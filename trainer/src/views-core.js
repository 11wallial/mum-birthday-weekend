/* ============================================================
   VIEWS — shell, router, Today, Drill
   ============================================================ */

const MODES = [
  ['today',  'Today',  'D', 'Your brief for this session'],
  ['drill',  'Drill',  '1', 'Adaptive interleaved retrieval'],
  ['bench',  'Bench',  '2', 'Timed written papers, marked to the scheme'],
  ['panel',  'Panel',  '3', 'Interview questions under the clock'],
  ['studio', 'Studio', '4', 'One case, many models'],
  ['room',   'Room',   '5', 'Role-play, scored on process'],
  ['atlas',  'Atlas',  '6', 'The map of what you know'],
  ['ledger', 'Ledger', '7', 'Your errors, and what they have in common'],
];
let VIEW = 'today', TIMERS = [];

function clearTimers() { TIMERS.forEach(t => clearInterval(t)); TIMERS = []; }
function focusMode(on) { document.body.classList.toggle('focus', !!on); }

function go(view, arg) {
  clearTimers(); focusMode(false);
  VIEW = view; S.lastMode = view; save();
  $$('#tabs .tab').forEach(t => t.setAttribute('aria-selected', String(t.dataset.v === view)));
  document.body.classList.remove('rail');
  const stage = $('#stage');
  stage.scrollTop = 0;
  stage.innerHTML = '';
  ({ today:vToday, drill:vDrill, bench:vBench, panel:vPanel, studio:vStudio,
     room:vRoom, atlas:vAtlas, ledger:vLedger }[view] || vToday)(stage, arg);
  renderRail();
}

/* ---------------------------------------------------------- rail */
function renderRail() {
  const rail = $('#rail'); rail.innerHTML = '';
  const now = Date.now(), rd = readiness(now), cal = calibration();

  // readiness instrument
  const sec1 = el('div', { class:'railsec' });
  sec1.appendChild(el('div', { class:'lbl', html:'<span>Readiness</span>' }));
  const ringWrap = el('div', { class:'ring', style:'margin:2px auto 14px' });
  const RC = 2 * Math.PI * 42;
  ringWrap.innerHTML =
    `<svg width="112" height="112" viewBox="0 0 112 112">
       <circle class="trk" cx="56" cy="56" r="42" stroke-width="7"></circle>
       <circle class="val" cx="56" cy="56" r="42" stroke-width="7"
               stroke-dasharray="${RC}" stroke-dashoffset="${RC}"></circle>
     </svg>
     <div class="mid">
       <div class="dnum" style="font-size:30px;line-height:1">${rd.overall}</div>
       <div class="lbl" style="margin-top:2px">${band(rd.overall)[2].split(' ')[0]}</div>
     </div>`;
  sec1.appendChild(ringWrap);
  requestAnimationFrame(() => {
    const v = $('.val', ringWrap);
    if (v) { v.style.strokeDashoffset = RC * (1 - rd.overall / 100); v.style.stroke = band(rd.overall)[3]; }
  });
  ['research','clinical','professional'].forEach(d => {
    const pct = rd[d];
    const row = el('div', { class:'rrow', onclick: () => go('atlas', d) }, [
      el('span', { class:'dot ' + d }),
      el('span', { class:'nm', text: d[0].toUpperCase() + d.slice(1) }),
      el('span', { class:'vv dnum', text: pct }),
    ]);
    sec1.appendChild(row);
    const m = el('div', { class:'meter ' + d, style:'margin:0 8px 8px' });
    m.innerHTML = '<i></i>';
    sec1.appendChild(m);
    requestAnimationFrame(() => { $('i', m).style.width = pct + '%'; });
  });
  rail.appendChild(sec1);

  // queue
  const due = dueCount(), unseen = unseenCount();
  const sec2 = el('div', { class:'railsec' });
  sec2.appendChild(el('div', { class:'lbl', html:'<span>Queue</span>' }));
  [['Due for review', due, due > 0], ['Not yet seen', unseen, false],
   ['Confident errors', S.errors.filter(e => e.conf >= 4).length, S.errors.some(e => e.conf >= 4)]]
    .forEach(([nm, v, hot]) => sec2.appendChild(
      el('div', { class:'rrow' + (hot ? ' hot' : '') }, [
        el('span', { class:'nm', text:nm }), el('span', { class:'vv dnum', text:v })])));
  rail.appendChild(sec2);

  // weakest — the gap ledger, live
  const weak = weakConcepts(7);
  if (weak.length) {
    const sec3 = el('div', { class:'railsec' });
    sec3.appendChild(el('div', { class:'lbl', html:'<span>Weakest held</span><span>mastery</span>' }));
    weak.forEach(w => {
      const row = el('div', { class:'rrow', title: w.n.precision, onclick: () => showConcept(w.n.id) }, [
        el('span', { class:'dot ' + w.n.domain }),
        el('span', { class:'nm', text: w.n.label }),
        el('span', { class:'vv dnum', text: w.m }),
      ]);
      sec3.appendChild(row);
    });
    rail.appendChild(sec3);
  }

  // calibration
  const sec4 = el('div', { class:'railsec' });
  sec4.appendChild(el('div', { class:'lbl', html:'<span>Calibration</span>' }));
  if (cal.score === null) {
    sec4.appendChild(el('div', { class:'rrow' }, [el('span', { class:'nm', text:'No data yet' })]));
  } else {
    sec4.appendChild(el('div', { class:'rrow hot' }, [
      el('span', { class:'nm', text:'Calibration score' }), el('span', { class:'vv dnum', text: cal.score })]));
    sec4.appendChild(el('div', { class:'rrow' }, [
      el('span', { class:'nm', text:'Confident & wrong' }), el('span', { class:'vv dnum', text: cal.hcw })]));
    sec4.appendChild(el('div', { class:'rrow' }, [
      el('span', { class:'nm', text:'Unsure & right' }), el('span', { class:'vv dnum', text: cal.lcr })]));
  }
  rail.appendChild(sec4);
}

/* ---------------------------------------------------------- TODAY */
function vToday(stage) {
  const w = el('div', { class:'wrap stg' });
  const rd = readiness(), d2i = daysToInterview(), due = dueCount();
  const hour = new Date().getHours();
  const greet = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  const head = el('div', { style:'margin-bottom:26px' });
  head.appendChild(el('h1', { text: greet + '.' }));
  const sub = el('p', { style:'color:var(--ink-2);font-size:15px;margin-top:7px;max-width:62ch' });
  sub.innerHTML = todayBrief(rd, d2i, due);
  head.appendChild(sub);
  w.appendChild(head);

  // the session launcher — three lengths, one adaptive composer
  const launch = el('div', { class:'panel', style:'padding:20px 22px;margin-bottom:26px' });
  launch.appendChild(el('div', { class:'lbl', style:'margin-bottom:12px', text:'Start a session' }));
  const row = el('div', { class:'grid g3' });
  [[12,'Short','~10 items'], [25,'Standard','~22 items'], [45,'Long','~40 items']].forEach(([mins, nm, sz]) => {
    const b = el('button', { class:'mode', onclick: () => startDrill(Math.round(mins * 0.9)) });
    b.innerHTML = `<h3>${nm}</h3><p>${mins} minutes · ${sz}</p>`;
    row.appendChild(b);
  });
  launch.appendChild(row);
  const hint = el('div', { style:'margin-top:14px;font-size:12.5px;color:var(--ink-3);line-height:1.5' });
  hint.textContent = 'Items are chosen by what is due, what you got wrong while confident, and which concepts sit lowest — then interleaved so you have to work out what kind of problem you are looking at.';
  launch.appendChild(hint);
  w.appendChild(launch);

  // modes
  w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Practice surfaces' })]));
  const grid = el('div', { class:'grid g2' });
  const counts = {
    bench: DATA.written.exercises.length + ' papers · ' + DATA.written.exercises.reduce((a,e)=>a+e.questions.length,0) + ' questions',
    panel: DATA.interview.questions.length + ' real questions · ' + DATA.interview.themes.length + ' themes',
    studio: DATA.formulation.vignettes.length + ' cases · ' + DATA.formulation.vignettes.reduce((a,v)=>a+v.models.length,0) + ' model formulations',
    room: DATA.roleplay.scenarios.length + ' scenarios',
    atlas: DATA.concepts.nodes.length + ' concepts',
    ledger: S.errors.length + ' recorded errors',
  };
  const blurbs = {
    bench: 'Timed papers from Birmingham, Cardiff, South Wales and Surrey. The 2014 Birmingham paper is marked against its own official scheme.',
    panel: 'Every question in the corpus, tagged by course and panel, with what the interviewers are listening for.',
    studio: 'The same case through CBT, systemic, ACT, CFT, psychodynamic and PTMF — and what each lens misses.',
    room: 'Branching conversations. Scored on whether you open, reflect and validate, or reach for a solution.',
    atlas: 'A live map of the concept graph. Nodes brighten as you demonstrate depth, not as you tick items off.',
    ledger: 'Your errors, classified, with the misconceptions several of them turn out to share.',
  };
  MODES.slice(2).forEach(([id, nm, key]) => {
    const b = el('button', { class:'mode', onclick: () => go(id) });
    b.innerHTML = `<h3>${nm}</h3><p>${blurbs[id]}</p>
      <div class="mt"><span class="tag">${counts[id]}</span></div>`;
    grid.appendChild(b);
  });
  w.appendChild(grid);

  // what changed — competence narrative, not XP
  if (S.wins.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'What changed' })]));
    const p = el('div', { class:'panel', style:'padding:6px 4px' });
    S.wins.slice(0, 6).forEach(win => {
      const node = CONCEPT[win.cid];
      p.appendChild(el('div', { class:'rrow', style:'padding:10px 14px' }, [
        el('span', { class:'dot ' + (node ? node.domain : 'research') }),
        el('span', { class:'nm', style:'color:var(--ink);white-space:normal', text: win.text }),
        el('span', { class:'vv', text: relTime(win.ts) }),
      ]));
    });
    w.appendChild(p);
  }

  // misconception clusters
  const clusters = misconceptionClusters(4);
  if (clusters.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Underneath your errors' })]));
    const p = el('div', { class:'panel pad' });
    p.appendChild(el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:14px',
      text:'Several separate errors point at the same underlying idea. Teaching the node beneath them is worth more than correcting each one.' }));
    clusters.forEach(c => {
      const b = el('button', { class:'rrow', style:'width:100%;background:none;border:0;text-align:left;font:inherit',
                               onclick: () => showConcept(c.cid) }, [
        el('span', { class:'dot ' + c.node.domain }),
        el('span', { class:'nm', style:'color:var(--ink)', text: c.node.label }),
        el('span', { class:'vv', text: Math.round(c.n) + ' errors · ' + c.m + '%' }),
      ]);
      p.appendChild(b);
    });
    w.appendChild(p);
  }
  stage.appendChild(w);
}

function todayBrief(rd, d2i, due) {
  const bits = [];
  const weakest = ['research','clinical','professional'].sort((a,b) => rd[a]-rd[b])[0];
  const started = Object.keys(S.c).length > 0;
  if (!started) {
    return 'Nothing is known about you yet. Start with a short session — the first dozen items are diagnostic, and the engine will stop guessing after that. Everything here is built from real past papers, and the Birmingham 2014 paper carries its own official marking scheme.';
  }
  if (due) bits.push(`<b>${due}</b> item${due===1?'':'s'} ${due===1?'is':'are'} due for review`);
  const hcw = S.errors.filter(e => e.conf >= 4).length;
  if (hcw) bits.push(`<b>${hcw}</b> you got wrong while confident — those come back first`);
  bits.push(`your weakest domain is <b>${weakest}</b> at ${rd[weakest]}`);
  let s = bits.join('; ') + '.';
  if (d2i !== null) {
    if (d2i <= 0) s += ' Your interview date has passed — update it in settings if there is another.';
    else if (d2i <= 14) s += ` <b>${d2i} days</b> to interview: review intervals have halved, and sessions now weight fluency and simulation over new material.`;
    else if (d2i <= 45) s += ` ${d2i} days to interview — intervals have tightened.`;
    else s += ` ${d2i} days to interview.`;
  }
  return s;
}

/* ---------------------------------------------------------- DRILL */
let SESSION = null;

function startDrill(minutes) {
  const n = Math.max(6, Math.round(minutes * 0.85));
  const items = buildSession(n);
  if (!items.length) { toast('Nothing due — try Bench or Panel'); return; }
  SESSION = { items, idx:0, right:0, started:Date.now(), answers:[], minutes };
  go('drill');
}

function vDrill(stage) {
  if (!SESSION || SESSION.idx >= SESSION.items.length) {
    if (SESSION && SESSION.idx >= SESSION.items.length && SESSION.items.length) return drillSummary(stage);
    return drillIdle(stage);
  }
  focusMode(true);
  const item = SESSION.items[SESSION.idx];
  const w = el('div', { class:'wrap' });

  // progress
  const prog = el('div', { style:'margin-bottom:22px' });
  const bar = el('div', { class:'timerbar', style:'margin-bottom:10px' });
  bar.innerHTML = `<i style="width:${(SESSION.idx / SESSION.items.length) * 100}%;transition:width .5s var(--ease)"></i>`;
  prog.appendChild(bar);
  const meta = el('div', { style:'display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap' });
  const dom = (CONCEPT[item.concepts[0]] || {}).domain || 'research';
  meta.innerHTML = `<div class="tagrow">
      <span class="tag on"><span class="dot ${dom}"></span>${esc((CONCEPT[item.concepts[0]]||{}).label||'')}</span>
      <span class="tag">${esc(item.level)}</span>
      ${item.source ? `<span class="tag">real paper</span>` : ''}
    </div>
    <div class="lbl">${SESSION.idx + 1} / ${SESSION.items.length}</div>`;
  prog.appendChild(meta);
  w.appendChild(prog);

  const host = el('div');
  w.appendChild(host);
  stage.appendChild(w);
  renderItem(host, item, res => {
    SESSION.answers.push(res);
    if (res.correct) SESSION.right++;
    SESSION.idx++;
    // a confident error is re-queued for later in this same session
    if (res.hiConfWrong && SESSION.items.length < 60) {
      SESSION.items.splice(Math.min(SESSION.items.length, SESSION.idx + 4), 0, item);
    }
    go('drill');
  });
}

function drillIdle(stage) {
  const w = el('div', { class:'wrap' });
  w.appendChild(el('div', { class:'empty' }, [
    el('h3', { text:'No session running' }),
    el('p', { text:'Start one from Today, or jump straight in.' }),
    el('div', { style:'margin-top:18px;display:flex;gap:10px;justify-content:center;flex-wrap:wrap' }, [
      el('button', { class:'btn pri', text:'Short session', onclick: () => startDrill(12) }),
      el('button', { class:'btn', text:'Standard', onclick: () => startDrill(25) }),
    ]),
  ]));
  stage.appendChild(w);
}

function drillSummary(stage) {
  const secs = (Date.now() - SESSION.started) / 1000;
  const pct = Math.round(SESSION.right / SESSION.answers.length * 100) || 0;
  S.log.unshift({ ts: Date.now(), mode:'drill', n: SESSION.answers.length, pct, secs });
  if (S.log.length > 200) S.log.pop();
  save();

  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('h1', { text:'Session complete' }));
  const stats = el('div', { class:'grid g3', style:'margin:22px 0' });
  [['Answered', SESSION.answers.length, ''], ['Correct', pct + '%', ''],
   ['Time', fmtTime(secs), '']].forEach(([l, v]) => {
    const c = el('div', { class:'panel pad' });
    c.innerHTML = `<div class="lbl">${l}</div><div class="dnum" style="font-size:32px;margin-top:6px">${v}</div>`;
    stats.appendChild(c);
  });
  w.appendChild(stats);

  const hcw = SESSION.answers.filter(a => a.hiConfWrong);
  if (hcw.length) {
    const p = el('div', { class:'panel pad', style:'margin-bottom:16px;border-color:color-mix(in srgb,var(--warning) 34%,transparent)' });
    p.innerHTML = `<div class="lbl" style="color:var(--warning)">Highest priority</div>
      <p style="margin-top:8px;font-size:13.5px;color:var(--ink-2)">You were confident and wrong on <b>${hcw.length}</b> item${hcw.length===1?'':'s'}. That combination matters more than any other result here: it means the belief felt settled. Those items are already scheduled to return today.</p>`;
    w.appendChild(p);
  }

  const newWins = S.wins.filter(x => x.ts >= SESSION.started);
  if (newWins.length) {
    const p = el('div', { class:'panel pad', style:'margin-bottom:16px' });
    p.innerHTML = `<div class="lbl">What you can now do that you couldn't</div>`;
    newWins.slice(0, 6).forEach(win => p.appendChild(el('p', {
      style:'margin:10px 0 0;font-size:13.5px', html: '· ' + esc(win.text) })));
    w.appendChild(p);
  }

  w.appendChild(el('div', { style:'display:flex;gap:10px;margin-top:20px;flex-wrap:wrap' }, [
    el('button', { class:'btn pri', text:'Another session', onclick: () => startDrill(SESSION.minutes) }),
    el('button', { class:'btn', text:'Back to Today', onclick: () => { SESSION = null; go('today'); } }),
  ]));
  stage.appendChild(w);
  SESSION = { ...SESSION, idx: -1 };
}

/* ---------------------------------------------------------- item renderers */
function renderItem(host, item, done) {
  const t0 = Date.now();
  ({ mcq: renderChoice, multi: renderChoice, contrast: renderContrast,
     ladder: renderLadder }[item.kind] || renderChoice)(host, item, t0, done);
}

function confRow(onPick) {
  const wrap = el('div', { style:'margin-bottom:18px' });
  wrap.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px',
    text:'How confident are you? (1 = guessing, 5 = certain)' }));
  const row = el('div', { class:'conf' });
  for (let i = 1; i <= 5; i++) {
    row.appendChild(el('button', { class:'cb', text:i, 'data-c':i, onclick: e => {
      $$('.cb', row).forEach(b => b.classList.remove('on'));
      e.currentTarget.classList.add('on'); onPick(i);
    }}));
  }
  wrap.appendChild(row);
  return wrap;
}

function renderChoice(host, item, t0, done) {
  const multi = item.kind === 'multi';
  let conf = null, picked = new Set(), locked = false;

  if (item.context) host.appendChild(el('div', { class:'ctx', text: item.context }));
  host.appendChild(el('div', { class:'stem', text: item.stem }));
  if (multi) host.appendChild(el('p', { class:'lbl', style:'margin:-10px 0 14px',
    text:'Select all that apply — in the real paper this scores only if every correct option and no incorrect one is selected' }));

  const cRow = confRow(v => { conf = v; sync(); });
  host.appendChild(cRow);

  const opts = el('div', { class:'opts' });
  item.options.forEach((o, i) => {
    const b = el('button', { class:'opt', 'data-id':o.id }, [
      el('span', { class:'key', text: String.fromCharCode(65 + i) }),
      el('span', {}, [el('span', { text: o.text })]),
    ]);
    b.addEventListener('click', () => {
      if (locked) return;
      if (conf === null) { toast('Rate your confidence first'); return; }
      if (multi) { picked.has(o.id) ? picked.delete(o.id) : picked.add(o.id); b.classList.toggle('sel'); sync(); }
      else { picked = new Set([o.id]); reveal(); }
    });
    opts.appendChild(b);
  });
  host.appendChild(opts);

  const submit = el('button', { class:'btn pri lg', style:'margin-top:16px;display:none', text:'Submit', onclick: reveal });
  if (multi) { submit.style.display = 'inline-flex'; host.appendChild(submit); }
  function sync() { submit.disabled = conf === null || !picked.size; }
  sync();

  function reveal() {
    if (locked) return;
    if (conf === null) { toast('Rate your confidence first'); return; }
    locked = true; submit.style.display = 'none';
    const correctIds = item.options.filter(o => o.correct).map(o => o.id);
    const correct = correctIds.length === picked.size && correctIds.every(id => picked.has(id));
    const secs = (Date.now() - t0) / 1000;

    $$('.opt', opts).forEach(b => {
      const o = item.options.find(x => x.id === b.dataset.id);
      b.classList.add('locked'); b.classList.remove('sel');
      if (o.correct) b.classList.add('ok');
      else if (picked.has(o.id)) b.classList.add('bad');
      if (o.why) $('span:last-child', b).appendChild(el('span', { class:'why', text: o.why }));
    });

    const rec = recordAnswer(item, correct, conf, secs);
    host.appendChild(feedbackBlock(item, correct, rec, secs, () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id })));
    scrollToEnd(host);
  }
}

function renderContrast(host, item, t0, done) {
  let conf = null, locked = false;
  const answers = {};
  host.appendChild(el('div', { class:'stem', text: item.stem }));
  host.appendChild(confRow(v => conf = v));

  const head = el('div', { class:'grid g2', style:'margin-bottom:10px' });
  head.appendChild(el('div', { class:'lbl', style:'text-align:center', text: item.left }));
  head.appendChild(el('div', { class:'lbl', style:'text-align:center', text: item.right }));
  host.appendChild(head);

  const list = el('div', { class:'opts' });
  const probes = shuffle(item.probes);
  probes.forEach((p, i) => {
    const row = el('div', { class:'opt', style:'align-items:center;gap:10px' });
    const L = el('button', { class:'cb', text:'‹', style:'flex:none;width:38px' });
    const R = el('button', { class:'cb', text:'›', style:'flex:none;width:38px' });
    const tx = el('span', { style:'flex:1 1 auto;font-size:13.5px;line-height:1.45', text: p.text });
    [[L,'L'],[R,'R']].forEach(([btn, side]) => btn.addEventListener('click', () => {
      if (locked) return;
      answers[i] = side; L.classList.toggle('on', side === 'L'); R.classList.toggle('on', side === 'R');
      if (Object.keys(answers).length === probes.length) submit.disabled = conf === null ? true : false;
    }));
    row.append(L, tx, R);
    list.appendChild(row);
    row._probe = p; row._L = L; row._R = R;
  });
  host.appendChild(list);

  const submit = el('button', { class:'btn pri lg', style:'margin-top:16px', text:'Check', disabled:'', onclick: reveal });
  host.appendChild(submit);
  const iv = setInterval(() => { submit.disabled = !(conf !== null && Object.keys(answers).length === probes.length); }, 250);
  TIMERS.push(iv);

  function reveal() {
    if (locked) return; locked = true; clearInterval(iv); submit.style.display = 'none';
    let right = 0;
    $$('.opt', list).forEach((row, i) => {
      const ok = answers[i] === row._probe.side;
      if (ok) { right++; row.classList.add('ok'); }
      else {
        row.classList.add('bad');
        const which = row._probe.side === 'L' ? item.left : item.right;
        row.appendChild(el('span', { class:'why', style:'flex-basis:100%;margin-left:48px', text:'→ ' + which }));
      }
    });
    const correct = right === probes.length;
    const secs = (Date.now() - t0) / 1000;
    host.insertBefore(el('div', { class:'panel pad', style:'margin:14px 0' , html:
      `<div class="lbl">Result</div><div class="dnum" style="font-size:26px;margin-top:4px">${right} / ${probes.length}</div>`}), submit);
    const rec = recordAnswer(item, correct, conf, secs);
    host.appendChild(feedbackBlock(item, correct, rec, secs, () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id })));
    scrollToEnd(host);
  }
}

function renderLadder(host, item, t0, done) {
  let conf = null, rung = 0, wrong = 0;
  host.appendChild(el('div', { class:'ctx', text: item.stem }));
  host.appendChild(el('p', { class:'lbl', style:'margin-bottom:14px',
    text:'Walk the chain. Each step follows from the last.' }));
  host.appendChild(confRow(v => { conf = v; next(); }));
  const track = el('div');
  host.appendChild(track);

  function next() {
    if (conf === null) return;
    if (rung >= item.rungs.length) return finish();
    const r = item.rungs[rung];
    const blk = el('div', { class:'panel pad', style:'margin-bottom:10px' });
    blk.appendChild(el('div', { class:'lbl', text:'Step ' + (rung + 1) + ' of ' + item.rungs.length }));
    blk.appendChild(el('div', { style:'font-size:15.5px;font-weight:500;margin:6px 0 12px', text: r.q }));
    const opts = el('div', { class:'opts' });
    r.options.forEach((o, i) => {
      const b = el('button', { class:'opt' }, [
        el('span', { class:'key', text: String.fromCharCode(65 + i) }),
        el('span', {}, [el('span', { text: o.text })]),
      ]);
      b.addEventListener('click', () => {
        if (b.classList.contains('locked')) return;
        $$('.opt', opts).forEach(x => {
          x.classList.add('locked');
          const oo = r.options[$$('.opt', opts).indexOf(x)];
          if (oo.correct) x.classList.add('ok'); else if (x === b) x.classList.add('bad');
          if (oo.why) $('span:last-child', x).appendChild(el('span', { class:'why', text: oo.why }));
        });
        if (!o.correct) wrong++;
        rung++;
        setTimeout(() => { next(); scrollToEnd(track); }, 480);
      });
      opts.appendChild(b);
    });
    blk.appendChild(opts);
    track.appendChild(blk);
  }

  function finish() {
    const correct = wrong === 0;
    const secs = (Date.now() - t0) / 1000;
    const a = el('div', { class:'panel pad', style:'margin:14px 0;border-color:color-mix(in srgb,var(--accent) 40%,transparent)' });
    a.innerHTML = `<div class="lbl" style="color:var(--accent)">The analysis</div>
      <p style="margin-top:7px;font-size:14.5px">${esc(item.answer)}</p>`;
    track.appendChild(a);
    const rec = recordAnswer(item, correct, conf, secs);
    host.appendChild(feedbackBlock(item, correct, rec, secs,
      () => done({ correct, conf, secs, hiConfWrong: rec.hiConfWrong, id:item.id })));
    scrollToEnd(host);
  }
}

/* the teaching block shown after every item */
function feedbackBlock(item, correct, rec, secs, onNext) {
  const wrap = el('div', { style:'margin-top:18px' });
  const v = el('div', { class:'verdict ' + (correct ? 'right' : 'wrong') });
  const head = el('div', { class:'vh' });
  head.innerHTML = `<span class="ic">${correct ? '✓' : '✕'}</span>
    <span>${correct ? 'Correct' : 'Not right'}</span>
    <span style="margin-left:auto;font-weight:400;font-size:12px;color:var(--ink-3)">${fmtTime(secs)}${item.time ? ' · target ' + fmtTime(item.time) : ''}</span>`;
  v.appendChild(head);
  if (rec.hiConfWrong) {
    v.appendChild(el('p', { style:'color:var(--warning);font-weight:520',
      text:'You were confident. That makes this the most valuable error in the session — it will come back before you leave.' }));
  }
  v.appendChild(el('p', { text: item.teach }));
  if (item.precision) {
    const p = el('div', { class:'precision' });
    p.innerHTML = `<div class="lbl">Say it exactly like this</div><p>${esc(item.precision)}</p>`;
    v.appendChild(p);
  }
  if (item.source) v.appendChild(el('p', { class:'src', style:'margin-top:12px', text:'Source: ' + item.source }));
  wrap.appendChild(v);

  // near-neighbour warnings from the concept graph
  const nots = [];
  item.concepts.forEach(cid => {
    const n = CONCEPT[cid];
    if (n && n.notThis && n.notThis.length) nots.push([n.label, n.notThis]);
  });
  if (!correct && nots.length) {
    const d = el('details', { class:'disc' });
    d.innerHTML = `<summary>What this is NOT — the near misses that lose marks</summary>`;
    const dc = el('div', { class:'dc' });
    nots.slice(0, 2).forEach(([label, list]) => {
      dc.appendChild(el('div', { class:'lbl', style:'margin-bottom:6px', text: label }));
      list.forEach(x => dc.appendChild(el('p', { style:'font-size:13px;color:var(--ink-2);margin:0 0 6px', text:'✕ ' + x })));
    });
    d.appendChild(dc);
    wrap.appendChild(d);
  }

  // error classification — learner's own diagnosis, kept alongside the engine's
  if (!correct) {
    const box = el('div', { class:'panel pad', style:'margin-top:12px' });
    box.appendChild(el('div', { class:'lbl', style:'margin-bottom:9px', text:'What actually went wrong?' }));
    const row = el('div', { class:'tagrow' });
    ERROR_TYPES.forEach(([id, nm, hint]) => {
      const t = el('button', { class:'tag', title: hint, style:'cursor:pointer;font-size:11.5px;padding:5px 10px', text: nm });
      t.addEventListener('click', () => {
        $$('.tag', row).forEach(x => x.classList.remove('on'));
        t.classList.add('on');
        const e = S.errors.find(x => x.id === item.id && !x.type);
        if (e) { e.type = id; save(); }
      });
      row.appendChild(t);
    });
    box.appendChild(row);
    wrap.appendChild(box);
  }

  const nextBtn = el('button', { class:'btn pri lg', style:'margin-top:18px', text:'Continue  ⏎', onclick: onNext });
  wrap.appendChild(nextBtn);
  const h = e => { if (e.key === 'Enter' && !e.target.matches('textarea,input')) { e.preventDefault(); document.removeEventListener('keydown', h); onNext(); } };
  document.addEventListener('keydown', h);
  return wrap;
}

function scrollToEnd(host) {
  requestAnimationFrame(() => {
    const st = $('#stage');
    st.scrollTo({ top: st.scrollHeight, behavior: 'smooth' });
  });
}
