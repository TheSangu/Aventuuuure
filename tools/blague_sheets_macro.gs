// ================================================================
// Google Apps Script — Blague Lock
//
// Installation (une fois) :
// 1. Ouvrir Google Sheets → Extensions → Apps Script
// 2. Coller tout ce fichier
// 3. Projet → Paramètres → Propriétés de script → Ajouter :
//       GITHUB_TOKEN = ghp_...  (ton token GitHub, contents r/w)
// 4. Sauvegarder, puis dans la feuille :
//    Insertion → Dessin → crée un bouton, clic droit → Assigner un script
//    → "bloquerFrere"  (et un autre pour "debloquerFrere" si tu veux)
// ================================================================

const OWNER  = 'thesangu';
const REPO   = 'Aventuuuure';
const BRANCH = 'main';
const PATH   = 'data/blague_lock.json';

function _getToken() {
  return PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
}

function _githubGet() {
  const url = `https://api.github.com/repos/${OWNER}/${REPO}/contents/${PATH}?ref=${BRANCH}`;
  const resp = UrlFetchApp.fetch(url, {
    headers: {
      Authorization: `Bearer ${_getToken()}`,
      Accept: 'application/vnd.github+json'
    },
    muteHttpExceptions: true
  });
  return JSON.parse(resp.getContentText());
}

function _githubPut(locked, sha) {
  const url = `https://api.github.com/repos/${OWNER}/${REPO}/contents/${PATH}`;
  const content = Utilities.base64Encode(JSON.stringify({ locked: locked }));
  UrlFetchApp.fetch(url, {
    method: 'put',
    headers: {
      Authorization: `Bearer ${_getToken()}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json'
    },
    payload: JSON.stringify({ message: locked ? 'lock' : 'unlock', content, sha, branch: BRANCH }),
    muteHttpExceptions: true
  });
}

function bloquerFrere() {
  const current = _githubGet();
  _githubPut(true, current.sha);
  SpreadsheetApp.getUi().alert('💥 PC verrouillé ! Attends son coup de fil...');
}

function debloquerFrere() {
  const current = _githubGet();
  _githubPut(false, current.sha);
  SpreadsheetApp.getUi().alert('✅ PC déverrouillé. Tu es magnanime.');
}
