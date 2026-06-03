# SPEC.md — Application de suivi « Destination Mystère »

## 1. Objectif
Construire une **Progressive Web App (PWA) mobile, en français**, qui sert de tracker personnel de perte de poids et de préparation physique pour un objectif daté. Elle doit être :
- **installable sur iPhone via Safari** (« Ajouter à l'écran d'accueil »), s'ouvrant en plein écran comme une app ;
- **fonctionnelle hors-ligne** ;
- **déployable telle quelle sur GitHub Pages** : fichiers 100 % statiques, **aucun serveur, aucune étape de build, aucun bundler**.

## 2. ⚠️ Règle critique — destination secrète
La destination de l'expédition est **secrète** jusqu'au jour du départ. N'écris **NULLE PART** (interface, code, commentaires, manifest, README, noms de fichiers) de mots ou d'indices géographiques révélant le lieu, ni rien évoquant la faune ou un environnement spécifique. Le seul thème visible est **« DESTINATION MYSTÈRE »**, avec un grand jour fixé au **10 août 2027**. Reste sur du vocabulaire neutre : « l'expédition », « le défi », « le grand départ ».

## 3. Stack imposée (pour GitHub Pages sans build)
- **HTML / CSS / JavaScript vanilla**, une seule SPA. Pas de framework lourd, pas de bundler.
- **manifest.json** + **service-worker.js** pour l'installation et le hors-ligne (cache de l'app shell, stratégie *cache-first*).
- **Données stockées en local** sur l'appareil (IndexedDB de préférence, sinon localStorage). **Rien n'est envoyé sur internet.**
- **Graphe** : SVG fait main, ou une petite lib mise en cache par le service worker (doit fonctionner hors-ligne).

## 4. Modèle de données
Reproduire fidèlement la structure ci-dessous (issue d'un tableur de référence).

### Paramètres (réglés une fois, modifiables)
| Champ | Valeur par défaut |
|---|---|
| Poids de départ (kg) | 150 |
| Objectif — poids cible (kg) | 100 |
| Date de départ du programme | 2026-06-03 |
| Date de l'expédition | 2027-08-10 |
| Cible calorique/jour (optionnel) | vide |
| Prénom (optionnel) | vide |

### Pesées (onglet « Poids »)
`date`, `poids` (kg, 1 décimale), `tourTaille` (cm, optionnel), `note`.
- **moyenne 7 j** = moyenne des pesées dont la date est dans les 7 jours précédant (et incluant) la pesée courante.

### Alimentation (journal détaillé)
`date`, `petitDejeuner`, `dejeuner`, `diner`, `collations`, `proteines` (échelle 1-3), `legumesFruits` (portions), `eau` (verres), `calories` (optionnel), `faim` (1-5), `energie` (1-5), `note`.
Les champs scorés (1-3, 1-5) se saisissent via sélecteurs pour une saisie rapide au pouce.

### Entraînement
`date`, `type`, `duree` (min), `distance` (km), `chargeSac` (kg), `denivele` (m), `rpe` (1-10), `note`.
Liste déroulante `type` : **Rando, Marche chargée, Cardio, Renforcement, Mobilité/Étirements, Tir, Autre**.

### Jalons
Paliers **-10, -20, -30, -40, -50 kg**. Pour chaque palier : poids cible = `poidsDepart − X`, statut **« Atteint ✓ »** automatiquement dès que le poids actuel passe sous ce seuil (sinon « — »).

## 5. Écrans et fonctions

### Tableau de bord (accueil)
- Titre **« DESTINATION MYSTÈRE »**, sous-titre **« Préparation de l'expédition • Grand départ le 10 août 2027 »**.
- **Décompte** : jours jusqu'au 10/08/2027 (recalculé chaque jour), semaines restantes, jours déjà écoulés depuis la date de départ.
- **Barre de progression** = `(poidsDepart − poidsActuel) / (poidsDepart − poidsCible)`, bornée 0–100 %, pourcentage affiché.
- Poids actuel / poids perdu / reste à perdre / **rythme moyen (kg/semaine)**.
- **Résumé entraînement 7 derniers jours** : nombre de séances + durée totale ; et **cumul de distance**.
- **Courbe du poids** avec la moyenne lissée 7 jours superposée.
- **Prochain jalon** à atteindre.

### Paramètres
Édition des champs du §4 (paramètres).

### Poids
Formulaire d'ajout + liste des pesées + courbe.

### Alimentation
Formulaire journalier détaillé (§4) + historique.

### Entraînement
Formulaire par séance (§4) + historique.

### Repères santé (page d'info, aucun calcul)
**À faire en premier**
1. RDV chez le **médecin traitant** (remboursé) : feu vert pour « déficit + entraînement intense », prise de sang, rythme de perte sûr, et éventuelle cible calorique adaptée.
2. Repères nutrition gratuits et officiels : **mangerbouger.fr** (Programme National Nutrition Santé).
3. Optionnel : 3-4 séances chez un **diététicien** pour poser un cadre durable — souvent couvert en partie par la mutuelle.

**Principes sains (repères généraux — pas un régime personnalisé)**
- Perte progressive et régulière plutôt que brutale (à caler avec le médecin) : on préserve le muscle et la motivation.
- Des protéines à chaque repas pour protéger la masse musculaire pendant la perte.
- Légumes, fruits et fibres en abondance ; limiter les produits ultra-transformés et les boissons sucrées.
- Bien s'hydrater, surtout autour des séances.
- Manger suffisamment autour des entraînements — pas d'entraînement à jeun sévère.
- Dormir 7 à 9 h : clé pour la perte de gras et la récupération.
- Signaux d'alerte d'un sous-régime : fatigue persistante, faim ingérable, baisse de performance, sommeil dégradé → manger plus et/ou consulter.

> Repères de santé publique à visée générale. Ne remplacent pas l'avis d'un médecin. En cas de trouble du comportement alimentaire, consulter un professionnel.

## 6. Calculs clés
- `poidsActuel` = poids de la pesée la plus récente (sinon `poidsDepart`).
- `progression` = borne entre 0 et 1 de `(poidsDepart − poidsActuel) / (poidsDepart − poidsCible)` ; protéger le cas `poidsDepart = poidsCible`.
- `joursAvantDepart` = `dateExpedition − aujourd'hui` (en jours).
- `semainesRestantes` = arrondi de `joursAvantDepart / 7`.
- `joursEcoules` = `aujourd'hui − dateDepart`.
- `rythme` = `(poidsDepart − poidsActuel) / (joursEcoules / 7)` si `joursEcoules > 0`, sinon 0.
- Résumé entraînement 7 j : ne compter que les séances dont la `date ≥ aujourd'hui − 6`.

## 7. Sauvegarde (important)
- **Bouton Export** : télécharge un **JSON** de toutes les données (+ un **CSV** pratique).
- **Bouton Import** : restaure l'état depuis le JSON.
- Raison : iOS peut purger le stockage local d'une PWA peu utilisée ; l'utilisateur doit pouvoir sauvegarder/restaurer.

## 8. Design
- **Mobile-first**, plein écran en mode standalone, grandes zones tactiles.
- **Barre d'onglets en bas** : Accueil, Poids, Alimentation, Entraînement, Repères.
- Palette sobre et froide (bleus profonds, blanc, un **vert** pour la progression), **sans aucun visuel révélant la destination**. Tout en français.

## 9. PWA — technique
- **manifest.json** : `name` « Destination Mystère », `short_name`, `display` « standalone », `theme_color`, `background_color`, `start_url`, icônes **192** et **512 px** (dégradé + symbole neutre type sommet ou flèche, sans indice géographique).
- **service-worker.js** : met en cache l'app shell pour un **hors-ligne complet**. Aucun backend ; l'app fonctionne en ouvrant `index.html`.
- Gérer le cycle de vie du service worker (mise à jour du cache lors d'une nouvelle version).

## 10. Déploiement (à documenter dans le README.md)
1. Pousser les fichiers **à la racine** d'un dépôt GitHub.
2. Activer **GitHub Pages** (source : branche `main`, dossier racine). L'app sera servie sur `https://<user>.github.io/<repo>/`.
3. Sur iPhone : ouvrir l'URL **dans Safari** → **Partager** → **« Sur l'écran d'accueil »** → installation avec icône + hors-ligne.

## 11. Livrables
`index.html`, fichier(s) CSS, fichier(s) JS, `manifest.json`, `service-worker.js`, les icônes, et `README.md` (étapes GitHub Pages + installation iPhone). Code propre et commenté, **testé en local** (ex. `python -m http.server`).

---
**RAPPEL CRITIQUE : aucune mention ni indice de la destination réelle nulle part dans le projet.**
