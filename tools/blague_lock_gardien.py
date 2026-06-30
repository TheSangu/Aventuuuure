#!/usr/bin/env python3
"""
Gardien : relance l'écran de verrouillage automatiquement s'il est tué.
C'est CE fichier qu'on met en démarrage Windows, pas l'écran directement.
"""

import subprocess
import sys
import time
import os

ECRAN = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blague_lock_ecran.py')

kwargs = {}
if sys.platform == 'win32':
    kwargs['creationflags'] = 0x08000000  # CREATE_NO_WINDOW — invisible dans la barre des tâches

print("Gardien actif. Ctrl+C pour arrêter.")
while True:
    proc = subprocess.Popen([sys.executable, ECRAN], **kwargs)
    proc.wait()
    time.sleep(2)
