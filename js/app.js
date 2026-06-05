/* ===================================================================
   Destination Mystère — logique de l'application (vanilla JS)
   - Stockage 100 % local (localStorage). Rien n'est envoyé sur le réseau.
   - SPA : navigation par onglets, écrans masqués/affichés.
   - Graphe : SVG fait main (poids + moyenne lissée 7 jours).
   =================================================================== */

(() => {
  'use strict';

  // ---------------------------------------------------------------
  // Constantes
  // ---------------------------------------------------------------
  const STORAGE_KEY = 'destination-mystere-data';
  const PALIERS = [10, 20, 30, 40, 50]; // jalons en kg perdus
  const DEFAULTS = {
    settings: {
      prenom: '',
      poidsDepart: 150,
      poidsCible: 100,
      dateDepart: '2026-06-03',
      dateExpedition: '2027-08-10',
      cibleCalories: ''
    },
    poids: [],         // { id, date, poids, tourTaille, note }
    alimentation: [],  // { id, date, petitDejeuner, dejeuner, diner, collations, proteines, legumesFruits, eau, calories, faim, energie, note }
    entrainement: [],  // { id, date, type, duree, distance, chargeSac, denivele, rpe, note }
    pas: []            // { id, date, pas } — nombre de pas par jour
  };

  // Configuration de synchronisation GitHub, stockée À PART (clé distincte) :
  // ainsi le jeton n'est jamais inclus dans l'export JSON des données.
  const SYNC_KEY = 'destination-mystere-sync';
  const SYNC_DEFAULTS = {
    token: '',
    owner: 'thesangu',
    repo: 'Aventuuuure',
    branch: 'claude/stoic-goodall-cY7kL',
    path: 'data/suivi.json',
    auto: true,
    lastSync: ''
  };

  // ---------------------------------------------------------------
  // Stockage
  // ---------------------------------------------------------------
  let state = loadState();

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return structuredCloneSafe(DEFAULTS);
      const parsed = JSON.parse(raw);
      // Fusion défensive pour rester compatible avec d'anciennes sauvegardes.
      return {
        settings: Object.assign({}, DEFAULTS.settings, parsed.settings || {}),
        poids: Array.isArray(parsed.poids) ? parsed.poids : [],
        alimentation: Array.isArray(parsed.alimentation) ? parsed.alimentation : [],
        entrainement: Array.isArray(parsed.entrainement) ? parsed.entrainement : [],
        pas: Array.isArray(parsed.pas) ? parsed.pas : []
      };
    } catch (e) {
      console.warn('Lecture du stockage impossible, réinitialisation locale.', e);
      return structuredCloneSafe(DEFAULTS);
    }
  }

  // ---- Configuration de synchronisation (jeton GitHub) ----
  let sync = loadSync();
  function loadSync() {
    try {
      const raw = localStorage.getItem(SYNC_KEY);
      return Object.assign({}, SYNC_DEFAULTS, raw ? JSON.parse(raw) : {});
    } catch (e) {
      return Object.assign({}, SYNC_DEFAULTS);
    }
  }
  function saveSync() {
    try { localStorage.setItem(SYNC_KEY, JSON.stringify(sync)); } catch (e) { /* ignore */ }
  }

  function saveState() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      alert('Impossible d\'enregistrer localement (stockage plein ou bloqué).');
    }
  }

  function structuredCloneSafe(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  // ---------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  function uid() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  }

  function todayISO() {
    const d = new Date();
    const off = d.getTimezoneOffset();
    return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10);
  }

  // Parse une date ISO (YYYY-MM-DD) en date locale à minuit.
  function parseISO(iso) {
    if (!iso) return null;
    const [y, m, d] = iso.split('-').map(Number);
    return new Date(y, m - 1, d);
  }

  // Nombre de jours entiers entre deux dates ISO (b - a).
  function daysBetween(aISO, bISO) {
    const a = parseISO(aISO), b = parseISO(bISO);
    if (!a || !b) return 0;
    return Math.round((b - a) / 86400000);
  }

  function num(v, fallback = 0) {
    const n = parseFloat(v);
    return Number.isFinite(n) ? n : fallback;
  }

  function fmtKg(v) { return (Math.round(v * 10) / 10).toFixed(1) + ' kg'; }

  function fmtDateFR(iso) {
    const d = parseISO(iso);
    if (!d) return '—';
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, (c) => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
  }

  // ---------------------------------------------------------------
  // Calculs métier
  // ---------------------------------------------------------------
  // Pesées triées par date croissante.
  function peséesTriees() {
    return [...state.poids].sort((a, b) => a.date.localeCompare(b.date));
  }

  function poidsActuel() {
    const tri = peséesTriees();
    return tri.length ? num(tri[tri.length - 1].poids, state.settings.poidsDepart) : num(state.settings.poidsDepart);
  }

  function progression() {
    const dep = num(state.settings.poidsDepart);
    const cible = num(state.settings.poidsCible);
    if (dep === cible) return 1; // protège la division par zéro
    const p = (dep - poidsActuel()) / (dep - cible);
    return Math.max(0, Math.min(1, p));
  }

  function rythmeKgSemaine() {
    const ecoules = daysBetween(state.settings.dateDepart, todayISO());
    if (ecoules <= 0) return 0;
    const perdu = num(state.settings.poidsDepart) - poidsActuel();
    return perdu / (ecoules / 7);
  }

  // Moyenne lissée 7 jours : pour chaque pesée, moyenne des pesées dans
  // la fenêtre [date-6j ; date].
  function moyenne7j(tri) {
    return tri.map((p, i) => {
      const fin = parseISO(p.date);
      const debut = new Date(fin.getTime() - 6 * 86400000);
      let somme = 0, n = 0;
      for (let j = 0; j <= i; j++) {
        const d = parseISO(tri[j].date);
        if (d >= debut && d <= fin) { somme += num(tri[j].poids); n++; }
      }
      return n ? somme / n : num(p.poids);
    });
  }

  // Résumé entraînement sur les 7 derniers jours (date >= aujourd'hui - 6).
  function resumeEntr7j() {
    const limite = new Date(parseISO(todayISO()).getTime() - 6 * 86400000);
    const recents = state.entrainement.filter((s) => parseISO(s.date) >= limite);
    return {
      seances: recents.length,
      duree: recents.reduce((t, s) => t + num(s.duree), 0),
      distance: recents.reduce((t, s) => t + num(s.distance), 0)
    };
  }

  function jalons() {
    const dep = num(state.settings.poidsDepart);
    const actuel = poidsActuel();
    return PALIERS.map((x) => {
      const seuil = dep - x;
      return { x, seuil, atteint: actuel <= seuil };
    });
  }

  // ---------------------------------------------------------------
  // Rendu : Tableau de bord
  // ---------------------------------------------------------------
  function renderDashboard() {
    const s = state.settings;
    const prenom = (s.prenom || '').trim();
    $('#dash-greeting').textContent = prenom ? `Bonjour ${prenom} 👋` : '';

    // Décompte
    const today = todayISO();
    const jours = daysBetween(today, s.dateExpedition);
    const semaines = Math.round(jours / 7);
    const ecoules = Math.max(0, daysBetween(s.dateDepart, today));
    $('#cd-jours').textContent = jours >= 0 ? jours : 0;
    $('#cd-semaines').textContent = semaines >= 0 ? semaines : 0;
    $('#cd-ecoules').textContent = ecoules;

    // Progression
    const prog = progression();
    const pct = Math.round(prog * 100);
    $('#prog-fill').style.width = pct + '%';
    $('#prog-percent').textContent = pct + ' %';
    const aria = $('#prog-bar-aria');
    if (aria) aria.setAttribute('aria-valuenow', String(pct));

    const actuel = poidsActuel();
    const dep = num(s.poidsDepart), cible = num(s.poidsCible);
    const perdu = Math.max(0, dep - actuel);
    const reste = Math.max(0, actuel - cible);
    $('#st-actuel').textContent = fmtKg(actuel);
    $('#st-perdu').textContent = fmtKg(perdu);
    $('#st-reste').textContent = fmtKg(reste);
    const r = rythmeKgSemaine();
    $('#st-rythme').textContent = (Math.round(r * 100) / 100).toFixed(2);

    // Entraînement 7 j
    const e = resumeEntr7j();
    $('#tr-seances').textContent = e.seances;
    $('#tr-duree').textContent = e.duree + ' min';
    $('#tr-distance').textContent = (Math.round(e.distance * 10) / 10) + ' km';

    // Pas 7 j
    const tp = $('#tr-pas');
    if (tp) tp.textContent = pas7j().toLocaleString('fr-FR');

    // Indicateur de synchro
    renderSyncStatus();

    // Courbe
    renderChart('#dash-chart');

    // Jalons
    renderJalons();
  }

  function renderJalons() {
    const list = $('#milestones-list');
    const js = jalons();
    list.innerHTML = js.map((j) => `
      <li>
        <span>−${j.x} kg <span class="muted">(≤ ${fmtKg(j.seuil)})</span></span>
        <span class="${j.atteint ? 'done' : 'pending'}">${j.atteint ? 'Atteint ✓' : '—'}</span>
      </li>`).join('');

    const prochain = js.find((j) => !j.atteint);
    const actuel = poidsActuel();
    if (!prochain) {
      $('#next-milestone').textContent = 'Tous les jalons sont atteints. Bravo ! 🎉';
    } else {
      const aFaire = Math.max(0, actuel - prochain.seuil);
      $('#next-milestone').textContent =
        `Prochain jalon : −${prochain.x} kg — encore ${fmtKg(aFaire)} (objectif ≤ ${fmtKg(prochain.seuil)}).`;
    }
  }

  // ---------------------------------------------------------------
  // Graphe SVG fait main : poids + moyenne lissée 7 jours
  // ---------------------------------------------------------------
  function renderChart(selector) {
    const host = $(selector);
    if (!host) return;
    const tri = peséesTriees();

    if (tri.length === 0) {
      host.innerHTML = '<p class="chart-empty">Aucune pesée enregistrée pour le moment.</p>';
      return;
    }

    const W = 340, H = 200, pad = { t: 14, r: 12, b: 26, l: 38 };
    const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;

    const valeurs = tri.map((p) => num(p.poids));
    const avg = moyenne7j(tri);
    const cible = num(state.settings.poidsCible);

    let min = Math.min(...valeurs, ...avg, cible);
    let max = Math.max(...valeurs, ...avg, num(state.settings.poidsDepart));
    if (min === max) { min -= 1; max += 1; }
    const margin = (max - min) * 0.08 || 1;
    min -= margin; max += margin;

    const n = tri.length;
    const x = (i) => pad.l + (n === 1 ? iw / 2 : (i / (n - 1)) * iw);
    const y = (v) => pad.t + ih - ((v - min) / (max - min)) * ih;

    // Lignes de grille horizontales + libellés Y
    const ticks = 4;
    let grid = '';
    for (let t = 0; t <= ticks; t++) {
      const v = min + (t / ticks) * (max - min);
      const yy = y(v);
      grid += `<line x1="${pad.l}" y1="${yy}" x2="${W - pad.r}" y2="${yy}" stroke="#1d4670" stroke-width="1"/>`;
      grid += `<text x="${pad.l - 6}" y="${yy + 3}" fill="#9bb6d2" font-size="9" text-anchor="end">${Math.round(v)}</text>`;
    }

    // Ligne cible (si dans la plage)
    let cibleLine = '';
    if (cible >= min && cible <= max) {
      const yc = y(cible);
      cibleLine = `<line x1="${pad.l}" y1="${yc}" x2="${W - pad.r}" y2="${yc}" stroke="#2ecc8f" stroke-width="1" stroke-dasharray="4 4" opacity="0.7"/>`;
    }

    const path = (arr) => arr.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');

    const linePoids = `<path d="${path(valeurs)}" fill="none" stroke="#4a9ae8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>`;
    const lineAvg = `<path d="${path(avg)}" fill="none" stroke="#2ecc8f" stroke-width="2" stroke-dasharray="1 0" stroke-linecap="round" stroke-linejoin="round" opacity="0.95"/>`;

    const pts = valeurs.map((v, i) => `<circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="2.5" fill="#4a9ae8"/>`).join('');

    // Libellés X : première et dernière date
    const xLabels =
      `<text x="${x(0)}" y="${H - 8}" fill="#9bb6d2" font-size="9" text-anchor="start">${fmtDateShort(tri[0].date)}</text>` +
      (n > 1 ? `<text x="${x(n - 1)}" y="${H - 8}" fill="#9bb6d2" font-size="9" text-anchor="end">${fmtDateShort(tri[n - 1].date)}</text>` : '');

    host.innerHTML =
      `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Courbe du poids">
        ${grid}${cibleLine}${lineAvg}${linePoids}${pts}${xLabels}
      </svg>`;
  }

  function fmtDateShort(iso) {
    const d = parseISO(iso);
    return d ? d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' }) : '';
  }

  // ---------------------------------------------------------------
  // Rendu : listes (poids, alimentation, entraînement)
  // ---------------------------------------------------------------
  function renderPoids() {
    renderChart('#poids-chart');
    const tri = [...state.poids].sort((a, b) => b.date.localeCompare(a.date));
    const host = $('#poids-list');
    if (!tri.length) { host.innerHTML = '<p class="list-empty">Aucune pesée.</p>'; return; }
    const avgMap = buildAvgMap();
    host.innerHTML = tri.map((p) => {
      const moy = avgMap[p.id];
      const meta = [
        p.tourTaille ? `Taille : ${p.tourTaille} cm` : '',
        moy != null ? `Moy. 7 j : ${(Math.round(moy * 10) / 10).toFixed(1)} kg` : ''
      ].filter(Boolean).join(' • ');
      return itemHtml('poids', p.id, fmtDateFR(p.date), fmtKg(num(p.poids)), meta, p.note);
    }).join('');
  }

  // Construit une table id -> moyenne 7 j (calculée sur ordre chronologique).
  function buildAvgMap() {
    const tri = peséesTriees();
    const avg = moyenne7j(tri);
    const map = {};
    tri.forEach((p, i) => { map[p.id] = avg[i]; });
    return map;
  }

  function renderAlim() {
    const tri = [...state.alimentation].sort((a, b) => b.date.localeCompare(a.date));
    const host = $('#alim-list');
    if (!tri.length) { host.innerHTML = '<p class="list-empty">Aucune entrée.</p>'; return; }
    host.innerHTML = tri.map((a) => {
      const repas = [
        a.petitDejeuner && `Matin : ${a.petitDejeuner}`,
        a.dejeuner && `Midi : ${a.dejeuner}`,
        a.diner && `Soir : ${a.diner}`,
        a.collations && `Collations : ${a.collations}`
      ].filter(Boolean).join('\n');
      const meta = [
        a.proteines ? `Protéines ${a.proteines}/3` : '',
        a.legumesFruits ? `Lég./fruits ${a.legumesFruits}` : '',
        a.eau ? `Eau ${a.eau} verres` : '',
        a.calories ? `${a.calories} kcal` : '',
        a.faim ? `Faim ${a.faim}/5` : '',
        a.energie ? `Énergie ${a.energie}/5` : ''
      ].filter(Boolean).join(' • ');
      const note = [repas, a.note].filter(Boolean).join('\n');
      return itemHtml('alimentation', a.id, fmtDateFR(a.date), 'Journal', meta, note);
    }).join('');
  }

  function renderEntr() {
    const tri = [...state.entrainement].sort((a, b) => b.date.localeCompare(a.date));
    const host = $('#entr-list');
    if (!tri.length) { host.innerHTML = '<p class="list-empty">Aucune séance.</p>'; return; }
    host.innerHTML = tri.map((s) => {
      const meta = [
        s.duree ? `${s.duree} min` : '',
        s.distance ? `${s.distance} km` : '',
        s.chargeSac ? `Sac ${s.chargeSac} kg` : '',
        s.denivele ? `D+ ${s.denivele} m` : '',
        s.rpe ? `RPE ${s.rpe}/10` : ''
      ].filter(Boolean).join(' • ');
      return itemHtml('entrainement', s.id, fmtDateFR(s.date), escapeHtml(s.type), meta, s.note);
    }).join('');
  }

  function itemHtml(kind, id, date, main, meta, note) {
    return `<div class="list-item">
      <div class="li-head">
        <div>
          <div class="li-main">${main}</div>
          <div class="li-date">${date}</div>
        </div>
        <button class="li-del" data-kind="${kind}" data-id="${id}">Supprimer</button>
      </div>
      ${meta ? `<div class="li-meta">${escapeHtml(meta)}</div>` : ''}
      ${note ? `<div class="li-note">${escapeHtml(note)}</div>` : ''}
    </div>`;
  }

  // Suppression d'un enregistrement (délégation d'événements).
  document.addEventListener('click', (ev) => {
    const btn = ev.target.closest('.li-del');
    if (!btn) return;
    const { kind, id } = btn.dataset;
    if (!confirm('Supprimer cet enregistrement ?')) return;
    state[kind] = state[kind].filter((x) => x.id !== id);
    saveState();
    renderAll();
  });

  // ---------------------------------------------------------------
  // Sélecteurs scorés (segments 1-3 / 1-5 / 1-10)
  // ---------------------------------------------------------------
  function initSegments(formEl) {
    $$('.seg', formEl).forEach((seg) => {
      seg.addEventListener('click', (ev) => {
        const b = ev.target.closest('button');
        if (!b) return;
        $$('button', seg).forEach((x) => x.classList.remove('sel'));
        b.classList.add('sel');
        seg.dataset.value = b.dataset.val;
      });
    });
  }

  function getSeg(formEl, name) {
    const seg = $(`.seg[data-name="${name}"]`, formEl);
    return seg && seg.dataset.value ? num(seg.dataset.value) : '';
  }

  function resetSegs(formEl) {
    $$('.seg', formEl).forEach((seg) => {
      delete seg.dataset.value;
      $$('button', seg).forEach((x) => x.classList.remove('sel'));
    });
  }

  // ---------------------------------------------------------------
  // Formulaires
  // ---------------------------------------------------------------
  function initForms() {
    // --- Poids ---
    const fp = $('#form-poids');
    fp.date.value = todayISO();
    fp.addEventListener('submit', (e) => {
      e.preventDefault();
      state.poids.push({
        id: uid(),
        date: fp.date.value,
        poids: num(fp.poids.value),
        tourTaille: fp.tourTaille.value ? num(fp.tourTaille.value) : '',
        note: fp.note.value.trim()
      });
      saveState();
      fp.reset();
      fp.date.value = todayISO();
      renderAll();
      maybeAutoSync();
      flashMsg('Pesée enregistrée.');
    });

    // --- Alimentation ---
    const fa = $('#form-alim');
    fa.date.value = todayISO();
    initSegments(fa);
    fa.addEventListener('submit', (e) => {
      e.preventDefault();
      state.alimentation.push({
        id: uid(),
        date: fa.date.value,
        petitDejeuner: fa.petitDejeuner.value.trim(),
        dejeuner: fa.dejeuner.value.trim(),
        diner: fa.diner.value.trim(),
        collations: fa.collations.value.trim(),
        proteines: getSeg(fa, 'proteines'),
        legumesFruits: fa.legumesFruits.value ? num(fa.legumesFruits.value) : '',
        eau: fa.eau.value ? num(fa.eau.value) : '',
        calories: fa.calories.value ? num(fa.calories.value) : '',
        faim: getSeg(fa, 'faim'),
        energie: getSeg(fa, 'energie'),
        note: fa.note.value.trim()
      });
      saveState();
      fa.reset();
      resetSegs(fa);
      fa.date.value = todayISO();
      renderAll();
      maybeAutoSync();
      flashMsg('Journal enregistré.');
    });

    // --- Entraînement ---
    const fe = $('#form-entr');
    fe.date.value = todayISO();
    initSegments(fe);
    fe.addEventListener('submit', (e) => {
      e.preventDefault();
      state.entrainement.push({
        id: uid(),
        date: fe.date.value,
        type: fe.type.value,
        duree: fe.duree.value ? num(fe.duree.value) : '',
        distance: fe.distance.value ? num(fe.distance.value) : '',
        chargeSac: fe.chargeSac.value ? num(fe.chargeSac.value) : '',
        denivele: fe.denivele.value ? num(fe.denivele.value) : '',
        rpe: getSeg(fe, 'rpe'),
        note: fe.note.value.trim()
      });
      saveState();
      fe.reset();
      resetSegs(fe);
      fe.date.value = todayISO();
      renderAll();
      maybeAutoSync();
      flashMsg('Séance enregistrée.');
    });

    // --- Paramètres ---
    const fParams = $('#form-params');
    fParams.addEventListener('submit', (e) => {
      e.preventDefault();
      state.settings = {
        prenom: fParams.prenom.value.trim(),
        poidsDepart: num(fParams.poidsDepart.value, 150),
        poidsCible: num(fParams.poidsCible.value, 100),
        dateDepart: fParams.dateDepart.value || DEFAULTS.settings.dateDepart,
        dateExpedition: fParams.dateExpedition.value || DEFAULTS.settings.dateExpedition,
        cibleCalories: fParams.cibleCalories.value ? num(fParams.cibleCalories.value) : ''
      };
      saveState();
      fillParamsForm();
      renderAll();
      maybeAutoSync();
      flashMsg('Paramètres enregistrés.');
    });
  }

  function fillParamsForm() {
    const f = $('#form-params'), s = state.settings;
    f.prenom.value = s.prenom || '';
    f.poidsDepart.value = s.poidsDepart;
    f.poidsCible.value = s.poidsCible;
    f.dateDepart.value = s.dateDepart;
    f.dateExpedition.value = s.dateExpedition;
    f.cibleCalories.value = s.cibleCalories || '';
  }

  function flashMsg(txt) {
    // Petit retour visuel discret dans la console + vibration si dispo.
    if (navigator.vibrate) navigator.vibrate(10);
    const el = $('#io-msg');
    if (el && currentView === 'parametres') { el.textContent = txt; setTimeout(() => (el.textContent = ''), 2500); }
  }

  // ---------------------------------------------------------------
  // Export / Import / Reset
  // ---------------------------------------------------------------
  function download(filename, content, mime) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function exportJSON() {
    const payload = { version: 1, exportéLe: new Date().toISOString(), data: state };
    download(`destination-mystere_${todayISO()}.json`, JSON.stringify(payload, null, 2), 'application/json');
    setIoMsg('Export JSON téléchargé.');
  }

  function exportCSV() {
    const lignes = [];
    const esc = (v) => '"' + String(v ?? '').replace(/"/g, '""') + '"';

    lignes.push('# POIDS');
    lignes.push(['date', 'poids', 'tourTaille', 'note'].join(','));
    peséesTriees().forEach((p) => lignes.push([p.date, p.poids, p.tourTaille, p.note].map(esc).join(',')));

    lignes.push('');
    lignes.push('# ALIMENTATION');
    lignes.push(['date', 'petitDejeuner', 'dejeuner', 'diner', 'collations', 'proteines', 'legumesFruits', 'eau', 'calories', 'faim', 'energie', 'note'].join(','));
    [...state.alimentation].sort((a, b) => a.date.localeCompare(b.date)).forEach((a) =>
      lignes.push([a.date, a.petitDejeuner, a.dejeuner, a.diner, a.collations, a.proteines, a.legumesFruits, a.eau, a.calories, a.faim, a.energie, a.note].map(esc).join(',')));

    lignes.push('');
    lignes.push('# ENTRAINEMENT');
    lignes.push(['date', 'type', 'duree', 'distance', 'chargeSac', 'denivele', 'rpe', 'note'].join(','));
    [...state.entrainement].sort((a, b) => a.date.localeCompare(b.date)).forEach((s) =>
      lignes.push([s.date, s.type, s.duree, s.distance, s.chargeSac, s.denivele, s.rpe, s.note].map(esc).join(',')));

    lignes.push('');
    lignes.push('# PAS');
    lignes.push(['date', 'pas'].join(','));
    [...state.pas].sort((a, b) => a.date.localeCompare(b.date)).forEach((p) =>
      lignes.push([p.date, p.pas].map(esc).join(',')));

    // BOM pour une bonne ouverture des accents dans Excel.
    download(`destination-mystere_${todayISO()}.csv`, '﻿' + lignes.join('\r\n'), 'text/csv;charset=utf-8');
    setIoMsg('Export CSV téléchargé.');
  }

  function importJSON(file) {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(reader.result);
        const data = parsed.data || parsed; // accepte les deux formats
        if (!data || typeof data !== 'object') throw new Error('Format invalide');
        state = {
          settings: Object.assign({}, DEFAULTS.settings, data.settings || {}),
          poids: Array.isArray(data.poids) ? data.poids : [],
          alimentation: Array.isArray(data.alimentation) ? data.alimentation : [],
          entrainement: Array.isArray(data.entrainement) ? data.entrainement : [],
          pas: Array.isArray(data.pas) ? data.pas : []
        };
        saveState();
        fillParamsForm();
        renderAll();
        setIoMsg('Données importées avec succès.');
      } catch (e) {
        setIoMsg('Échec de l\'import : fichier JSON invalide.', true);
      }
    };
    reader.readAsText(file);
  }

  function setIoMsg(txt, isError) {
    const el = $('#io-msg');
    if (!el) return;
    el.textContent = txt;
    el.style.color = isError ? 'var(--danger)' : 'var(--green-soft)';
    setTimeout(() => (el.textContent = ''), 4000);
  }

  function initIO() {
    $('#btn-export-json').addEventListener('click', exportJSON);
    $('#btn-export-csv').addEventListener('click', exportCSV);
    const fileInput = $('#file-import');
    $('#btn-import').addEventListener('click', () => fileInput.click());
    fileInput.addEventListener('change', () => {
      if (fileInput.files[0]) importJSON(fileInput.files[0]);
      fileInput.value = '';
    });
    $('#btn-reset').addEventListener('click', () => {
      if (!confirm('Effacer TOUTES les données locales ? Cette action est irréversible.')) return;
      state = structuredCloneSafe(DEFAULTS);
      saveState();
      fillParamsForm();
      renderAll();
      setIoMsg('Données réinitialisées.');
    });
  }

  // ---------------------------------------------------------------
  // Navigation par onglets
  // ---------------------------------------------------------------
  let currentView = 'accueil';

  function showView(name) {
    currentView = name;
    $$('.view').forEach((v) => { v.hidden = v.id !== `view-${name}`; });
    $$('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === name));
    document.getElementById('main').scrollTop = 0;
    window.scrollTo(0, 0);
    // Re-rendu ciblé pour des données toujours fraîches.
    if (name === 'accueil') renderDashboard();
    else if (name === 'poids') renderPoids();
    else if (name === 'alimentation') renderAlim();
    else if (name === 'entrainement') renderEntr();
    else if (name === 'parametres') fillParamsForm();
  }

  function initTabs() {
    $$('.tab').forEach((t) => t.addEventListener('click', () => showView(t.dataset.view)));
  }

  // ---------------------------------------------------------------
  // Rendu global
  // ---------------------------------------------------------------
  function renderAll() {
    renderDashboard();
    renderPoids();
    renderAlim();
    renderEntr();
    renderPasList();
    renderSyncStatus();
  }

  // ---------------------------------------------------------------
  // Recalcul quotidien du décompte
  // ---------------------------------------------------------------
  function scheduleDailyRefresh() {
    let dernierJour = todayISO();
    setInterval(() => {
      if (todayISO() !== dernierJour) {
        dernierJour = todayISO();
        renderDashboard();
      }
    }, 60 * 1000); // vérifie chaque minute le changement de jour
  }

  // ---------------------------------------------------------------
  // Service worker
  // ---------------------------------------------------------------
  function registerSW() {
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('./service-worker.js').catch((e) =>
          console.warn('Service worker non enregistré :', e));
      });
    }
  }

  // ===============================================================
  // PAS (nombre de pas par jour)
  // ===============================================================
  // Enregistre/met à jour les pas d'une date donnée (un seul total par jour).
  function setPas(dateISO, valeur) {
    const v = num(valeur);
    if (!dateISO || v <= 0) return;
    const existant = state.pas.find((p) => p.date === dateISO);
    if (existant) existant.pas = v;
    else state.pas.push({ id: uid(), date: dateISO, pas: v });
  }

  // Total des pas sur les 7 derniers jours (date >= aujourd'hui - 6).
  function pas7j() {
    const limite = new Date(parseISO(todayISO()).getTime() - 6 * 86400000);
    return state.pas
      .filter((p) => parseISO(p.date) >= limite)
      .reduce((t, p) => t + num(p.pas), 0);
  }

  function initPasForm() {
    const f = $('#form-pas');
    if (!f) return;
    f.date.value = todayISO();
    f.addEventListener('submit', (e) => {
      e.preventDefault();
      setPas(f.date.value, f.pas.value);
      saveState();
      f.pas.value = '';
      renderPasList();
      renderDashboard();
      maybeAutoSync();
      flashMsg('Pas enregistrés.');
    });
  }

  function renderPasList() {
    const host = $('#pas-list');
    if (!host) return;
    const tri = [...state.pas].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 14);
    if (!tri.length) { host.innerHTML = '<p class="list-empty">Aucun pas enregistré.</p>'; return; }
    host.innerHTML = tri.map((p) => `<div class="list-item">
      <div class="li-head">
        <div><div class="li-main">${num(p.pas).toLocaleString('fr-FR')} pas</div>
        <div class="li-date">${fmtDateFR(p.date)}</div></div>
        <button class="li-del" data-kind="pas" data-id="${p.id}">Supprimer</button>
      </div></div>`).join('');
  }

  // ===============================================================
  // SYNCHRONISATION GITHUB (le repo sert de stockage distant)
  // Le jeton reste en local sur l'appareil ; il n'est jamais dans le code.
  // ===============================================================
  const GH_API = 'https://api.github.com';

  // Encode une chaîne UTF-8 en base64 (compatible accents).
  function toB64(str) { return btoa(unescape(encodeURIComponent(str))); }

  // Encode un chemin de fichier segment par segment (conserve les « / »).
  function encPath(p) { return String(p).split('/').map(encodeURIComponent).join('/'); }

  function syncConfigured() {
    return sync.token && sync.owner && sync.repo && sync.path && sync.branch;
  }

  async function ghGetSha() {
    // Récupère le SHA du fichier distant (nécessaire pour le mettre à jour).
    const url = `${GH_API}/repos/${sync.owner}/${sync.repo}/contents/${encPath(sync.path)}?ref=${encodeURIComponent(sync.branch)}`;
    const res = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${sync.token}`,
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28'
      }
    });
    if (res.status === 404) return null;        // le fichier n'existe pas encore
    if (!res.ok) throw new Error('GET ' + res.status);
    const j = await res.json();
    return j.sha;
  }

  // Envoie l'état courant vers GitHub (création ou mise à jour du fichier).
  async function pushData(silent) {
    if (!syncConfigured()) { if (!silent) setSyncMsg('Configure d\'abord le jeton GitHub.', true); return false; }
    try {
      if (!silent) setSyncMsg('Envoi en cours…');
      const payload = {
        version: 1,
        majLe: new Date().toISOString(),
        data: state
      };
      let sha = null;
      try { sha = await ghGetSha(); } catch (e) { /* on tentera sans sha */ }
      const body = {
        message: `maj suivi ${todayISO()}`,
        content: toB64(JSON.stringify(payload, null, 2)),
        branch: sync.branch
      };
      if (sha) body.sha = sha;
      const url = `${GH_API}/repos/${sync.owner}/${sync.repo}/contents/${encPath(sync.path)}`;
      const res = await fetch(url, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${sync.token}`,
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28'
        },
        body: JSON.stringify(body)
      });
      if (!res.ok) throw new Error('PUT ' + res.status);
      sync.lastSync = new Date().toISOString();
      saveSync();
      renderSyncStatus();
      if (!silent) setSyncMsg('Données envoyées ✓');
      return true;
    } catch (e) {
      if (!silent) setSyncMsg('Échec de l\'envoi (' + e.message + '). Vérifie le jeton et le dépôt.', true);
      return false;
    }
  }

  // Récupère l'état depuis GitHub et remplace les données locales.
  async function pullData() {
    if (!syncConfigured()) { setSyncMsg('Configure d\'abord le jeton GitHub.', true); return; }
    if (!confirm('Remplacer les données locales par celles du dépôt ?')) return;
    try {
      setSyncMsg('Récupération…');
      const url = `${GH_API}/repos/${sync.owner}/${sync.repo}/contents/${encPath(sync.path)}?ref=${encodeURIComponent(sync.branch)}`;
      const res = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${sync.token}`,
          'Accept': 'application/vnd.github.raw',
          'X-GitHub-Api-Version': '2022-11-28'
        }
      });
      if (!res.ok) throw new Error('GET ' + res.status);
      const parsed = JSON.parse(await res.text());
      const data = parsed.data || parsed;
      state = {
        settings: Object.assign({}, DEFAULTS.settings, data.settings || {}),
        poids: Array.isArray(data.poids) ? data.poids : [],
        alimentation: Array.isArray(data.alimentation) ? data.alimentation : [],
        entrainement: Array.isArray(data.entrainement) ? data.entrainement : [],
        pas: Array.isArray(data.pas) ? data.pas : []
      };
      saveState();
      fillParamsForm();
      renderAll();
      setSyncMsg('Données récupérées ✓');
    } catch (e) {
      setSyncMsg('Échec de la récupération (' + e.message + ').', true);
    }
  }

  // Envoi silencieux automatique après chaque enregistrement (si activé).
  let autoSyncTimer = null;
  function maybeAutoSync() {
    if (!sync.auto || !syncConfigured()) return;
    // Léger anti-rebond pour regrouper des saisies rapprochées.
    clearTimeout(autoSyncTimer);
    autoSyncTimer = setTimeout(() => pushData(true), 1200);
  }

  function setSyncMsg(txt, isError) {
    const el = $('#sync-msg');
    if (!el) return;
    el.textContent = txt;
    el.style.color = isError ? 'var(--danger)' : 'var(--green-soft)';
  }

  function renderSyncStatus() {
    const ind = $('#sync-indicator');
    if (ind) {
      if (!syncConfigured()) ind.textContent = '';
      else if (sync.lastSync) ind.textContent = '☁︎ Synchro : ' + new Date(sync.lastSync).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
      else ind.textContent = '☁︎ Synchro configurée';
    }
    const stat = $('#sync-last');
    if (stat) stat.textContent = sync.lastSync ? new Date(sync.lastSync).toLocaleString('fr-FR') : 'jamais';
  }

  function fillSyncForm() {
    const f = $('#form-sync');
    if (!f) return;
    f.token.value = sync.token || '';
    f.owner.value = sync.owner || '';
    f.repo.value = sync.repo || '';
    f.branch.value = sync.branch || '';
    f.path.value = sync.path || '';
    f.auto.checked = !!sync.auto;
    renderSyncStatus();
  }

  function initSync() {
    const f = $('#form-sync');
    if (!f) return;
    f.addEventListener('submit', (e) => {
      e.preventDefault();
      sync.token = f.token.value.trim();
      sync.owner = f.owner.value.trim();
      sync.repo = f.repo.value.trim();
      sync.branch = f.branch.value.trim();
      sync.path = f.path.value.trim();
      sync.auto = f.auto.checked;
      saveSync();
      renderSyncStatus();
      setSyncMsg('Réglages de synchro enregistrés.');
    });
    $('#btn-sync-push').addEventListener('click', () => pushData(false));
    $('#btn-sync-pull').addEventListener('click', () => pullData());
  }

  // ===============================================================
  // INGESTION PAR URL (pour le Raccourci iPhone)
  // Ex : ?pas=8500  ou  ?pas=8500&date=2026-06-05  ou  ?poids=151.2
  // Après ingestion, l'app enregistre, synchronise puis nettoie l'URL.
  // ===============================================================
  function ingestURLParams() {
    const params = new URLSearchParams(location.search);
    if (![...params.keys()].length) return;
    const date = params.get('date') || todayISO();
    let changed = false;

    if (params.has('pas')) { setPas(date, params.get('pas')); changed = true; }

    if (params.has('poids')) {
      const v = num(params.get('poids'));
      if (v > 0) {
        state.poids.push({ id: uid(), date, poids: v, tourTaille: '', note: 'via raccourci' });
        changed = true;
      }
    }

    if (changed) {
      saveState();
      maybeAutoSync();
      // Nettoie l'URL pour éviter une double saisie au rechargement.
      history.replaceState(null, '', location.pathname);
    }
  }

  // ---------------------------------------------------------------
  // Démarrage
  // ---------------------------------------------------------------
  function init() {
    initTabs();
    initForms();
    initIO();
    initPasForm();
    initSync();
    fillParamsForm();
    fillSyncForm();
    ingestURLParams();
    renderAll();
    showView('accueil');
    scheduleDailyRefresh();
    registerSW();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
