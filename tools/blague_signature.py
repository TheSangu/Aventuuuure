#!/usr/bin/env python3
"""
Blague signature : remplace "Léo Le Psycho" par "Bip Bap BOOM"
dans le presse-papier dès que la signature est copiée.

Lancer : python3 blague_signature.py
Arrêter : Ctrl+C
"""

import time
import sys

try:
    import pyperclip
except ImportError:
    print("Installation de pyperclip...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyperclip"])
    import pyperclip

SIGNATURE = "Léo Le Psycho"
REMPLACEMENT = "Bip Bap BOOM"
INTERVALLE = 0.5  # secondes entre chaque vérification

print("🎯 Surveillance du presse-papier active...")
print(f'   Si "{SIGNATURE}" est copié → remplacé par "{REMPLACEMENT}"')
print("   Appuie sur Ctrl+C pour arrêter.\n")

dernier_contenu = ""

try:
    while True:
        try:
            contenu = pyperclip.paste()
        except Exception:
            time.sleep(INTERVALLE)
            continue

        if contenu != dernier_contenu:
            dernier_contenu = contenu
            if SIGNATURE in contenu:
                nouveau = contenu.replace(SIGNATURE, REMPLACEMENT)
                pyperclip.copy(nouveau)
                dernier_contenu = nouveau
                print(f"💥 Remplacement effectué ! « {SIGNATURE} » → « {REMPLACEMENT} »")

        time.sleep(INTERVALLE)

except KeyboardInterrupt:
    print("\n✅ Surveillance arrêtée. Blague terminée !")
