/* ============================================================
   BOOT — shell wiring, command palette, settings, keyboard
   ============================================================ */

function buildShell() {
  const tabs = $('#tabs');
  tabs.innerHTML = '';
  MODES.forEach(([id, nm]) => {
    const b = el('button', { class:'tab', 'data-v':id, role:'tab', 'aria-selected':'false',
                             'aria-controls':'stage', tabindex:'-1',
                             text:nm, onclick: () => go(id) });
    tabs.appendChild(b);
  });
  /* The tablist pattern requires arrow-key traversal with a single tab stop,
     otherwise the roles promise a keyboard behaviour that is not there. */
  tabs.addEventListener('keydown', e => {
    const items = $$('.tab', tabs);
    const i = items.indexOf(document.activeElement);
    if (i < 0) return;
    let n = null;
    if (e.key === 'ArrowRight') n = (i + 1) % items.length;
    else if (e.key === 'ArrowLeft') n = (i - 1 + items.length) % items.length;
    else if (e.key === 'Home') n = 0;
    else if (e.key === 'End') n = items.length - 1;
    if (n === null) return;
    e.preventDefault();
    items[n].focus();
    go(items[n].dataset.v);
  });
  $('#brandlink').addEventListener('click', () => go('today'));
  $('#cmdbtn').addEventListener('click', openPalette);
  $('#setbtn').addEventListener('click', openSettings);
  $('#streak').addEventListener('click', () => go('progress'));
  if (S.streak.n) countUp($('#streakn'), S.streak.n, 620);
  $('#scrim').addEventListener('click', closeModal);
  Act.init();
}

/* ---------------------------------------------------------- command palette
   Grouped, with the actions the engine can take at the top. Typing filters
   across every paper, case, theme and concept in the build. */
function paletteItems() {
  const out = [];
  const A = (t, s, ic, fn) => out.push({ t, s, ic, g:'Actions', go: fn });
  A('Start a session', PLAN_MIN + ' min · adaptive', 'drill', () => startDrill(PLAN_MIN));
  A('Start a 12-minute session', 'adaptive', 'clock', () => startDrill(12));
  A('Start a 25-minute session', 'adaptive', 'clock', () => startDrill(25));
  A('Start a 45-minute session', 'adaptive', 'clock', () => startDrill(45));
  A('Toggle theme', S.theme === 'dark' ? 'to light' : 'to dark', 'theme', toggleTheme);
  A('Settings', 'date, courses, your data', 'gear', openSettings);
  A('Keyboard shortcuts', 'and how to turn the single-key ones off', 'go', showShortcuts);

  MODES.forEach(([id, nm, desc]) => out.push({ t: nm, s: desc, ic:'go', g:'Go to', go: () => go(id) }));
  out.push({ t:'The Atlas', s:'concept map', ic:'atlas', g:'Go to', go: () => go('atlas') });
  out.push({ t:'The Ledger', s:'your errors', ic:'ledger', g:'Go to', go: () => go('ledger') });
  SURFACES.forEach(([id, nm, mk, dom, blurb]) => out.push({ t: nm, s: blurb.split('.')[0], ic: mk, g:'Go to', go: () => go(id) }));

  DATA.written.exercises.forEach(e => out.push({
    t: e.title, s:`${e.course} ${e.year} · ${e.minutes} min`, ic:'bench', g:'Written papers',
    go: () => { EXAM = null; go('papers'); benchStart($('#stage'), e.id); } }));
  DATA.interview.themes.forEach(t => out.push({ t: t.label, s:'interview theme', ic:'panel', g:'Interview themes',
    go: () => { go('panel'); showTheme(t.id); } }));
  DATA.formulation.vignettes.forEach(v => out.push({ t: v.title, s: v.source, ic:'studio', g:'Cases',
    go: () => go('studio', v.id) }));
  DATA.roleplay.scenarios.forEach(r => out.push({ t: r.title, s: r.source, ic:'room', g:'Role-plays',
    go: () => { RP = { s:r, turn:0, score:0, max:0, log:[] }; go('room'); } }));
  DATA.concepts.nodes.forEach(n => out.push({ t: n.label, s: n.domain + ' · ' + (CLUSTER_LABEL[n.cluster] || n.cluster),
    ic:'atlas', g:'Concepts', go: () => showConcept(n.id) }));
  return out;
}
let PAL = null;
function openPalette() {
  PAL = paletteItems();
  const input = el('input', { type:'text', class:'cmdinput', role:'combobox', 'aria-expanded':'true',
                             'aria-controls':'cmdlist', 'aria-autocomplete':'list',
                             'aria-label':'Search actions, papers, themes, cases and concepts',
                             placeholder:'Search actions, papers, themes, cases, concepts…' });
  const list = el('div', { class:'cmdlist', id:'cmdlist', role:'listbox',
                           'aria-label':'Results' });
  let sel = 0, shown = [];

  function render(q) {
    const ql = q.toLowerCase().trim();
    shown = (ql ? PAL.filter(x => (x.t + ' ' + (x.s || '')).toLowerCase().includes(ql)) : PAL).slice(0, 60);
    sel = 0; list.innerHTML = '';
    let group = null;
    shown.forEach((x, i) => {
      if (x.g !== group) { group = x.g; list.appendChild(el('div', { class:'cmdgroup', text: group })); }
      const r = el('div', { class:'cmditem' + (i === 0 ? ' on' : ''), 'data-i':i,
                            id:'cmdopt' + i, role:'option',
                            'aria-selected': i === 0 ? 'true' : 'false',
                            onclick: () => { closeModal(); x.go(); } });
      r.innerHTML = `<span class="ci">${icon(x.ic || 'go', 16)}</span>
        <span class="ct">${esc(x.t)}</span><span class="h">${esc(x.s || '')}</span>`;
      list.appendChild(r);
    });
    if (!shown.length) list.appendChild(el('div', { class:'empty', style:'padding:34px', text:'Nothing matches' }));
    input.setAttribute('aria-activedescendant', shown.length ? 'cmdopt0' : '');
    announce(shown.length ? `${shown.length} result${shown.length === 1 ? '' : 's'}` : 'Nothing matches');
  }
  function move(d) {
    sel = Math.max(0, Math.min(shown.length - 1, sel + d));
    $$('.cmditem', list).forEach(r => {
      const isOn = +r.dataset.i === sel;
      r.classList.toggle('on', isOn);
      r.setAttribute('aria-selected', isOn ? 'true' : 'false');
    });
    const on = $('.cmditem.on', list);
    if (on) { on.scrollIntoView({ block:'nearest' }); input.setAttribute('aria-activedescendant', on.id); }
  }
  input.addEventListener('input', () => render(input.value));
  input.addEventListener('keydown', e => {
    if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
    else if (e.key === 'Enter' && shown[sel]) { closeModal(); shown[sel].go(); }
  });

  const foot = el('div', { class:'cmdfoot' });
  foot.innerHTML = `<span><kbd>↑</kbd><kbd>↓</kbd> move</span><span><kbd>↵</kbd> open</span><span><kbd>esc</kbd> close</span>`;

  const m = $('#modal');
  MODAL_RETURN = document.activeElement;
  m.innerHTML = '';
  m.setAttribute('aria-label', 'Command palette');
  m.removeAttribute('aria-labelledby');
  m.append(input, list, foot);
  m.removeAttribute('hidden');
  m.classList.add('on'); $('#scrim').classList.add('on');
  document.addEventListener('keydown', trapTab, true);
  render('');
  setTimeout(() => input.focus(), 60);
}

function toggleTheme() {
  S.theme = S.theme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', S.theme);
  save();
  if (VIEW === 'atlas') go('atlas');
  toast(S.theme === 'dark' ? 'Dark' : 'Light');
}

/* ---------------------------------------------------------- settings */
function exportProgress() {
  const blob = new Blob([JSON.stringify(S, null, 1)], { type:'application/json' });
  const a = el('a', { href: URL.createObjectURL(blob),
                      download: 'dclinpsy-progress-' + new Date().toISOString().slice(0, 10) + '.json' });
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 4000);
  toast('Progress exported');
}

function openSettings() {
  const body = el('div');

  body.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text:'Interview date' }));
  body.appendChild(el('p', { class:'src', style:'margin-bottom:11px',
    text:'This changes the scheduler. Inside 45 days review intervals tighten; inside 14 they halve, and sessions shift from acquiring material to retrieving it fast.' }));
  const dt = el('input', { type:'date', value: S.interviewDate || '' });
  dt.addEventListener('change', () => { S.interviewDate = dt.value || null; save(); if (VIEW === 'today') go('today'); });
  body.appendChild(dt);

  body.appendChild(el('div', { class:'lbl', style:'margin:24px 0 8px', text:'Your courses' }));
  const cw = el('div', { class:'card flat' });
  cw.innerHTML = `<p style="font-size:14px;color:var(--ink-2);margin:0 0 10px">
    <b>Cardiff · UCL · UEA</b>, with a fourth slot open. Cardiff is the only one of the three represented in the past-paper corpus, so Cardiff-specific guidance here is evidence-based and the rest is general. Verify every course's current selection process on its own site — these change year to year.</p>
    <p style="font-size:14px;color:var(--ink-2);margin:0">The corpus also covers Birmingham, Coventry &amp; Warwick, Exeter, Glasgow, Plymouth, Southampton and South Wales. Those papers are worth doing whatever your four are: the reasoning they test is common to all of them.</p>`;
  body.appendChild(cw);

  body.appendChild(el('div', { class:'lbl', style:'margin:24px 0 8px', text:'Preferences' }));
  const prefs = el('div', { class:'row wrap' });
  prefs.appendChild(segEl([['light','Light'], ['dark','Dark']], S.theme || 'light',
    v => { if (S.theme !== v) toggleTheme(); }));
  prefs.appendChild(segEl([[false,'Silent'], [true,'Sounds']], !!S.sound,
    v => { S.sound = v; save(); if (v) tick(880, .08, .05); }));
  body.appendChild(prefs);

  body.appendChild(el('div', { class:'lbl', style:'margin:24px 0 8px', text:'Your data' }));
  body.appendChild(el('p', { class:'src', style:'margin-bottom:11px',
    text:'Everything is stored in this browser only. Nothing is sent anywhere. Clearing site data erases your progress, so export it if you care about it.' }));
  const data = el('div', { class:'row wrap' });
  data.appendChild(el('button', { class:'btn sm', text:'Export', onclick: exportProgress }));
  const imp = el('input', { type:'file', accept:'.json', style:'display:none' });
  imp.addEventListener('change', () => {
    const f = imp.files[0]; if (!f) return;
    const r = new FileReader();
    r.onload = () => {
      try { S = Object.assign(blankState(), JSON.parse(r.result)); save(); closeModal(); go('today'); toast('Progress restored'); }
      catch (e) { toast('Could not read that file'); }
    };
    r.readAsText(f);
  });
  data.append(el('button', { class:'btn sm', text:'Import', onclick: () => imp.click() }), imp);
  data.appendChild(el('button', { class:'btn sm ghost', text:'Reset everything', onclick: () => {
    confirmDialog({
      title: 'Erase all progress?',
      text: 'Every answer, every scheduled review, your calibration record and your error ledger. ' +
            'This cannot be undone.',
      note: 'Export first if there is any chance you want it back — the file restores everything.',
      cancel: 'Keep my progress',
      third: 'Export first',
      danger: true,
      confirm: 'Erase everything',
      onThird: exportProgress,
      onConfirm: () => { S = blankState(); save(); go('today'); toast('Progress erased'); },
    });
  }}));
  body.appendChild(data);

  const cal = calibration();
  const stats = el('div', { class:'card flat', style:'margin-top:24px' });
  stats.innerHTML = `<div class="lbl">In this build</div>
    <p class="src" style="margin-top:8px">
      ${DATA.concepts.nodes.length} concepts · ${DATA.items.items.length} drill items ·
      ${DATA.written.exercises.length} written papers (${DATA.written.exercises.reduce((a,e)=>a+e.questions.reduce((b,q)=>b+q.rubric.length,0),0)} marking points) ·
      ${DATA.interview.questions.length} verbatim interview questions ·
      ${DATA.formulation.vignettes.length} multi-model cases · ${DATA.roleplay.scenarios.length} role-plays.<br><br>
      You have answered ${cal.n} confidence-rated item${cal.n === 1 ? '' : 's'} across ${Object.keys(S.c).length} concept${Object.keys(S.c).length === 1 ? '' : 's'}.</p>`;
  body.appendChild(stats);

  openModal('Settings', body);
}

/* ---------------------------------------------------------- first run
   One sentence and a way in. The three mechanics that used to be explained
   here — confidence, the depth ladder, adjudicated marking — are taught at
   the moment they first apply instead, where they mean something. */
function intro() {
  const body = el('div');
  body.innerHTML = `
    <p style="font-size:17px;line-height:1.55;margin-bottom:6px">
      Built from real material: past interview questions from eight courses, five written
      papers, and one official marking scheme.</p>
    <p class="src" style="margin-top:14px">Everything stays in this browser. Nothing is sent anywhere.</p>`;
  const b = el('button', { class:'btn pri lg wide', style:'margin-top:20px',
    text: 'Start the diagnostic — 12 items',
    onclick: () => { S.seenIntro = true; save(); closeModal(); startDrill(12); } });
  body.appendChild(b);
  const later = el('button', { class:'btn ghost wide', style:'margin-top:8px', text:'Look around first',
    onclick: () => { S.seenIntro = true; save(); closeModal(); } });
  body.appendChild(later);
  openModal('DClinPsy Trainer', body);
}

/* ---------------------------------------------------------- teaching moments
   Each fires once, the first time the thing it explains is on screen. This is
   what replaces the wall of text: the explanation arrives with the control. */
function coach(id, title, text) {
  S.coached = S.coached || {};
  if (S.coached[id]) return false;
  /* Never replace a dialog that is already open — a teaching prompt must not
     stomp a confirmation the learner is in the middle of answering. Leave it
     unmarked so it fires the next time the control appears. */
  if ($('#modal').classList.contains('on')) return false;
  S.coached[id] = Date.now(); save();
  const body = el('div');
  body.appendChild(el('p', { style:'font-size:15.5px;line-height:1.6;margin:0', text }));
  const b = el('button', { class:'btn pri wide', style:'margin-top:18px', text:'Got it',
                           onclick: closeModal });
  body.appendChild(b);
  openModal(title, body);
  return true;
}
const COACH = {
  confidence: ['Rate your confidence first',
    'Every item asks how sure you are before you answer. Being sure and wrong is the most ' +
    'important signal here — those items come back the same day, ahead of everything else.'],
  depth: ['Depth is earned level by level',
    'Recognising something never counts as mastering it. A concept only advances when you ' +
    'pass an item at that level, and a failed transfer item takes depth back.'],
  marking: ['You mark it, not the matcher',
    'Your text is scanned against each rubric point, then you confirm or override every tick. ' +
    'The matcher is literal and you are not — and that comparison is the exercise.'],
};
function coachOn(id) { const c = COACH[id]; return c ? coach(id, c[0], c[1]) : false; }

/* ---------------------------------------------------------- keyboard */
function showShortcuts() {
  const rows = [
    ['⌘K / Ctrl K', 'Command palette — every mode, paper, theme, case and concept'],
    ['?',           'This list'],
    ['1 – 5',       'Rate confidence on the open item'],
    ['A – F',       'Pick an answer'],
    ['↵',           'Continue past a result'],
    ['Esc',         'Close a dialog, or leave a session'],
    ['← →',         'Move between the three tabs when one is focused'],
  ];
  const body = el('div');
  const t = el('div', { class:'plate' });
  rows.forEach(([k, what]) => {
    const r = el('div', { class:'prow' });
    r.innerHTML = `<span style="flex:none;min-width:104px"><kbd>${esc(k)}</kbd></span>
      <span class="pmain"><span class="pname" style="font-weight:500">${esc(what)}</span></span>`;
    t.appendChild(r);
  });
  body.appendChild(t);
  const foot = el('div', { class:'row', style:'margin-top:18px;gap:12px' });
  foot.appendChild(el('span', { class:'src', style:'flex:1 1 auto',
    text: S.noHotkeys ? 'Single-key shortcuts are off. ⌘K and Esc still work.'
                      : 'Single-key shortcuts act only while an item is open.' }));
  foot.appendChild(el('button', { class:'btn sm',
    text: S.noHotkeys ? 'Turn single-key shortcuts on' : 'Turn single-key shortcuts off',
    onclick: () => { S.noHotkeys = !S.noHotkeys; save(); closeModal(); setTimeout(showShortcuts, 80); } }));
  body.appendChild(foot);
  openModal('Keyboard', body);
}

function keys() {
  document.addEventListener('keydown', e => {
    const t = e.target;
    const typing = !!(t && t.matches && t.matches('input, textarea, select'));
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); return; }
    if (e.key === 'Escape') {
      if ($('#modal').classList.contains('on')) { closeModal(); return; }
      if (SESSION && VIEW === 'drill') { quitDrill(); return; }
      return;
    }
    if (e.key === '?' && !typing) { e.preventDefault(); showShortcuts(); return; }
    if (typing || e.metaKey || e.ctrlKey || e.altKey) return;
    /* Single-character shortcuts can be turned off (WCAG 2.1.4). They only
       ever act on an open item, but a switch user driving speech input needs
       to be able to stop them firing at all. */
    if (S.noHotkeys) return;
    // 1-5 sets confidence while an item is open
    if (/^[1-5]$/.test(e.key)) {
      const pip = $$('#actbar .pip')[+e.key - 1];
      if (pip) { e.preventDefault(); pip.click(); return; }
    }
    // a-f picks a choice
    if (/^[a-f]$/i.test(e.key)) {
      const i = e.key.toLowerCase().charCodeAt(0) - 97;
      const ch = $$('.choices > .choice:not(.locked)')[i];
      if (ch) { e.preventDefault(); ch.click(); }
    }
  });
}

/* ---------------------------------------------------------- go */
function boot() {
  load();
  document.documentElement.setAttribute('data-theme', S.theme || 'light');
  buildIndex();
  buildShell();
  keys();
  /* An answer given in the last 220ms before the tab closes used to be lost
     with the pending debounce. */
  document.addEventListener('visibilitychange', () => { if (document.hidden) flushSave(); });
  window.addEventListener('pagehide', flushSave);
  window.addEventListener('popstate', () => applyRoute(true));
  window.addEventListener('hashchange', () => applyRoute(true));
  applyRoute();
  if (!S.seenIntro) setTimeout(intro, 460);
  let rt = null;
  window.addEventListener('resize', () => {
    clearTimeout(rt);
    rt = setTimeout(() => { if (VIEW === 'atlas') go('atlas'); }, 240);
  });
}
document.addEventListener('DOMContentLoaded', boot);
