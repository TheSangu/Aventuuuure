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
- **Pas** : saisie du nombre de pas par jour (manuelle ou via Raccourci iPhone), total 7 jours sur l'accueil.
- **Jalons** : −10, −20, −30, −40, −50 kg, marqués « Atteint ✓ » automatiquement.
- **Sauvegarde** : export **JSON** + **CSV**, import **JSON** pour restaurer.
- **Synchronisation à distance** (optionnelle) : envoi automatique vers GitHub + page **coach** en lecture seule.

> ⚠️ iOS peut purger le stockage local d'une PWA peu utilisée. **Pense à exporter régulièrement** tes données (onglet Réglages → Sauvegarde).

---

## Structure du projet

```
.
├── index.html            # SPA (tous les écrans)
├── coach.html            # vue « coach » en lecture seule (suivi à distance)
├── manifest.json         # métadonnées PWA + icônes
├── service-worker.js     # cache app shell (hors-ligne, cache-first)
├── css/styles.css        # styles (mobile-first, palette froide)
├── js/app.js             # logique : stockage, calculs, rendu, graphe SVG, synchro
├── data/suivi.json       # fichier de données distant (rempli par la synchro)
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

## Synchronisation à distance (optionnel)

L'app peut **envoyer automatiquement les données dans le dépôt GitHub** (fichier `data/suivi.json`). Ça sert de **sauvegarde** *et* permet à une autre personne (un coach, un binôme) de **suivre la progression à distance** via la page `coach.html`.

> Le dépôt étant public, ce fichier ne contient que des chiffres anonymes (poids, pas…), aucune information permettant d'identifier la personne. Le **jeton d'accès reste uniquement sur l'appareil** (saisi dans l'app, jamais dans le code).

### 1. Créer un jeton d'accès GitHub (une fois)

1. GitHub → **Settings** du compte → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. **Repository access** : *Only select repositories* → choisir **ce dépôt**.
3. **Permissions** → **Repository permissions** → **Contents** : **Read and write**.
4. Choisir une **expiration** (ex. 1 an), générer, **copier le jeton** (`github_pat_…`).

### 2. Configurer l'app

Dans l'app → onglet **Réglages** → carte **« Synchronisation »** :
- **Jeton** : coller le `github_pat_…`,
- **owner** : le compte GitHub (ex. `thesangu`),
- **repo** : le nom du dépôt (ex. `Aventuuuure`),
- **branche** : la branche servie (ex. `claude/stoic-goodall-cY7kL` ou `main`),
- **chemin** : `data/suivi.json`,
- cocher **« Envoi automatique après chaque saisie »**,
- **Enregistrer**, puis **Envoyer maintenant** pour tester.

À partir de là, chaque pesée / saisie de pas est **poussée automatiquement** vers le dépôt.

### 3. La page « coach » (suivi à distance)

Ouvre simplement :

`https://<utilisateur>.github.io/<depot>/coach.html`

C'est une page **en lecture seule** (aucun jeton requis, lit le fichier public) : poids actuel, progression, courbe, pas des 7 derniers jours, dernières pesées. Elle se rafraîchit toute seule. Le bouton **« Réglages de la source »** permet d'ajuster owner / repo / branche / chemin si besoin.

## Récolte automatique des pas (Raccourci iPhone)

Une app web ne peut pas lire l'app **Santé** d'Apple. On contourne avec un **Raccourci** (app *Raccourcis*) qui lit les pas et les envoie à l'app via l'URL.

1. App **Raccourcis** → **+** → ajouter les actions :
   - **« Rechercher des échantillons de santé »** → Type : **Nombre de pas**, Trier par **Date de début**, Limite **aucune** sur **aujourd'hui** (ou « Obtenir la statistique de santé » → Pas → Aujourd'hui → Somme).
   - **« Calculer la statistique »** / **« Obtenir le total »** pour additionner → variable **Pas**.
   - **« Ouvrir les URL »** avec :
     `https://<utilisateur>.github.io/<depot>/?pas=[Pas]`
     (insérer la variable **Pas** à la place de `[Pas]`).
2. **Automatisation** : onglet *Automatisation* → **+** → **Heure du jour** (ex. 22:00, chaque jour) → lancer ce raccourci.

Au déclenchement, l'app s'ouvre une seconde, **enregistre les pas du jour** et les **synchronise** vers GitHub, puis nettoie l'URL. On peut aussi envoyer le poids de la même façon : `?poids=151.2` (ou combiner `?pas=8500&poids=151.2`).

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
