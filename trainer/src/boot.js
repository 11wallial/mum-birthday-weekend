/* ============================================================
   BOOT — shell wiring, command palette, settings, keyboard
   ============================================================ */

function buildShell() {
  const tabs = $('#tabs');
  tabs.innerHTML = '';
  MODES.forEach(([id, nm]) => {
    const b = el('button', { class:'tab', 'data-v':id, role:'tab', 'aria-selected':'false',
                             text:nm, onclick: () => go(id) });
    tabs.appendChild(b);
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

  MODES.forEach(([id, nm, desc]) => out.push({ t: nm, s: desc, ic:'go', g:'Go to', go: () => go(id) }));
  out.push({ t:'The Atlas', s:'concept map', ic:'atlas', g:'Go to', go: () => go('atlas') });
  out.push({ t:'The Ledger', s:'your errors', ic:'ledger', g:'Go to', go: () => go('ledger') });
  SURFACES.forEach(([id, nm, mk, dom, blurb]) => out.push({ t: nm, s: blurb.split('.')[0], ic: mk, g:'Go to', go: () => go(id) }));

  DATA.written.exercises.forEach(e => out.push({
    t: e.title, s:`${e.course} ${e.year} · ${e.minutes} min`, ic:'bench', g:'Written papers',
    go: () => { EXAM = null; go('bench'); benchStart($('#stage'), e.id); } }));
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
  const input = el('input', { type:'text', class:'cmdinput', placeholder:'Search actions, papers, themes, cases, concepts…' });
  const list = el('div', { class:'cmdlist' });
  let sel = 0, shown = [];

  function render(q) {
    const ql = q.toLowerCase().trim();
    shown = (ql ? PAL.filter(x => (x.t + ' ' + (x.s || '')).toLowerCase().includes(ql)) : PAL).slice(0, 60);
    sel = 0; list.innerHTML = '';
    let group = null;
    shown.forEach((x, i) => {
      if (x.g !== group) { group = x.g; list.appendChild(el('div', { class:'cmdgroup', text: group })); }
      const r = el('div', { class:'cmditem' + (i === 0 ? ' on' : ''), 'data-i':i,
                            onclick: () => { closeModal(); x.go(); } });
      r.innerHTML = `<span class="ci">${icon(x.ic || 'go', 16)}</span>
        <span class="ct">${esc(x.t)}</span><span class="h">${esc(x.s || '')}</span>`;
      list.appendChild(r);
    });
    if (!shown.length) list.appendChild(el('div', { class:'empty', style:'padding:34px', text:'Nothing matches' }));
  }
  function move(d) {
    sel = Math.max(0, Math.min(shown.length - 1, sel + d));
    $$('.cmditem', list).forEach(r => r.classList.toggle('on', +r.dataset.i === sel));
    const on = $('.cmditem.on', list); if (on) on.scrollIntoView({ block:'nearest' });
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
  m.innerHTML = '';
  m.append(input, list, foot);
  m.classList.add('on'); $('#scrim').classList.add('on');
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
  data.appendChild(el('button', { class:'btn sm', text:'Export', onclick: () => {
    const blob = new Blob([JSON.stringify(S, null, 1)], { type:'application/json' });
    const a = el('a', { href: URL.createObjectURL(blob), download:'dclinpsy-progress.json' });
    document.body.appendChild(a); a.click(); a.remove();
  }}));
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
    if (confirm('This erases all progress, permanently. Continue?')) { S = blankState(); save(); closeModal(); go('today'); }
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

/* ---------------------------------------------------------- first run */
function intro() {
  const body = el('div');
  body.innerHTML = `
    <p style="font-size:16px;line-height:1.6;margin-bottom:16px">A preparation engine for DClinPsy selection, built from real material: past interview questions from eight courses, four written papers, and one official marking scheme.</p>
    <p style="font-size:15px;color:var(--ink-2);line-height:1.6;margin-bottom:14px"><b style="color:var(--ink)">Confidence is compulsory.</b> Every item asks how sure you are before you answer. Being sure and wrong is the most important signal here, and those items come back the same day.</p>
    <p style="font-size:15px;color:var(--ink-2);line-height:1.6;margin-bottom:14px"><b style="color:var(--ink)">Depth is earned level by level.</b> Recognising something never counts as mastering it. A concept only advances when you pass an item at that level, and a failed transfer item takes depth back.</p>
    <p style="font-size:15px;color:var(--ink-2);line-height:1.6;margin-bottom:18px"><b style="color:var(--ink)">Written answers are matched, not marked.</b> Your text is scanned against each rubric point and then <em>you</em> adjudicate every tick. That comparison is the exercise — it is what makes a past paper worth more than a textbook.</p>
    <p class="src">Everything stays in this browser. Nothing is sent anywhere.</p>`;
  const b = el('button', { class:'btn pri lg wide', style:'margin-top:22px', text:'Begin',
    onclick: () => { S.seenIntro = true; save(); closeModal(); } });
  body.appendChild(b);
  openModal('Before you start', body);
}

/* ---------------------------------------------------------- keyboard */
function keys() {
  document.addEventListener('keydown', e => {
    const typing = e.target.matches('input,textarea,select');
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); return; }
    if (e.key === 'Escape') {
      if ($('#modal').classList.contains('on')) { closeModal(); return; }
      if (SESSION && VIEW === 'drill') { quitDrill(); return; }
      return;
    }
    if (typing || e.metaKey || e.ctrlKey || e.altKey) return;
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
  go(S.lastMode && MODES.some(m => m[0] === S.lastMode) ? S.lastMode : 'today');
  if (!S.seenIntro) setTimeout(intro, 460);
  let rt = null;
  window.addEventListener('resize', () => {
    clearTimeout(rt);
    rt = setTimeout(() => { if (VIEW === 'atlas') go('atlas'); }, 240);
  });
}
document.addEventListener('DOMContentLoaded', boot);
