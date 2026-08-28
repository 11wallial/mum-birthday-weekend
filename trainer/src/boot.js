/* ============================================================
   BOOT — shell wiring, command palette, settings, keyboard
   ============================================================ */

function buildShell() {
  const top = $('#top');
  const tabs = $('#tabs');
  MODES.forEach(([id, nm, key]) => {
    const b = el('button', { class:'tab', 'data-v':id, role:'tab', 'aria-selected':'false',
                             onclick: () => go(id) });
    b.innerHTML = `${nm}<span class="k">${key}</span>`;
    tabs.appendChild(b);
  });

  $('#railbtn').addEventListener('click', () => document.body.classList.toggle('rail'));
  $('#cmdbtn').addEventListener('click', openPalette);
  $('#setbtn').addEventListener('click', openSettings);
  $('#themebtn').addEventListener('click', () => {
    S.theme = S.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', S.theme);
    save(); if (VIEW === 'atlas') go('atlas');
  });
  $('#scrim').addEventListener('click', closeModal);

  const d2i = daysToInterview();
  const chip = $('#datechip');
  chip.classList.toggle('nodate', d2i === null);
  chip.innerHTML = d2i === null
    ? '<span>Set interview date</span>'
    : `<b>${d2i}</b><span>days to interview</span>`;
  chip.addEventListener('click', openSettings);
}

/* ---------------------------------------------------------- command palette */
function paletteItems() {
  const out = [];
  MODES.forEach(([id, nm, key, desc]) => out.push({ t:nm, s:desc, h:key, go:() => go(id) }));
  out.push({ t:'Start a short session', s:'12 minutes, adaptive', h:'', go:() => startDrill(12) });
  out.push({ t:'Start a standard session', s:'25 minutes, adaptive', h:'', go:() => startDrill(25) });
  DATA.written.exercises.forEach(e => out.push({
    t:'Paper — ' + e.title, s:`${e.course} ${e.year} · ${e.minutes} min`, h:'', go:() => { EXAM=null; go('bench'); benchStart($('#stage'), e.id); } }));
  DATA.formulation.vignettes.forEach(v => out.push({ t:'Case — ' + v.title, s:v.source, h:'', go:() => go('studio', v.id) }));
  DATA.roleplay.scenarios.forEach(r => out.push({ t:'Role-play — ' + r.title, s:r.source, h:'', go:() => { RP = { s:r, turn:0, score:0, max:0, log:[] }; go('room'); } }));
  DATA.interview.themes.forEach(t => out.push({ t:'Theme — ' + t.label, s:'interview', h:'', go:() => { go('panel'); showTheme(t.id); } }));
  DATA.concepts.nodes.forEach(n => out.push({ t:n.label, s:n.domain + ' · ' + n.cluster, h:'', go:() => showConcept(n.id) }));
  return out;
}
let PAL = null;
function openPalette() {
  PAL = PAL || paletteItems();
  const body = el('div');
  const input = el('input', { type:'text', class:'cmdinput', placeholder:'Search modes, papers, cases, concepts…' });
  const list = el('div', { class:'cmdlist' });
  let sel = 0, shown = [];
  function render(q) {
    const ql = q.toLowerCase().trim();
    shown = (ql ? PAL.filter(x => (x.t + ' ' + x.s).toLowerCase().includes(ql)) : PAL).slice(0, 40);
    sel = 0; list.innerHTML = '';
    shown.forEach((x, i) => {
      const r = el('div', { class:'cmditem' + (i === 0 ? ' on' : ''), onclick: () => { closeModal(); x.go(); } });
      r.innerHTML = `<span>${esc(x.t)}</span><span class="h">${esc(x.s || '')}${x.h ? ' · ' + x.h : ''}</span>`;
      list.appendChild(r);
    });
    if (!shown.length) list.appendChild(el('div', { class:'empty', style:'padding:30px', text:'Nothing matches' }));
  }
  input.addEventListener('input', () => render(input.value));
  input.addEventListener('keydown', e => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      sel = Math.max(0, Math.min(shown.length - 1, sel + (e.key === 'ArrowDown' ? 1 : -1)));
      $$('.cmditem', list).forEach((r, i) => r.classList.toggle('on', i === sel));
      const on = $$('.cmditem', list)[sel]; if (on) on.scrollIntoView({ block:'nearest' });
    } else if (e.key === 'Enter' && shown[sel]) { closeModal(); shown[sel].go(); }
  });
  body.append(input, list);
  const m = $('#modal');
  m.innerHTML = ''; m.appendChild(body);
  m.classList.add('on'); $('#scrim').classList.add('on');
  render('');
  setTimeout(() => input.focus(), 60);
}

/* ---------------------------------------------------------- settings */
function openSettings() {
  const body = el('div');

  body.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text:'Interview date' }));
  body.appendChild(el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:10px',
    text:'Setting this changes the scheduler. Inside 45 days review intervals tighten; inside 14 they halve, and the session shifts from acquiring material to retrieving it fast.' }));
  const dt = el('input', { type:'date', value: S.interviewDate || '' });
  dt.addEventListener('change', () => { S.interviewDate = dt.value || null; save(); buildShell(); renderRail(); });
  body.appendChild(dt);

  body.appendChild(el('div', { class:'lbl', style:'margin:22px 0 8px', text:'Your courses' }));
  const cw = el('div', { class:'panel pad' });
  cw.innerHTML = `<p style="font-size:13px;color:var(--ink-2);margin:0 0 10px">
    <b>Cardiff · UCL · UEA</b>, with a fourth slot open. Cardiff is the only one of the three represented in the past-paper corpus, so Cardiff-specific guidance in this app is evidence-based and the rest is general. Verify every course's current selection process on their own site — these processes change year to year.</p>
    <p style="font-size:13px;color:var(--ink-2);margin:0">The corpus also covers Birmingham, Coventry &amp; Warwick, Exeter, Glasgow, Plymouth, Southampton and South Wales. Those papers are worth doing whatever your four are: the reasoning they test is common to all of them.</p>`;
  body.appendChild(cw);

  body.appendChild(el('div', { class:'lbl', style:'margin:22px 0 8px', text:'Preferences' }));
  const prefs = el('div', { style:'display:flex;gap:10px;flex-wrap:wrap' });
  const snd = el('button', { class:'btn' + (S.sound ? ' pri' : ''), text: S.sound ? 'Timer sounds on' : 'Timer sounds off' });
  snd.addEventListener('click', () => { S.sound = !S.sound; save(); snd.textContent = S.sound ? 'Timer sounds on' : 'Timer sounds off'; snd.classList.toggle('pri', S.sound); if (S.sound) tick(660, .07, .04); });
  prefs.appendChild(snd);
  const thm = el('button', { class:'btn', text: S.theme === 'dark' ? 'Dark theme' : 'Light theme' });
  thm.addEventListener('click', () => { $('#themebtn').click(); thm.textContent = S.theme === 'dark' ? 'Dark theme' : 'Light theme'; });
  prefs.appendChild(thm);
  body.appendChild(prefs);

  body.appendChild(el('div', { class:'lbl', style:'margin:22px 0 8px', text:'Your data' }));
  body.appendChild(el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:10px',
    text:'Everything is stored in this browser only. Nothing is sent anywhere. Clearing site data will erase your progress, so export if you care about it.' }));
  const data = el('div', { style:'display:flex;gap:10px;flex-wrap:wrap' });
  data.appendChild(el('button', { class:'btn', text:'Export progress', onclick: () => {
    const blob = new Blob([JSON.stringify(S, null, 1)], { type:'application/json' });
    const a = el('a', { href: URL.createObjectURL(blob), download:'dclinpsy-progress.json' });
    document.body.appendChild(a); a.click(); a.remove();
  }}));
  const imp = el('input', { type:'file', accept:'.json', style:'display:none' });
  imp.addEventListener('change', () => {
    const f = imp.files[0]; if (!f) return;
    const r = new FileReader();
    r.onload = () => { try { S = Object.assign(blankState(), JSON.parse(r.result)); save(); closeModal(); go('today'); toast('Progress restored'); }
                       catch (e) { toast('Could not read that file'); } };
    r.readAsText(f);
  });
  data.append(el('button', { class:'btn', text:'Import progress', onclick: () => imp.click() }), imp);
  data.appendChild(el('button', { class:'btn ghost', text:'Reset everything', onclick: () => {
    if (confirm('This erases all progress, permanently. Continue?')) { S = blankState(); save(); closeModal(); go('today'); }
  }}));
  body.appendChild(data);

  const stats = el('div', { class:'panel pad', style:'margin-top:22px' });
  const cal = calibration();
  stats.innerHTML = `<div class="lbl">Content in this build</div>
    <p style="font-size:13px;color:var(--ink-2);margin-top:8px;line-height:1.6">
      ${DATA.concepts.nodes.length} concepts · ${DATA.items.items.length} drill items ·
      ${DATA.written.exercises.length} written papers (${DATA.written.exercises.reduce((a,e)=>a+e.questions.reduce((b,q)=>b+q.rubric.length,0),0)} rubric points) ·
      ${DATA.interview.questions.length} verbatim interview questions ·
      ${DATA.formulation.vignettes.length} multi-model cases · ${DATA.roleplay.scenarios.length} role-plays.<br>
      You have answered ${cal.n} confidence-rated items across ${Object.keys(S.c).length} concepts.</p>`;
  body.appendChild(stats);

  openModal('Settings', body);
}

/* ---------------------------------------------------------- first run */
function intro() {
  const body = el('div');
  body.innerHTML = `
    <p style="font-size:15px;line-height:1.62;margin-bottom:14px">This is a preparation engine built from real DClinPsy selection material — past interview questions from eight courses, four written papers, and one official marking scheme.</p>
    <p style="font-size:14px;color:var(--ink-2);line-height:1.62;margin-bottom:14px">Three things worth knowing before you start.</p>
    <p style="font-size:14px;color:var(--ink-2);line-height:1.62;margin-bottom:12px"><b style="color:var(--ink)">Confidence is compulsory.</b> Every item asks how sure you are before you answer. Being confident and wrong is the single most important signal here, and those items come back the same day.</p>
    <p style="font-size:14px;color:var(--ink-2);line-height:1.62;margin-bottom:12px"><b style="color:var(--ink)">Depth is earned at each level separately.</b> Recognising something never counts as mastering it. A concept only advances when you pass an item at that level, and a failed transfer item takes depth back.</p>
    <p style="font-size:14px;color:var(--ink-2);line-height:1.62;margin-bottom:18px"><b style="color:var(--ink)">Free text is matched, not marked.</b> On written papers your answer is scanned against each rubric point and then <em>you</em> adjudicate every tick. That comparison is the exercise — it is what makes a past paper worth more than a textbook.</p>
    <p style="font-size:13px;color:var(--ink-3);line-height:1.55">Everything is stored in this browser. Nothing is sent anywhere.</p>`;
  const b = el('button', { class:'btn pri lg', style:'margin-top:20px', text:'Begin', onclick: () => {
    S.seenIntro = true; save(); closeModal();
  }});
  body.appendChild(b);
  openModal('Before you start', body);
}

/* ---------------------------------------------------------- keyboard */
function keys() {
  document.addEventListener('keydown', e => {
    const typing = e.target.matches('input,textarea,select');
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); return; }
    if (e.key === 'Escape') { closeModal(); return; }
    if (typing || e.metaKey || e.ctrlKey || e.altKey) return;
    const m = MODES.find(x => x[2].toLowerCase() === e.key.toLowerCase());
    if (m) { e.preventDefault(); go(m[0]); return; }
    if (/^[1-5]$/.test(e.key)) {
      const cb = $$('.conf .cb')[+e.key - 1];
      if (cb) { e.preventDefault(); cb.click(); }
    }
  });
}

/* ---------------------------------------------------------- go */
function boot() {
  load();
  document.documentElement.setAttribute('data-theme', S.theme || 'dark');
  buildIndex();
  buildShell();
  keys();
  go(S.lastMode && MODES.some(m => m[0] === S.lastMode) ? S.lastMode : 'today');
  if (!S.seenIntro) setTimeout(intro, 420);
  window.addEventListener('resize', () => { if (VIEW === 'atlas') buildAtlas('all'); });
}
document.addEventListener('DOMContentLoaded', boot);
