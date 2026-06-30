#!/usr/bin/env python3
"""
Écran de verrouillage prank — à lancer sur le PC du frère.
Surveille GitHub toutes les 3s. Quand locked=true → écran plein écran inévitable.
Seul le code secret (ou le bouton Sheets) le libère.
"""

import tkinter as tk
import threading
import time
import json
import base64
import urllib.request
import urllib.error
import queue
import sys
import os

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'blague_lock_config.json')


def charger_config():
    with open(CONFIG_FILE, encoding='utf-8') as f:
        return json.load(f)


def github_get(config):
    url = f"https://api.github.com/repos/{config['owner']}/{config['repo']}/contents/{config['lock_path']}?ref={config['branch']}"
    req = urllib.request.Request(url, headers={
        'Authorization': f"Bearer {config['token']}",
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Python'
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def github_put(config, locked, sha):
    url = f"https://api.github.com/repos/{config['owner']}/{config['repo']}/contents/{config['lock_path']}"
    data = json.dumps({
        'message': 'unlock' if not locked else 'lock',
        'content': base64.b64encode(json.dumps({'locked': locked}).encode()).decode(),
        'sha': sha,
        'branch': config['branch']
    }).encode()
    req = urllib.request.Request(url, data=data, method='PUT', headers={
        'Authorization': f"Bearer {config['token']}",
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'User-Agent': 'Python'
    })
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


class BlagueVerrou:
    def __init__(self):
        self.config = charger_config()
        self.q = queue.Queue()
        self.verrou_actif = False
        self.sha_courant = None
        self.win = None

        self.root = tk.Tk()
        self.root.withdraw()

        threading.Thread(target=self._surveiller, daemon=True).start()
        self.root.after(500, self._traiter_queue)
        self.root.mainloop()

    def _surveiller(self):
        while True:
            try:
                f = github_get(self.config)
                contenu = json.loads(base64.b64decode(f['content']).decode())
                self.q.put(('lock' if contenu.get('locked') else 'unlock', f['sha']))
            except Exception:
                pass
            time.sleep(3)

    def _traiter_queue(self):
        try:
            while True:
                signal, sha = self.q.get_nowait()
                if signal == 'lock' and not self.verrou_actif:
                    self.sha_courant = sha
                    self._afficher_verrou()
                elif signal == 'unlock' and self.verrou_actif:
                    self._masquer_verrou()
        except queue.Empty:
            pass
        self.root.after(500, self._traiter_queue)

    def _afficher_verrou(self):
        self.verrou_actif = True

        w = tk.Toplevel(self.root)
        self.win = w
        sw = w.winfo_screenwidth()
        sh = w.winfo_screenheight()
        w.geometry(f"{sw}x{sh}+0+0")
        w.attributes('-topmost', True)
        w.overrideredirect(True)
        w.configure(bg='#0a0a0a')
        w.protocol("WM_DELETE_WINDOW", lambda: None)
        w.focus_force()

        for seq in ['<Alt-F4>', '<Alt-Tab>', '<Control-Escape>', '<Super-L>', '<Super-R>', '<Escape>', '<Control-Alt-Delete>']:
            w.bind(seq, lambda e: 'break')

        frame = tk.Frame(w, bg='#0a0a0a')
        frame.place(relx=0.5, rely=0.5, anchor='center')

        tk.Label(frame, text="🔒", font=('Segoe UI', 72), bg='#0a0a0a', fg='white').pack(pady=5)
        tk.Label(frame, text="2  —  1", font=('Segoe UI', 80, 'bold'), fg='#e74c3c', bg='#0a0a0a').pack(pady=5)
        tk.Label(frame,
            text="Ton PC est sous juridiction fraternelle.\n\n"
                 "Appelle-moi pour obtenir le code de libération.\n\n"
                 "(Oui tu peux ouvrir le gestionnaire des tâches.\n"
                 " Il revient dans 2 secondes.  Bonne chance. 😊)",
            font=('Segoe UI', 18), fg='#cccccc', bg='#0a0a0a', justify='center'
        ).pack(pady=25)

        self.code_var = tk.StringVar()
        entry = tk.Entry(frame, textvariable=self.code_var, font=('Segoe UI', 22),
                         show='●', width=16, bg='#1c1c1c', fg='white',
                         insertbackground='white', relief='flat', bd=12, justify='center')
        entry.pack(pady=10)
        entry.focus_force()

        self.msg_var = tk.StringVar()
        tk.Label(frame, textvariable=self.msg_var, font=('Segoe UI', 13),
                 fg='#e74c3c', bg='#0a0a0a').pack(pady=4)

        btn = tk.Button(frame, text="Déverrouiller", command=self._valider,
                        font=('Segoe UI', 16, 'bold'), bg='#c0392b', fg='white',
                        activebackground='#e74c3c', relief='flat', padx=24, pady=10, cursor='hand2')
        btn.pack(pady=12)
        w.bind('<Return>', lambda e: self._valider())

    def _valider(self):
        if self.code_var.get() == self.config['code_secret']:
            try:
                github_put(self.config, False, self.sha_courant)
            except Exception:
                pass
            self._masquer_verrou()
        else:
            self.msg_var.set("❌ Code incorrect. Rappelle ton grand frère.")
            self.code_var.set("")

    def _masquer_verrou(self):
        self.verrou_actif = False
        if self.win:
            self.win.destroy()
            self.win = None


if __name__ == '__main__':
    BlagueVerrou()
