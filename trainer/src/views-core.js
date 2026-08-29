/* ============================================================
   VIEWS — shell, router, Today, Practice, Progress, Drill
   ============================================================ */

/* Simple stroke marks. Emoji render inconsistently across platforms and read as
   decoration; these carry the domain colour and stay legible at 21px. */
const ICON = {
  bench:  '<path d="M5 3h9l5 5v13H5z"/><path d="M14 3v5h5"/><path d="M8.5 12.5h7M8.5 16h4.5"/>',
  panel:  '<path d="M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0"/><path d="M12 17.5V21"/>',
  studio: '<path d="M12 3 3.5 7.5 12 12l8.5-4.5z"/><path d="m3.5 12.5 8.5 4.5 8.5-4.5"/>',
  room:   '<path d="M3 6.5A2.5 2.5 0 0 1 5.5 4h7A2.5 2.5 0 0 1 15 6.5v3A2.5 2.5 0 0 1 12.5 12H7l-4 3z"/><path d="M9 15.2c0 1.3 1.1 2.3 2.5 2.3H17l4 3V13a2.5 2.5 0 0 0-2.5-2.5H18"/>',
  drill:  '<path d="M13 2 4.5 13H11l-1 9 8.5-11H12z"/>',
  atlas:  '<circle cx="6" cy="7" r="2.4"/><circle cx="18" cy="6.5" r="2"/><circle cx="12" cy="14" r="2.6"/><circle cx="19" cy="18" r="2"/><path d="M8 8.5 10 12M16.2 7.6 13.4 12M14.2 15.6 17.3 17.2"/>',
  ledger: '<path d="M5 4h14v17l-3-2-2 2-2-2-2 2-2-2-3 2z"/><path d="M9 9h6M9 13h6"/>',
};
function icon(name) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"
    stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICON[name] || ''}</svg>`;
}

const MODES = [
  ['today',    'Today',    'One tap into practice'],
  ['practice', 'Practice', 'Every surface: papers, panels, cases, role-play'],
  ['progress', 'Progress', 'What you hold, what you keep getting wrong'],
];
let VIEW = 'today', TIMERS = [];

function clearTimers() { TIMERS.forEach(t => clearInterval(t)); TIMERS = []; }
function focusMode(on) { document.body.classList.toggle('focus', !!on); }

/* ---------------------------------------------------------- action bar */
const Act = {
  el: null,
  init() { this.el = $('#actbar'); },
  /* a simple action row: [left…] [right…] */
  row(left, right) {
    this.el.className = 'up';
    this.el.innerHTML = '';
    const inner = el('div', { class:'inner' });
    (left || []).forEach(n => n && inner.appendChild(n));
    inner.appendChild(el('div', { class:'spacer' }));
    (right || []).forEach(n => n && inner.appendChild(n));
    this.el.appendChild(inner);
    $('#stage').classList.add('hasact');
  },
  /* a result panel: the bar becomes the explanation */
  result(tone, body, button) {
    this.el.className = 'up ' + (tone || '');
    this.el.innerHTML = '';
    const sc = el('div', { class:'scroller' });
    const bi = el('div', { class:'inner' });
    bi.appendChild(body);
    sc.appendChild(bi);
    this.el.appendChild(sc);
    const ai = el('div', { class:'inner' });
    ai.appendChild(el('div', { class:'spacer' }));
    ai.appendChild(button);
    this.el.appendChild(ai);
    $('#stage').classList.add('hasact');
  },
  hide() {
    if (!this.el) return;
    this.el.className = '';
    $('#stage').classList.remove('hasact');
    setTimeout(() => { if (!this.el.classList.contains('up')) this.el.innerHTML = ''; }, 420);
  },
};

function go(view, arg) {
  clearTimers(); focusMode(false); Act.hide();
  if (MODES.some(m => m[0] === view)) { VIEW = view; S.lastMode = view; save(); }
  $$('#tabs .tab').forEach(t => t.setAttribute('aria-selected', String(t.dataset.v === view)));
  const stage = $('#stage');
  stage.scrollTop = 0;
  stage.innerHTML = '';
  ({ today:vToday, practice:vPractice, progress:vProgress, drill:vDrill,
     bench:vBench, panel:vPanel, studio:vStudio, room:vRoom,
     atlas:vAtlas, ledger:vLedger }[view] || vToday)(stage, arg);
  refreshTop();
}

function refreshTop() {
  const s = $('#streakn');
  if (s) s.textContent = S.streak.n || 0;
  const f = $('#streak');
  if (f) f.style.display = S.streak.n ? '' : 'none';
}

/* ---------------------------------------------------------- shared bits */
function ringEl(pct, size, stroke, colour, label, sub) {
  const r = (size - stroke) / 2, C = 2 * Math.PI * r;
  const w = el('div', { class:'ring', style:`width:${size}px;height:${size}px` });
  w.innerHTML =
    `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
       <circle class="trk" cx="${size/2}" cy="${size/2}" r="${r}" stroke-width="${stroke}"></circle>
       <circle class="val" cx="${size/2}" cy="${size/2}" r="${r}" stroke-width="${stroke}"
               stroke="${colour}" stroke-dasharray="${C}" stroke-dashoffset="${C}"></circle>
     </svg>
     <div class="mid">
       <div class="dnum" style="font-size:${Math.round(size*0.29)}px">${label}</div>
       ${sub ? `<div class="lbl" style="font-size:9.5px;margin-top:1px">${sub}</div>` : ''}
     </div>`;
  requestAnimationFrame(() => {
    const v = $('.val', w); if (v) v.style.strokeDashoffset = C * (1 - Math.max(0, Math.min(100, pct)) / 100);
  });
  return w;
}

function domainRow(d, pct) {
  const row = el('div', { style:'margin-bottom:15px' });
  row.innerHTML =
    `<div class="row" style="margin-bottom:7px">
       <span class="dot ${d}"></span>
       <span style="font-weight:650;font-size:14.5px">${d[0].toUpperCase() + d.slice(1)}</span>
       <span class="spacer" style="flex:1"></span>
       <span class="dnum" style="font-size:15px">${pct}</span>
     </div>
     <div class="meter ${d}"><i></i></div>`;
  requestAnimationFrame(() => { $('i', row).style.width = pct + '%'; });
  return row;
}

/* ---------------------------------------------------------- TODAY */
function vToday(stage) {
  const w = el('div', { class:'wrap stg' });
  const rd = readiness(), d2i = daysToInterview(), due = dueCount();
  const hcw = S.errors.filter(e => e.conf >= 4).length;
  const started = Object.keys(S.c).length > 0;
  const hour = new Date().getHours();

  // greeting
  const head = el('div', { style:'margin-bottom:22px' });
  head.appendChild(el('div', { class:'lbl', style:'margin-bottom:7px',
    text: new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long' }) }));
  head.appendChild(el('h1', { text: hour < 12 ? 'Good morning.' : hour < 18 ? 'Good afternoon.' : 'Good evening.' }));
  w.appendChild(head);

  // hero — one tap into practice
  const hero = el('div', { class:'hero', style:'margin-bottom:16px' });
  const line = !started
    ? 'The first dozen items are diagnostic. After that the engine stops guessing and starts choosing.'
    : due
      ? `${due} item${due === 1 ? '' : 's'} due${hcw ? `, and ${hcw} you were sure about and got wrong` : ''}.`
      : 'Nothing overdue. A session will bring you new material and stretch what you already hold.';
  hero.innerHTML = `<h2>${started ? "Today's session" : 'Start here'}</h2><p>${esc(line)}</p>`;
  const hb = el('div', { class:'heroacts' });
  hb.appendChild(el('button', { class:'btn lg', text:'Start · 12 min', onclick: () => startDrill(12) }));
  hb.appendChild(el('button', { class:'btn alt lg', text:'25 min', onclick: () => startDrill(25) }));
  hb.appendChild(el('button', { class:'btn alt lg', text:'45 min', onclick: () => startDrill(45) }));
  hero.appendChild(hb);
  w.appendChild(hero);

  if (d2i !== null) {
    const phase = d2i <= 14 ? 'Fluency phase — intervals halved, sessions weight retrieval speed and simulation.'
                : d2i <= 45 ? 'Intervals have tightened as the date approaches.'
                : 'Plenty of runway. This is the phase for building depth rather than speed.';
    const c = el('div', { class:'card tight row', style:'margin-bottom:16px;gap:14px' });
    c.innerHTML = `<div class="dnum" style="font-size:28px;color:var(--accent)">${d2i}</div>
      <div><div style="font-weight:700;font-size:14.5px">days to interview</div>
      <div class="src">${esc(phase)}</div></div>`;
    w.appendChild(c);
  }

  // where you are
  if (started) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Where you are' })]));
    const c = el('div', { class:'card' });
    const top = el('div', { class:'row', style:'gap:22px;margin-bottom:20px;align-items:center' });
    top.appendChild(ringEl(rd.overall, 92, 10, band(rd.overall)[3], rd.overall, ''));
    const t = el('div', { style:'flex:1 1 auto' });
    t.innerHTML = `<div style="font-weight:750;font-size:17px;margin-bottom:3px">${band(rd.overall)[2]}</div>
      <div class="src">Readiness weights your weakest domain, because selection filters on your weakest panel — not your strongest.</div>`;
    top.appendChild(t);
    c.appendChild(top);
    ['research','clinical','professional'].forEach(d => c.appendChild(domainRow(d, rd[d])));
    c.appendChild(el('button', { class:'btn sm ghost', style:'margin-top:4px;padding-left:0',
      text:'See the full picture →', onclick: () => go('progress') }));
    w.appendChild(c);
  }

  // what changed
  if (S.wins.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'What changed' })]));
    const c = el('div', { class:'card' });
    S.wins.slice(0, 5).forEach((win, i) => {
      const node = CONCEPT[win.cid];
      const r = el('div', { class:'row', style:'padding:9px 0;align-items:flex-start' + (i ? ';border-top:1px solid var(--line)' : '') });
      r.innerHTML = `<span class="dot ${node ? node.domain : 'research'}" style="margin-top:7px"></span>
        <span style="flex:1 1 auto;font-size:14.5px;line-height:1.45">${esc(win.text)}</span>
        <span class="src" style="flex:none">${relTime(win.ts)}</span>`;
      c.appendChild(r);
    });
    w.appendChild(c);
  }

  // underneath your errors
  const clusters = misconceptionClusters(3);
  if (clusters.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Underneath your errors' })]));
    const c = el('div', { class:'card' });
    c.appendChild(el('p', { class:'src', style:'margin-bottom:14px',
      text:'Separate mistakes that turn out to share a root. Teaching the idea beneath them beats correcting each one.' }));
    clusters.forEach(cl => {
      const b = el('button', { class:'row', style:'width:100%;background:none;border:0;padding:10px 0;text-align:left;font:inherit;cursor:pointer;border-top:1px solid var(--line)',
        onclick: () => showConcept(cl.cid) });
      b.innerHTML = `<span class="dot ${cl.node.domain}"></span>
        <span style="flex:1 1 auto;font-weight:650;font-size:14.5px">${esc(cl.node.label)}</span>
        <span class="pill">${Math.round(cl.n)} errors</span>
        <span class="dnum" style="font-size:14px;color:var(--ink-3)">${cl.m}</span>`;
      c.appendChild(b);
    });
    w.appendChild(c);
  }

  // jump to a surface
  w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Or work on something specific' })]));
  w.appendChild(surfaceGrid(2));
  stage.appendChild(w);
}

const SURFACES = [
  ['bench',  'Bench',  'bench', 'clinical',
   'Timed written papers, marked to the scheme. The 2014 Birmingham paper carries its own official one.',
   () => DATA.written.exercises.length + ' papers · ' + DATA.written.exercises.reduce((a,e)=>a+e.questions.reduce((b,q)=>b+q.rubric.length,0),0) + ' marking points'],
  ['panel',  'Panel',  'panel', 'research',
   'Real interview questions under the clock, with the follow-up they push with afterwards.',
   () => DATA.interview.questions.length + ' verbatim questions'],
  ['studio', 'Studio', 'studio', 'professional',
   'One case, several models. Write yours first, then see what each lens adds and what it misses.',
   () => DATA.formulation.vignettes.length + ' cases · ' + DATA.formulation.vignettes.reduce((a,v)=>a+v.models.length,0) + ' formulations'],
  ['room',   'Room',   'room', 'clinical',
   'Branching conversations, scored on whether you open and reflect — or reach for a solution.',
   () => DATA.roleplay.scenarios.length + ' scenarios'],
];

function surfaceGrid(cols) {
  const g = el('div', { class:'grid g' + (cols || 2) });
  SURFACES.forEach(([id, nm, mk, dom, blurb, count]) => {
    const b = el('button', { class:'tile', onclick: () => go(id) });
    b.innerHTML = `<div class="tmk tint-${dom}" style="color:var(--d-${dom})">${icon(mk)}</div>
      <h3>${nm}</h3><p>${esc(blurb)}</p>
      <div class="tfoot"><span class="pill">${esc(count())}</span></div>`;
    g.appendChild(b);
  });
  return g;
}

/* ---------------------------------------------------------- PRACTICE */
function vPractice(stage) {
  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('h1', { text:'Practice' }));
  w.appendChild(el('p', { class:'muted', style:'margin:9px 0 26px;max-width:58ch',
    text:'Five ways in. Drill trains retrieval and discrimination; the other four rehearse the actual tasks selection puts in front of you.' }));

  const drill = el('button', { class:'tile', style:'margin-bottom:16px', onclick: () => startDrill(12) });
  drill.innerHTML = `<div class="tmk">${icon('drill')}</div><h3>Drill</h3>
    <p>Adaptive interleaved retrieval. Chosen by what is due, what you got wrong while confident, and which concepts sit lowest.</p>
    <div class="tfoot">
      <span class="pill">${dueCount()} due</span>
      <span class="pill">${unseenCount()} unseen</span>
      <span class="pill solid">Start</span>
    </div>`;
  w.appendChild(drill);
  w.appendChild(surfaceGrid(2));
  stage.appendChild(w);
}

/* ---------------------------------------------------------- PROGRESS */
function vProgress(stage) {
  const w = el('div', { class:'wrap wide stg' });
  const rd = readiness(), cal = calibration();
  w.appendChild(el('h1', { text:'Progress' }));
  w.appendChild(el('p', { class:'muted', style:'margin:9px 0 24px;max-width:58ch',
    text:'Depth is earned level by level. Recognising something never counts as mastering it, and a failed transfer item takes depth back.' }));

  const top = el('div', { class:'grid g2', style:'margin-bottom:8px' });

  const rcard = el('div', { class:'card' });
  const rrow = el('div', { class:'row', style:'gap:20px;margin-bottom:18px' });
  rrow.appendChild(ringEl(rd.overall, 96, 11, band(rd.overall)[3], rd.overall, ''));
  const rt = el('div', { style:'flex:1 1 auto' });
  rt.innerHTML = `<div class="lbl">Readiness</div>
    <div style="font-weight:750;font-size:18px;margin:3px 0 4px">${band(rd.overall)[2]}</div>
    <div class="src">0.62 × mean + 0.38 × weakest</div>`;
  rrow.appendChild(rt);
  rcard.appendChild(rrow);
  ['research','clinical','professional'].forEach(d => rcard.appendChild(domainRow(d, rd[d])));
  top.appendChild(rcard);

  const ccard = el('div', { class:'card' });
  ccard.appendChild(el('div', { class:'lbl', style:'margin-bottom:12px', text:'Calibration' }));
  if (cal.score === null) {
    ccard.appendChild(el('p', { class:'src', text:'No data yet. Every item asks how sure you are before you answer; the gap between that and the outcome is what gets scored here.' }));
  } else {
    const c1 = el('div', { class:'statline', style:'margin-bottom:14px' });
    c1.innerHTML = `<span class="dnum v" style="color:${band(cal.score)[3]}">${cal.score}</span><span class="u">/ 100</span>`;
    ccard.appendChild(c1);
    ccard.appendChild(el('p', { class:'src', style:'margin-bottom:16px',
      text:'The goal is calibrated confidence, not maximum confidence. Being sure and wrong costs more than being unsure and right.' }));
    [['Sure and wrong', cal.hcw, 'var(--wrong)', 'Highest priority — the belief felt settled'],
     ['Unsure and right', cal.lcr, 'var(--warning)', 'Knowledge you have but do not trust'],
     ['Rated answers', cal.n, 'var(--ink-3)', '']].forEach(([nm, v, col, sub], i) => {
      const r = el('div', { style:'padding:10px 0' + (i ? ';border-top:1px solid var(--line)' : '') });
      r.innerHTML = `<div class="row"><span style="flex:1 1 auto;font-size:14px;font-weight:650">${nm}</span>
        <span class="dnum" style="font-size:19px;color:${col}">${v}</span></div>
        ${sub ? `<div class="src">${sub}</div>` : ''}`;
      ccard.appendChild(r);
    });
  }
  top.appendChild(ccard);
  w.appendChild(top);

  const qs = el('div', { class:'grid g3', style:'margin-top:14px' });
  [['Due for review', dueCount()], ['Not yet seen', unseenCount()],
   ['Concepts met', Object.keys(S.c).length + ' / ' + DATA.concepts.nodes.length]].forEach(([nm, v]) => {
    const c = el('div', { class:'card tight' });
    c.innerHTML = `<div class="lbl">${nm}</div><div class="dnum" style="font-size:26px;margin-top:5px">${v}</div>`;
    qs.appendChild(c);
  });
  w.appendChild(qs);

  // weakest held
  const weak = weakConcepts(8);
  if (weak.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Weakest held' })]));
    const c = el('div', { class:'card' });
    weak.forEach((x, i) => {
      const b = el('button', { style:'width:100%;background:none;border:0;padding:11px 0;text-align:left;font:inherit;cursor:pointer' + (i ? ';border-top:1px solid var(--line)' : ''),
        onclick: () => showConcept(x.n.id) });
      b.innerHTML = `<div class="row" style="margin-bottom:6px">
          <span class="dot ${x.n.domain}"></span>
          <span style="flex:1 1 auto;font-weight:650;font-size:14.5px">${esc(x.n.label)}</span>
          ${x.rec && x.rec.hcw ? '<span class="pill warn">sure &amp; wrong ×' + x.rec.hcw + '</span>' : ''}
          <span class="dnum" style="font-size:14px;color:var(--ink-3)">${x.m}</span>
        </div><div class="meter thin ${x.n.domain}"><i style="width:${x.m}%"></i></div>`;
      c.appendChild(b);
    });
    w.appendChild(c);
  }

  w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Deeper' })]));
  const links = el('div', { class:'grid g2' });
  [['atlas', 'The Atlas', 'atlas', 'A live map of ' + DATA.concepts.nodes.length + ' concepts. Nodes brighten as you demonstrate depth, and dim hubs with many links are the highest-leverage targets.'],
   ['ledger', 'The Ledger', 'ledger', S.errors.length + ' recorded errors, classified, ordered by what will cost you most.']]
   .forEach(([id, nm, mk, blurb]) => {
    const b = el('button', { class:'tile', onclick: () => go(id) });
    b.innerHTML = `<div class="tmk">${icon(mk)}</div><h3>${nm}</h3><p>${esc(blurb)}</p>`;
    links.appendChild(b);
  });
  w.appendChild(links);
  stage.appendChild(w);
}

/* ============================================================
   DRILL
   ============================================================ */
let SESSION = null;

function startDrill(minutes) {
  const n = Math.max(6, Math.round(minutes * 0.85));
  const items = buildSession(n);
  if (!items.length) { toast('Nothing to drill right now — try the Bench or the Panel'); return; }
  SESSION = { items, idx:0, right:0, started:Date.now(), answers:[], minutes, wasWins: S.wins.length };
  go('drill');
}

function quitDrill() {
  if (SESSION && SESSION.answers.length && SESSION.idx < SESSION.items.length) {
    if (!confirm('Leave this session? Answers already given are saved.')) return;
  }
  SESSION = null; go('today');
}

function vDrill(stage) {
  if (!SESSION) { go('practice'); return; }
  if (SESSION.idx >= SESSION.items.length) return drillDone(stage);

  focusMode(true);
  const item = SESSION.items[SESSION.idx];

  const bar = el('div', { id:'sessbar' });
  bar.innerHTML = `<button class="x" title="Leave">✕</button>
    <div class="track"><i></i></div>
    <span class="lbl" style="flex:none">${SESSION.idx + 1}/${SESSION.items.length}</span>`;
  $('.x', bar).addEventListener('click', quitDrill);
  stage.appendChild(bar);
  requestAnimationFrame(() => { $('.track i', bar).style.width = (SESSION.idx / SESSION.items.length * 100) + '%'; });

  const w = el('div', { class:'wrap' });
  const node = CONCEPT[item.concepts[0]] || {};
  const tags = el('div', { class:'tagrow', style:'margin-bottom:18px' });
  tags.innerHTML = `<span class="pill on"><span class="dot ${node.domain || 'research'}"></span>${esc(node.label || '')}</span>
    <span class="pill">${esc(item.level)}</span>
    ${item.source ? '<span class="pill">from a real paper</span>' : ''}`;
  w.appendChild(tags);

  const host = el('div');
  w.appendChild(host);
  stage.appendChild(w);

  renderItem(host, item, res => {
    SESSION.answers.push(res);
    if (res.correct) SESSION.right++;
    SESSION.idx++;
    if (res.hiConfWrong && SESSION.items.length < 60) {
      SESSION.items.splice(Math.min(SESSION.items.length, SESSION.idx + 4), 0, item);
    }
    go('drill');
  });
}

function drillDone(stage) {
  focusMode(false); Act.hide();
  const secs = (Date.now() - SESSION.started) / 1000;
  const n = SESSION.answers.length;
  const pct = n ? Math.round(SESSION.right / n * 100) : 0;
  if (n && !SESSION.logged) {
    S.log.unshift({ ts: Date.now(), mode:'drill', n, pct, secs });
    if (S.log.length > 200) S.log.pop();
    save(); SESSION.logged = true;
  }
  const newWins = S.wins.slice(0, Math.max(0, S.wins.length - SESSION.wasWins));
  const hcw = SESSION.answers.filter(a => a.hiConfWrong);

  const w = el('div', { class:'wrap narrow stg', style:'text-align:center;padding-top:52px' });
  w.appendChild(el('div', { style:'font-size:56px;line-height:1;margin-bottom:16px',
    text: pct >= 80 ? '🎯' : pct >= 50 ? '💪' : '🧭' }));
  w.appendChild(el('h1', { text: pct >= 80 ? 'Strong session.' : pct >= 50 ? 'Session complete.' : 'Useful session.' }));
  w.appendChild(el('p', { class:'muted', style:'margin:10px auto 26px;max-width:38ch',
    text: pct >= 80 ? 'Hold that. The scheduler will push these further out and bring you harder versions.'
        : pct >= 50 ? 'The errors are the valuable part — they are already scheduled to come back.'
        : 'A low score early is information, not a verdict. The engine now knows where to aim.' }));

  const g = el('div', { class:'grid g3', style:'margin-bottom:22px;text-align:left' });
  [['Answered', n], ['Correct', pct + '%'], ['Time', fmtTime(secs)]].forEach(([l, v]) => {
    const c = el('div', { class:'card tight' });
    c.innerHTML = `<div class="lbl">${l}</div><div class="dnum" style="font-size:26px;margin-top:4px">${v}</div>`;
    g.appendChild(c);
  });
  w.appendChild(g);

  if (newWins.length) {
    const c = el('div', { class:'card tint-accent', style:'text-align:left;margin-bottom:14px;box-shadow:none' });
    c.appendChild(el('div', { class:'lbl', style:'color:var(--accent);margin-bottom:10px',
      text:"What you can now do that you couldn't" }));
    newWins.slice(0, 6).forEach(win => c.appendChild(
      el('p', { style:'margin:0 0 7px;font-size:14.5px;line-height:1.45', text:'· ' + win.text })));
    w.appendChild(c);
  }

  if (hcw.length) {
    const c = el('div', { class:'card', style:'text-align:left;margin-bottom:14px;border-left:4px solid var(--warning)' });
    c.innerHTML = `<div class="lbl" style="color:var(--warning);margin-bottom:7px">Highest priority</div>
      <p style="font-size:14.5px;color:var(--ink-2);margin:0">You were confident and wrong on <b>${hcw.length}</b> item${hcw.length === 1 ? '' : 's'}. That combination matters more than the score: it means the belief felt settled. Those are scheduled to return today.</p>`;
    w.appendChild(c);
  }

  const btns = el('div', { class:'row', style:'justify-content:center;margin-top:24px;flex-wrap:wrap' });
  btns.appendChild(el('button', { class:'btn pri lg', text:'Another session', onclick: () => startDrill(SESSION.minutes) }));
  btns.appendChild(el('button', { class:'btn lg', text:'Done', onclick: () => { SESSION = null; go('today'); } }));
  w.appendChild(btns);
  stage.appendChild(w);
}

/* ---------------------------------------------------------- item renderers */
function renderItem(host, item, done) {
  const t0 = Date.now();
  ({ mcq: renderChoice, multi: renderChoice, contrast: renderContrast,
     ladder: renderLadder }[item.kind] || renderChoice)(host, item, t0, done);
}

/* the confidence control that lives in the action bar */
function confControl(onPick) {
  const wrap = el('div', { class:'confwrap' });
  wrap.appendChild(el('span', { class:'cl', text:'Sure?' }));
  const pips = el('div', { class:'pips' });
  for (let i = 1; i <= 5; i++) {
    pips.appendChild(el('button', { class:'pip', text:i, title: ['Guessing','Doubtful','Even','Fairly sure','Certain'][i-1],
      onclick: e => {
        $$('.pip', pips).forEach(b => b.classList.remove('on'));
        e.currentTarget.classList.add('on'); onPick(i);
      }}));
  }
  wrap.appendChild(pips);
  return wrap;
}

function renderChoice(host, item, t0, done) {
  const multi = item.kind === 'multi';
  let conf = null, picked = new Set(), locked = false;

  if (item.context) host.appendChild(el('div', { class:'qctx', text: item.context }));
  host.appendChild(el('div', { class:'qstem', text: item.stem }));
  if (multi) host.appendChild(el('div', { class:'qhint',
    text:'Select all that apply. In the real paper this scores only if every correct option — and no incorrect one — is selected.' }));

  const box = el('div', { class:'choices' });
  item.options.forEach((o, i) => {
    const b = el('button', { class:'choice', 'data-id':o.id }, [
      el('span', { class:'key', text: String.fromCharCode(65 + i) }),
      el('span', { class:'ctx' }, [el('span', { text: o.text })]),
    ]);
    b.addEventListener('click', () => {
      if (locked) return;
      if (multi) { picked.has(o.id) ? picked.delete(o.id) : picked.add(o.id); b.classList.toggle('sel'); }
      else {
        picked = new Set([o.id]);
        $$('.choice', box).forEach(x => x.classList.toggle('sel', x === b));
      }
      sync();
    });
    box.appendChild(b);
  });
  host.appendChild(box);

  const checkBtn = el('button', { class:'btn pri lg', text:'Check', disabled:'', onclick: reveal });
  Act.row([confControl(v => { conf = v; sync(); })], [checkBtn]);
  function sync() { checkBtn.disabled = !(conf !== null && picked.size); }

  function reveal() {
    if (locked || conf === null || !picked.size) return;
    locked = true;
    const correctIds = item.options.filter(o => o.correct).map(o => o.id);
    const correct = correctIds.length === picked.size && correctIds.every(id => picked.has(id));
    const secs = (Date.now() - t0) / 1000;

    $$('.choice', box).forEach(b => {
      const o = item.options.find(x => x.id === b.dataset.id);
      b.classList.add('locked'); b.classList.remove('sel');
      if (o.correct) b.classList.add('ok');
      else if (picked.has(o.id)) b.classList.add('bad');
      else b.classList.add('faded');
      if (o.why && (o.correct || picked.has(o.id))) $('.ctx', b).appendChild(el('span', { class:'why', text: o.why }));
    });

    const rec = recordAnswer(item, correct, conf, secs);
    showVerdict(item, correct, rec, secs, () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id }));
  }
}

function renderContrast(host, item, t0, done) {
  let conf = null, locked = false;
  const answers = {};
  host.appendChild(el('div', { class:'qstem', text: item.stem }));

  const cols = el('div', { class:'sortcols' });
  cols.appendChild(el('div', { class:'h', text: item.left }));
  cols.appendChild(el('div', { class:'h', text: item.right }));
  host.appendChild(cols);

  const list = el('div', { class:'choices' });
  const probes = shuffle(item.probes);
  probes.forEach((p, i) => {
    const row = el('div', { class:'sortrow' });
    const L = el('button', { class:'sidebtn', text:'◀' });
    const R = el('button', { class:'sidebtn', text:'▶' });
    row.append(L, el('span', { class:'t', text: p.text }), R);
    [[L,'L'],[R,'R']].forEach(([btn, side]) => btn.addEventListener('click', () => {
      if (locked) return;
      answers[i] = side;
      L.classList.toggle('on', side === 'L'); R.classList.toggle('on', side === 'R');
      row.classList.toggle('pickL', side === 'L'); row.classList.toggle('pickR', side === 'R');
      sync();
    }));
    list.appendChild(row);
    row._probe = p;
  });
  host.appendChild(list);

  const checkBtn = el('button', { class:'btn pri lg', text:'Check', disabled:'', onclick: reveal });
  Act.row([confControl(v => { conf = v; sync(); })], [checkBtn]);
  function sync() { checkBtn.disabled = !(conf !== null && Object.keys(answers).length === probes.length); }

  function reveal() {
    if (locked) return; locked = true;
    let right = 0;
    $$('.sortrow', list).forEach((row, i) => {
      const ok = answers[i] === row._probe.side;
      if (ok) { right++; row.classList.add('ok'); }
      else {
        row.classList.add('bad');
        const which = row._probe.side === 'L' ? item.left : item.right;
        row.appendChild(el('span', { class:'src', style:'flex-basis:100%;padding-left:52px', text:'→ ' + which }));
      }
    });
    const correct = right === probes.length;
    const secs = (Date.now() - t0) / 1000;
    const sc = el('div', { class:'card tight', style:'margin-top:14px' });
    sc.innerHTML = `<div class="lbl">Sorted correctly</div>
      <div class="dnum" style="font-size:26px;margin-top:3px">${right} <span style="font-size:15px;color:var(--ink-3)">/ ${probes.length}</span></div>`;
    host.appendChild(sc);
    const rec = recordAnswer(item, correct, conf, secs);
    showVerdict(item, correct, rec, secs, () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id }));
  }
}

function renderLadder(host, item, t0, done) {
  let conf = null, rung = 0, wrong = 0, live = false;
  host.appendChild(el('div', { class:'qctx', text: item.stem }));
  const hint = el('div', { class:'qhint', style:'margin-top:0',
    text:'Walk the chain. Each step follows from the one before it — rate your confidence to begin.' });
  host.appendChild(hint);
  const track = el('div');
  host.appendChild(track);

  // step one is on screen from the start; confidence unlocks it
  next();
  Act.row([confControl(v => {
    conf = v; live = true;
    hint.textContent = 'Walk the chain. Each step follows from the one before it.';
    $$('.choice', track).forEach(c => c.classList.remove('faded'));
    Act.hide();
  })], []);

  function next() {
    if (rung >= item.rungs.length) return finish();
    const r = item.rungs[rung];
    const blk = el('div', { class:'card', style:'margin-bottom:12px' });
    blk.appendChild(el('div', { class:'lbl', text:'Step ' + (rung + 1) + ' of ' + item.rungs.length }));
    blk.appendChild(el('div', { style:'font-size:18px;font-weight:700;letter-spacing:-.015em;margin:7px 0 14px;line-height:1.35', text: r.q }));
    const opts = el('div', { class:'choices' });
    r.options.forEach((o, i) => {
      const b = el('button', { class:'choice' + (live ? '' : ' faded'), style:'box-shadow:none;border-color:var(--line)' }, [
        el('span', { class:'key', text: String.fromCharCode(65 + i) }),
        el('span', { class:'ctx' }, [el('span', { text: o.text })]),
      ]);
      b.addEventListener('click', () => {
        if (!live || b.classList.contains('locked')) {
          if (!live) toast('Rate your confidence first');
          return;
        }
        const all = $$('.choice', opts);
        all.forEach((x, xi) => {
          x.classList.add('locked');
          const oo = r.options[xi];
          if (oo.correct) x.classList.add('ok'); else if (x === b) x.classList.add('bad'); else x.classList.add('faded');
          if (oo.why && (oo.correct || x === b)) $('.ctx', x).appendChild(el('span', { class:'why', text: oo.why }));
        });
        if (!o.correct) wrong++;
        rung++;
        setTimeout(() => { next(); scrollEnd(); }, 560);
      });
      opts.appendChild(b);
    });
    blk.appendChild(opts);
    track.appendChild(blk);
    if (rung > 0) scrollEnd();
  }

  function finish() {
    const correct = wrong === 0;
    const secs = (Date.now() - t0) / 1000;
    const a = el('div', { class:'callout', style:'margin:14px 0' });
    a.innerHTML = `<div class="lbl">The analysis</div><p>${esc(item.answer)}</p>`;
    track.appendChild(a);
    const rec = recordAnswer(item, correct, conf, secs);
    showVerdict(item, correct, rec, secs, () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id }));
  }
}

/* the action bar becomes the teaching surface */
function showVerdict(item, correct, rec, secs, onNext) {
  const body = el('div');
  const h = el('div', { class:'verdict-h ' + (correct ? 'good' : 'bad') });
  h.innerHTML = `<span class="badge">${correct ? '✓' : '✕'}</span>
    <span class="t">${correct ? 'Correct' : 'Not quite'}</span>
    <span class="meta">${fmtTime(secs)}${item.time ? ' · target ' + fmtTime(item.time) : ''}</span>`;
  body.appendChild(h);

  if (rec.hiConfWrong) {
    body.appendChild(el('p', { style:'color:var(--warning);font-weight:700;font-size:14.5px;margin-bottom:10px',
      text:'You were confident. That makes this the most valuable error in the session — it comes back before you leave.' }));
  }
  body.appendChild(el('div', { class:'teachtext', text: item.teach }));

  if (item.precision) {
    const p = el('div', { class:'precision' });
    p.innerHTML = `<div class="lbl">Say it exactly like this</div><p>${esc(item.precision)}</p>`;
    body.appendChild(p);
  }

  if (!correct) {
    const nots = [];
    item.concepts.forEach(cid => {
      const n = CONCEPT[cid];
      if (n && n.notThis && n.notThis.length) nots.push([n.label, n.notThis]);
    });
    if (nots.length) {
      const d = el('div', { class:'nots' });
      d.appendChild(el('div', { class:'lbl', style:'margin-bottom:4px', text: nots[0][0] + ' is NOT' }));
      nots[0][1].forEach(x => d.appendChild(el('div', { class:'n', text: x })));
      body.appendChild(d);
    }

    const box = el('div', { style:'margin-top:16px' });
    box.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text:'What actually went wrong?' }));
    const row = el('div', { class:'tagrow' });
    ERROR_TYPES.forEach(([id, nm, hint]) => {
      const t = el('button', { class:'pill', title: hint, style:'cursor:pointer;border:0;font:inherit;font-weight:650', text: nm });
      t.addEventListener('click', () => {
        $$('.pill', row).forEach(x => x.classList.remove('on'));
        t.classList.add('on');
        const e = S.errors.find(x => x.id === item.id && !x.type);
        if (e) { e.type = id; save(); }
      });
      row.appendChild(t);
    });
    box.appendChild(row);
    body.appendChild(box);
  }

  if (item.source) body.appendChild(el('p', { class:'src', style:'margin-top:14px', text:'Source: ' + item.source }));

  const btn = el('button', { class: 'btn lg ' + (correct ? 'ok' : 'no'), text:'Continue', onclick: onNext });
  Act.result(correct ? 'good' : 'bad', body, btn);
  if (correct) tick(880, .08, .05); else tick(300, .12, .045);

  const h2 = e => {
    if (e.key === 'Enter' && !e.target.matches('textarea,input')) {
      e.preventDefault(); document.removeEventListener('keydown', h2); onNext();
    }
  };
  document.addEventListener('keydown', h2);
  scrollEnd();
}

function scrollEnd() {
  requestAnimationFrame(() => {
    const st = $('#stage');
    st.scrollTo({ top: st.scrollHeight, behavior: 'smooth' });
  });
}
