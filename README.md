# Destination Mystère

Application web personnelle (PWA) de suivi de **perte de poids** et de **préparation physique** pour un objectif daté : **le grand départ, le 10 août 2027**.

- 📱 **Installable sur iPhone** via Safari (« Sur l'écran d'accueil »), s'ouvre en plein écran comme une app.
- 🔌 **Fonctionne hors-ligne** (service worker, cache de l'app shell).
- 🔒 **100 % local** : toutes les données restent sur l'appareil (`localStorage`). Rien n'est envoyé sur internet.
- 🛠️ **Aucune étape de build** : HTML/CSS/JS vanilla, déployable tel quel sur GitHub Pages.

---

## Fonctions

- **Tableau de bord** : décompte des jours avant le grand départ, barre de progression, poids actuel / perdu / restant, rythme moyen (kg/semaine), résumé entraînement 7 jours, courbe du poids avec moyenne lissée 7 jours, prochain jalon.
- **Poids** : pesées (date, poids, tour de taille, note), moyenne lissée 7 j, courbe.
- **Alimentation** : journal détaillé (repas, protéines, légumes/fruits, eau, calories, faim, énergie, note) avec sélecteurs rapides au pouce.
- **Entraînement** : séances (type, durée, distance, charge sac, dénivelé, RPE, note).
- **Repères santé** : page d'information (médecin, mangerbouger.fr, diététicien, principes sains, disclaimer).
- **Jalons** : −10, −20, −30, −40, −50 kg, marqués « Atteint ✓ » automatiquement.
- **Sauvegarde** : export **JSON** + **CSV**, import **JSON** pour restaurer.

> ⚠️ iOS peut purger le stockage local d'une PWA peu utilisée. **Pense à exporter régulièrement** tes données (onglet Réglages → Sauvegarde).

---

## Structure du projet

```
.
├── index.html            # SPA (tous les écrans)
├── manifest.json         # métadonnées PWA + icônes
├── service-worker.js     # cache app shell (hors-ligne, cache-first)
├── css/styles.css        # styles (mobile-first, palette froide)
├── js/app.js             # logique : stockage, calculs, rendu, graphe SVG
├── icons/                # icônes 192 / 512 / 512 maskable
└── tools/gen_icons.py    # script de (re)génération des icônes (optionnel)
```

---

## Tester en local

Un service worker exige un serveur HTTP (il ne fonctionne pas via `file://`).

```bash
# Depuis la racine du projet
python3 -m http.server 8000
```

Puis ouvrir <http://localhost:8000> dans un navigateur.

---

## Déployer sur GitHub Pages

1. **Pousser les fichiers à la racine** d'un dépôt GitHub (branche `main`).
2. Dans le dépôt : **Settings → Pages**.
3. **Source** : *Deploy from a branch*, branche **`main`**, dossier **`/ (root)`**, puis *Save*.
4. Après quelques instants, l'app est servie sur :
   `https://<utilisateur>.github.io/<depot>/`

Les chemins du projet sont **relatifs**, l'app fonctionne donc aussi bien à la racine d'un domaine que dans un sous-dossier `/<depot>/`.

---

## Installer sur iPhone

1. Ouvrir l'URL GitHub Pages **dans Safari** (l'installation PWA n'est possible que depuis Safari sur iOS).
2. Toucher le bouton **Partager** (le carré avec une flèche vers le haut).
3. Choisir **« Sur l'écran d'accueil »**.
4. Valider : l'icône apparaît sur l'écran d'accueil. L'app s'ouvre en plein écran et fonctionne **hors-ligne**.

---

## Mettre à jour l'app

Après avoir poussé de nouveaux fichiers, incrémente `CACHE_VERSION` dans `service-worker.js` (ex. `v1` → `v2`). Le worker purge alors l'ancien cache et recharge les fichiers à jour.

---

## Régénérer les icônes (optionnel)

```bash
python3 tools/gen_icons.py
```

Aucune dépendance externe : le script encode directement les PNG.

---

## Vie privée

Toutes les données saisies sont stockées **uniquement** dans le navigateur de l'appareil (`localStorage`). L'application ne contacte aucun serveur et ne nécessite aucun compte. Les exports (JSON/CSV) sont des téléchargements locaux que tu maîtrises entièrement.
