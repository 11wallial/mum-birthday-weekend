/* ============================================================
   VIEWS — shell, router, Today, Practice, Progress, Drill

   Structure over decoration. Each screen is a short page head, then
   sections: a quiet label, a hairline, and content. Containers are used
   where content genuinely groups, not to make every item look like a
   component.
   ============================================================ */

/* One stroke weight, one optical size, no coloured chips behind them.
   Emoji render inconsistently across platforms and read as decoration. */
const ICON = {
  /* Drawn on one 24-unit grid: 1.6 stroke, round caps and joins, every glyph
     sitting in the same 18-unit optical box, circles all r=2.2. No fills, so
     nothing reads heavier than its neighbours. */
  bench:  '<path d="M6.2 3.4h7.3l4.3 4.3v12.9H6.2z"/><path d="M13.4 3.5v4.3h4.3"/><path d="M9 13h6.2M9 16.4h3.6"/>',
  panel:  '<rect x="9.2" y="2.9" width="5.6" height="10.5" rx="2.8"/><path d="M6 11.1a6 6 0 0 0 12 0"/><path d="M12 17.1v3.5"/><path d="M9.2 20.6h5.6"/>',
  studio: '<path d="M12 3.2 3.6 7.5 12 11.8l8.4-4.3z"/><path d="m3.6 12 8.4 4.3 8.4-4.3"/><path d="m3.6 16.5 8.4 4.3 8.4-4.3"/>',
  room:   '<path d="M3.4 6.6a2.2 2.2 0 0 1 2.2-2.2h7.8a2.2 2.2 0 0 1 2.2 2.2v3.6a2.2 2.2 0 0 1-2.2 2.2H7l-3.6 2.7z"/><path d="M9 15.4a2.2 2.2 0 0 0 2.2 2.2h5.2l4.2 2.8v-8.6a2.2 2.2 0 0 0-2.2-2.2h-1.4"/>',
  drill:  '<path d="M13.4 2.6 5.2 13.4h5.5l-1.1 8 8.2-10.8h-5.5z"/>',
  atlas:  '<circle cx="6" cy="7" r="2.2"/><circle cx="18" cy="6.4" r="2.2"/><circle cx="12" cy="14" r="2.2"/><circle cx="18.6" cy="18" r="2.2"/><path d="M7.9 8.3 10.3 12.6M16.3 7.6 13.6 12.2M13.8 15.5 16.8 17.1"/>',
  ledger: '<path d="M5.4 4.2h13.2v16.4l-2.9-2-1.9 2-1.9-2-1.9 2-1.9-2-2.8 2z"/><path d="M9.2 9h5.6M9.2 12.6h5.6"/>',
  go:     '<path d="M4.5 12h14"/><path d="m12.8 6.3 5.7 5.7-5.7 5.7"/>',
  clock:  '<circle cx="12" cy="12" r="8.2"/><path d="M12 7.4V12l3.2 1.9"/>',
  search: '<circle cx="11" cy="11" r="6.4"/><path d="m19.8 19.8-4.3-4.3"/>',
  gear:   '<circle cx="12" cy="12" r="3.2"/><path d="M12 3v2.4M12 18.6V21M21 12h-2.4M5.4 12H3M18.4 5.6l-1.7 1.7M7.3 16.7l-1.7 1.7M18.4 18.4l-1.7-1.7M7.3 7.3 5.6 5.6"/>',
  theme:  '<circle cx="12" cy="12" r="8.2"/><path d="M12 3.8a8.2 8.2 0 0 1 0 16.4z" fill="currentColor" stroke="none"/>',
  flame:  '<path d="M12 21.2a6.6 6.6 0 0 0 6.6-6.6c0-3.8-2.9-6.2-3.4-9.6-2.4 2.7-3.2 4.1-3.2 4.1S10.5 6.6 8.6 5.6c0 2.9-3.2 4.3-3.2 9a6.6 6.6 0 0 0 6.6 6.6z"/>',
};
function icon(name, size) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"
    stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"${size ? ` width="${size}" height="${size}"` : ''}>${ICON[name] || ''}</svg>`;
}

const MODES = [
  ['today',    'Today',    'What the engine would have you do now'],
  ['practice', 'Practice', 'Every surface: drill, papers, panels, cases, role-play'],
  ['progress', 'Progress', 'What you hold, and what you keep getting wrong'],
];
let VIEW = 'today', TIMERS = [];
/* The verdict panel binds a document-level key handler. Navigating away must
   unbind it, or it survives into the next screen. */
let VERDICT_OFF = null;
function clearVerdict() { if (VERDICT_OFF) { VERDICT_OFF(); VERDICT_OFF = null; } }

function clearTimers() {
  TIMERS.forEach(t => { if (t && t.__off) t.__off(); else clearInterval(t); });
  TIMERS = [];
}
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
    setTimeout(() => { if (!this.el.classList.contains('up')) this.el.innerHTML = ''; }, 380);
  },
};

/* Which tab owns each screen. Sub-pages used to leave every tab unselected,
   so the navigation could not say where you were. */
const OWNER = {
  today:'today', practice:'practice', progress:'progress',
  drill:'practice', papers:'practice', panel:'practice', studio:'practice', room:'practice',
  atlas:'progress', ledger:'progress',
};
const VIEWS = { today:vToday, practice:vPractice, progress:vProgress, drill:vDrill,
                papers:vBench, panel:vPanel, studio:vStudio, room:vRoom,
                atlas:vAtlas, ledger:vLedger };
/* 'Bench' read as furniture rather than as the written-paper surface. The old
   route still resolves so any link already made keeps working. */
const ROUTE_ALIAS = { bench: 'papers' };
const TITLES = { today:'Today', practice:'Practice', progress:'Progress', drill:'Drill',
                 papers:'Papers', panel:'The Panel', studio:'The Studio', room:'The Room',
                 atlas:'The Atlas', ledger:'The Ledger' };

/* Hash routing. The single go() chokepoint is the whole router: every screen
   gets a URL, the browser's back button works instead of leaving the app, and
   a screen can be linked to. `replace` is used when a view redirects to
   itself so we do not push a history entry the user has to press back twice
   through. */
let ROUTING = false;

function routeOf(view, arg) {
  return '#/' + view + (arg ? '/' + encodeURIComponent(arg) : '');
}

function go(view, arg, opts) {
  opts = opts || {};
  if (ROUTE_ALIAS[view]) view = ROUTE_ALIAS[view];
  if (!VIEWS[view]) view = 'today';
  clearTimers(); clearVerdict(); focusMode(false); Act.hide();
  if (MODES.some(m => m[0] === view)) { VIEW = view; S.lastMode = view; save(); }

  if (!ROUTING && !opts.fromPop) {
    const url = routeOf(view, arg);
    if (location.hash !== url) {
      if (opts.replace) history.replaceState({ view, arg }, '', url);
      else history.pushState({ view, arg }, '', url);
    }
  }
  document.title = (TITLES[view] ? TITLES[view] + ' · ' : '') + 'DClinPsy Trainer';

  const owner = OWNER[view] || view;
  $$('#tabs .tab').forEach(t => {
    const on = t.dataset.v === owner;
    t.setAttribute('aria-selected', String(on));
    t.tabIndex = on ? 0 : -1;
  });

  const stage = $('#stage');
  stage.scrollTop = 0;
  stage.innerHTML = '';
  VIEWS[view](stage, arg);
  refreshTop();
}

/* Read the address bar and render it. Guarded so the render does not push a
   new entry for the state we are already restoring. */
function applyRoute(fromPop) {
  const m = /^#\/([a-z]+)(?:\/(.*))?$/.exec(location.hash || '');
  const raw = m ? (ROUTE_ALIAS[m[1]] || m[1]) : null;
  const view = raw && VIEWS[raw] ? raw : null;
  const arg = m && m[2] ? decodeURIComponent(m[2]) : undefined;
  ROUTING = true;
  try {
    if (!view) go(S.lastMode && MODES.some(x => x[0] === S.lastMode) ? S.lastMode : 'today',
                  undefined, { fromPop: true });
    else go(view, arg, { fromPop: true });
  } finally { ROUTING = false; }
}

function refreshTop() {
  const s = $('#streakn');
  if (s) s.textContent = S.streak.n || 0;
  const f = $('#streak');
  if (f) f.style.display = S.streak.n ? '' : 'none';
}

/* ---------------------------------------------------------- structure helpers */
function pageHead(label, title, sub, big) {
  const h = el('div', { class:'pagehead' + (big ? ' big' : '') });
  if (label) h.appendChild(el('span', { class:'lbl', text: label }));
  h.appendChild(el('h1', { text: title }));
  if (sub) h.appendChild(el('div', { class:'sub', text: sub }));
  return h;
}

function section(label, opts) {
  opts = opts || {};
  const s = el('div', { class:'section' });
  const h = el('div', { class:'sechead' });
  h.appendChild(el('span', { class:'lbl', text: label }));
  if (opts.note) h.appendChild(el('span', { class:'note', text: opts.note }));
  if (opts.act) h.appendChild(el('button', { class:'act', text: opts.act, onclick: opts.onAct }));
  s.appendChild(h);
  return s;
}

function plate(rows) {
  const p = el('div', { class:'plate' });
  (rows || []).forEach(r => r && p.appendChild(r));
  return p;
}

/* one row of a plate. `lead` is an optional node placed before the text. */
function prow(o) {
  const r = el(o.onclick ? 'button' : 'div', { class:'prow' });
  if (o.onclick) r.addEventListener('click', o.onclick);
  if (o.lead) r.appendChild(o.lead);
  const m = el('div', { class:'pmain' });
  m.appendChild(el('div', { class:'pname', text: o.name }));
  if (o.sub) m.appendChild(el('div', { class:'psub', text: o.sub }));
  r.appendChild(m);
  if (o.tail) r.appendChild(o.tail);
  if (o.val != null) r.appendChild(el('div', { class:'pval', text: String(o.val) }));
  if (o.onclick) r.appendChild(el('span', { class:'chev', text:'›' }));
  return r;
}

function dotEl(domain) { return el('span', { class:'dot ' + domain, 'aria-hidden':'true' }); }

/* One way back, used everywhere. Each screen used to invent its own — "← All
   cases" in the Studio, "← Leave" in the Room, nothing at all in the papers and
   the Panel — so the return path changed shape depending where you were. */
function backLink(label, onBack) {
  const b = el('button', { class:'backlink', onclick: onBack });
  b.innerHTML = `<span class="bk" aria-hidden="true">${icon('go', 15)}</span><span>${esc(label)}</span>`;
  return b;
}

/* Segmented control. The thumb is a single element that travels, so changing
   the choice reads as one object moving rather than two highlights swapping. */
function segEl(options, current, onPick) {
  const wrap = el('div', { class:'seg' });
  const thumb = el('i', { class:'thumb' });
  wrap.appendChild(thumb);
  const btns = options.map(([val, label]) => {
    const b = el('button', { text: label, class: val === current ? 'on' : '' });
    b.addEventListener('click', () => {
      if (b.classList.contains('on')) return;
      btns.forEach(x => x.classList.toggle('on', x === b));
      place();
      onPick(val);
    });
    wrap.appendChild(b);
    return b;
  });
  function place() {
    const on = btns.find(b => b.classList.contains('on')) || btns[0];
    if (!on || !on.offsetWidth) return;
    thumb.style.width = on.offsetWidth + 'px';
    thumb.style.transform = `translateX(${on.offsetLeft}px)`;
  }
  requestAnimationFrame(() => {
    // the first placement must not animate in from zero
    const t = thumb.style.transition;
    thumb.style.transition = 'none';
    place();
    requestAnimationFrame(() => { thumb.style.transition = t; });
  });
  return wrap;
}

/* Count a number up to its value. Numbers that matter should arrive, not
   appear — but only where the value is the point of the element. */
function countUp(node, to, ms) {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) { node.textContent = to; return; }
  const dur = ms || 760, t0 = performance.now();
  function step(now) {
    const k = Math.min(1, (now - t0) / dur);
    const e = 1 - Math.pow(1 - k, 4);                 // expo-out, matches --e-out
    node.textContent = Math.round(to * e);
    if (k < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

/* the depth ladder, drawn — five rungs, filled to the level demonstrated */
function rungsEl(depth, domain) {
  const w = el('div', { class:'rungs ' + (domain || ''), title: LEVELS[depth] || 'unseen' });
  for (let i = 1; i <= 5; i++) w.appendChild(el('i', { class: i <= depth ? 'on' : '' }));
  return w;
}

/* `ghost`, when given, draws a second faint arc behind the value. On the
   readiness ring it is the unweighted mean of the three domains, so the gap
   between the two arcs *is* the weighting — the chart shows you what the
   formula did to you rather than asserting a number. */
function ringEl(pct, size, stroke, colour, label, sub, ghost) {
  const r = (size - stroke) / 2, C = 2 * Math.PI * r;
  const w = el('div', { class:'ring', style:`width:${size}px;height:${size}px` });
  const clamp = v => Math.max(0, Math.min(100, v));
  w.innerHTML =
    `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
       <circle class="trk" cx="${size/2}" cy="${size/2}" r="${r}" stroke-width="${stroke}"></circle>
       ${ghost != null ? `<circle class="ghost" cx="${size/2}" cy="${size/2}" r="${r}"
               stroke-width="${stroke}" stroke="${colour}" stroke-opacity=".22"
               stroke-dasharray="${C}" stroke-dashoffset="${C}"></circle>` : ''}
       <circle class="val" cx="${size/2}" cy="${size/2}" r="${r}" stroke-width="${stroke}"
               stroke="${colour}" stroke-dasharray="${C}" stroke-dashoffset="${C}"></circle>
     </svg>
     <div class="mid">
       <div class="dnum" style="font-size:${Math.round(size*0.3)}px">${label}</div>
       ${sub ? `<div class="lbl" style="font-size:9px;margin-top:1px">${sub}</div>` : ''}
     </div>`;
  requestAnimationFrame(() => {
    const v = $('.val', w);   if (v) v.style.strokeDashoffset = C * (1 - clamp(pct) / 100);
    const g = $('.ghost', w); if (g) g.style.strokeDashoffset = C * (1 - clamp(ghost) / 100);
    const n = $('.dnum', w);
    if (n && /^\d+$/.test(String(label))) countUp(n, +label, 900);
  });
  return w;
}

/* a domain line: name, bar, value, and — when there is history — movement */
function domainRow(d, pct, mv) {
  const row = el('div', { style:'padding:13px 0;border-top:1px solid var(--line)' });
  const arrow = !mv ? '' : mv.up > mv.dn ? `<span class="mv up">↑ ${mv.up} advanced</span>`
    : mv.dn > mv.up ? `<span class="mv dn">↓ ${mv.dn} slipped</span>`
    : (mv.up || mv.dn) ? '<span class="mv fl">→ holding</span>' : '';
  row.innerHTML =
    `<div class="row" style="margin-bottom:7px;gap:8px">
       <span class="dot ${d}"></span>
       <span style="font-weight:600;font-size:14px">${d[0].toUpperCase() + d.slice(1)}</span>
       <span class="spacer"></span>
       ${arrow}
       <span class="dnum" style="font-size:14px;color:var(--ink-2)">${pct}</span>
     </div>
     <div class="meter ${d}"><i></i></div>`;
  requestAnimationFrame(() => { $('i', row).style.width = pct + '%'; });
  return row;
}

/* ---------------------------------------------------------- TODAY */
let PLAN_MIN = 12;

/* The Today headline, written from the queue the engine has actually built.
   It leads with the most valuable thing in the session rather than with a
   greeting: a confident error outranks a due review, which outranks new
   material. Nothing here is decorative — every number is the real one. */
function sessionHeadline(started, due, hcw) {
  if (!started) return {
    title: 'Start with the diagnostic.',
    sub: 'Twelve items across all three domains. After that it stops sampling and starts targeting.' };

  const plan = sessionPlan(Math.max(6, Math.round(PLAN_MIN * 0.85)));
  if (!plan.total) return {
    title: 'Nothing is due.',
    sub: 'Every item is scheduled further out. The papers and the Panel are the better use of this session.' };

  const top = plan.groups[0];
  const others = plan.groups.length - 1;
  const spread = others > 0
    ? `${top.label.toLowerCase()} and ${others} other area${others === 1 ? '' : 's'}`
    : top.label.toLowerCase();

  if (hcw) return {
    title: `${hcw} you were sure about and got wrong.`,
    sub: `They come first this session, then ${plan.total - Math.min(hcw, plan.total)} more across ${spread}.` };
  if (due) return {
    title: `${due} item${due === 1 ? '' : 's'} due.`,
    sub: `${PLAN_MIN} minutes on ${spread}, interleaved so no cluster runs twice in a row.` };
  return {
    title: `${PLAN_MIN} minutes on ${spread}.`,
    sub: 'Nothing overdue, so this session brings new material and stretches what you already hold.' };
}

function vToday(stage) {
  const w = el('div', { class:'wrap today stg' });
  const rd = readiness(), d2i = daysToInterview(), due = dueCount();
  const hcw = S.errors.filter(e => e.conf >= 4).length;
  const started = Object.keys(S.c).length > 0;
  const hour = new Date().getHours();

  /* The headline states what this session is, drawn from the real queue. The
     greeting moves to the eyebrow: it was the largest text on the most-visited
     screen and it carried no information. */
  const greet = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  const date = new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long' });
  const head = sessionHeadline(started, due, hcw);
  w.appendChild(pageHead(date + ' · ' + greet, head.title, head.sub, true));

  w.appendChild(launchPanel(started, due, hcw));

  if (d2i !== null) {
    const phase = d2i <= 14 ? 'Fluency phase — intervals halved, sessions weight retrieval speed and simulation.'
                : d2i <= 45 ? 'Intervals have tightened as the date approaches.'
                : 'Plenty of runway. This is the phase for building depth rather than speed.';
    const m = el('div', { class:'row', style:'margin-top:14px;gap:8px;align-items:baseline' });
    m.innerHTML = `<span class="dnum" style="font-size:15px;color:var(--accent)">${d2i}</span>
      <span class="meta"><b>days to interview.</b> ${esc(phase)}</span>`;
    w.appendChild(m);
  }

  if (started) {
    const s = section('Where you are', { act:'Full breakdown', onAct: () => go('progress') });
    const mean = Math.round((rd.research + rd.clinical + rd.professional) / 3);
    const top = el('div', { class:'row', style:'gap:20px;margin-bottom:4px;align-items:center' });
    top.appendChild(ringEl(rd.overall, 78, 8, band(rd.overall)[3], rd.overall, '', mean));
    const t = el('div', { style:'flex:1 1 auto' });
    t.innerHTML = `<div style="font-weight:600;font-size:17px;margin-bottom:3px;letter-spacing:-.024em">${band(rd.overall)[2]}</div>
      <div class="src">The faint arc is your plain average, ${mean}. Readiness sits ${rd.overall === mean ? 'level with it' : (rd.overall < mean ? 'below' : 'above') + ' it'} because it weights your weakest domain — selection filters on the weakest panel you sit, not the strongest.</div>`;
    top.appendChild(t);
    s.appendChild(top);
    const mv = recentMovement(7);
    ['research','clinical','professional'].forEach(d => s.appendChild(domainRow(d, rd[d], mv[d])));
    w.appendChild(s);
  }

  /* These two read as a pair — what you gained, and what keeps costing you —
     so at wide widths they sit beside each other rather than stacking. */
  const clusters = misconceptionClusters(3);
  if (S.wins.length || clusters.length) {
    const pair = el('div', { class:'pair' });
    if (S.wins.length) {
      const s = section('What changed', { note:'most recent first' });
      s.appendChild(plate(S.wins.slice(0, 5).map(win => {
        const node = CONCEPT[win.cid];
        return prow({ lead: dotEl(node ? node.domain : 'research'), name: win.text,
                      tail: el('span', { class:'meta', text: relTime(win.ts) }) });
      })));
      pair.appendChild(s);
    }
    if (clusters.length) {
      const s = section('Underneath your errors', { note:'mistakes that share a root' });
      s.appendChild(plate(clusters.map(cl => prow({
        lead: dotEl(cl.node.domain), name: cl.node.label,
        sub: `${Math.round(cl.n)} errors trace back here`,
        val: cl.m, onclick: () => showConcept(cl.cid) }))));
      pair.appendChild(s);
    }
    w.appendChild(pair);
  }

  const s = section('Or work on something specific');
  s.appendChild(plate(SURFACES.map(([id, nm, mk, dom, blurb, count]) => prow({
    lead: el('span', { class:'rlead', html: icon(mk) }),
    name: nm, sub: blurb, tail: el('span', { class:'meta', text: count() }),
    onclick: () => go(id) }))));
  w.appendChild(s);
  stage.appendChild(w);
}

/* The launch panel is the one thing on Today with real visual weight, and
   it shows the queue it is about to hand you rather than asserting that it
   knows best. */
function launchPanel(started, due, hcw) {
  const p = el('div', { class:'launch' });
  p.appendChild(el('div', { class:'lbl', text:'Recommended' }));
  /* The page headline already states what this session is, so the panel does
     not restate it — it shows the queue and hands over the controls. */
  p.appendChild(el('p', { style:'margin-top:6px', text: !started
    ? 'The engine watches what you get wrong and how sure you were, then stops sampling and starts targeting.'
    : 'Chosen by what is due, what you got wrong while confident, and which concepts sit lowest.' }));

  const planBox = el('div', { style:'margin-top:16px' });
  p.appendChild(planBox);

  const foot = el('div', { class:'lfoot' });
  foot.appendChild(segEl([[12,'12 min'], [25,'25 min'], [45,'45 min']], PLAN_MIN, m => {
    PLAN_MIN = m;
    drawPlan(planBox, m);
  }));
  foot.appendChild(el('div', { class:'spacer', style:'flex:1 1 auto' }));
  const start = el('button', { class:'btn pri lg', onclick: () => startDrill(PLAN_MIN) });
  start.innerHTML = `Start session <span class="arw">${icon('go', 16)}</span>`;
  foot.appendChild(start);
  p.appendChild(foot);

  drawPlan(planBox, PLAN_MIN);
  return p;
}

function drawPlan(box, minutes) {
  box.innerHTML = '';
  const plan = sessionPlan(Math.max(6, Math.round(minutes * 0.85)));
  if (!plan.total) {
    box.appendChild(el('p', { class:'src', text:'Nothing is queued right now — every item is scheduled further out. The papers and the Panel are the better use of this session.' }));
    return;
  }
  const ph = el('div', { class:'row', style:'margin-bottom:2px;gap:10px' });
  ph.innerHTML = `<span class="lbl">What it will cover</span><span class="spacer"></span>
    <span class="meta">${plan.total} items</span>`;
  box.appendChild(ph);
  plan.groups.slice(0, 4).forEach((g, i) => {
    const r = el('div', { class:'planline' });
    r.innerHTML = `<span class="n">${i + 1}</span>
      <span class="dot ${g.domain}"></span>
      <span class="pl-t">${esc(g.label)}</span>
      <span class="pl-w">${g.n} · ${esc(REASON_TEXT[g.reason])}</span>`;
    box.appendChild(r);
  });
  const rest = plan.groups.slice(4).reduce((a, g) => a + g.n, 0);
  if (rest) box.appendChild(el('div', { class:'src', style:'padding-top:8px',
    text: `and ${rest} more across ${plan.groups.length - 4} other area${plan.groups.length - 4 === 1 ? '' : 's'}` }));
}

const SURFACES = [
  ['papers', 'Papers', 'bench', 'clinical',
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
    b.innerHTML = `<span class="tmk">${icon(mk)}</span>
      <h3>${nm}</h3><p>${esc(blurb)}</p>
      <div class="tfoot"><span class="meta">${esc(count())}</span></div>`;
    g.appendChild(b);
  });
  return g;
}

/* ---------------------------------------------------------- PRACTICE */
function vPractice(stage) {
  const w = el('div', { class:'wrap stg' });
  w.appendChild(pageHead(null, 'Practice',
    'Drill trains retrieval and discrimination. The other four rehearse the actual tasks selection puts in front of you.', true));

  const s1 = section('Recommended');
  const drill = el('button', { class:'tile feature', onclick: () => startDrill(PLAN_MIN) });
  drill.innerHTML =
    `<span class="tmk">${icon('drill')}</span>
     <span class="tbody">
       <h3>Drill</h3>
       <p>Adaptive interleaved retrieval. Chosen by what is due, what you got wrong while confident, and which concepts sit lowest.</p>
       <div class="tfoot"><span class="meta"><b>${dueCount()}</b> due<span class="sep">·</span><b>${unseenCount()}</b> unseen<span class="sep">·</span>${PLAN_MIN} min</span></div>
     </span>
     <span class="tgo"><span class="btn pri">Start<span class="arw">${icon('go', 15)}</span></span></span>`;
  s1.appendChild(drill);
  w.appendChild(s1);

  const s2 = section('Simulate the real thing', { note:'the four tasks selection actually sets' });
  s2.appendChild(surfaceGrid(2));
  w.appendChild(s2);

  const s3 = section('Study the map');
  s3.appendChild(plate([
    prow({ lead: el('span', { class:'rlead', html: icon('atlas') }), name:'The Atlas',
           sub:`A live map of ${DATA.concepts.nodes.length} concepts. Dim hubs with many links are the highest-leverage targets.`,
           onclick: () => go('atlas') }),
    prow({ lead: el('span', { class:'rlead', html: icon('ledger') }), name:'The Ledger',
           sub:`${S.errors.length} recorded errors, classified, ordered by what will cost you most.`,
           onclick: () => go('ledger') }),
  ]));
  w.appendChild(s3);
  stage.appendChild(w);
}

/* ---------------------------------------------------------- PROGRESS */
function vProgress(stage) {
  const w = el('div', { class:'wrap stg' });
  const rd = readiness(), cal = calibration(), mv = recentMovement(7);
  w.appendChild(pageHead(null, 'Progress',
    'Depth is earned level by level. Recognising something never counts as mastering it, and a failed transfer item takes depth back.', true));

  /* readiness — the one number, with the weighting stated rather than hidden */
  const s0 = section('Readiness', { note:'0.62 × mean of domains + 0.38 × weakest' });
  const mean = Math.round((rd.research + rd.clinical + rd.professional) / 3);
  const top = el('div', { class:'row', style:'gap:24px;align-items:center;margin-bottom:4px' });
  top.appendChild(ringEl(rd.overall, 96, 9, band(rd.overall)[3], rd.overall, '', mean));
  const rt = el('div', { style:'flex:1 1 auto' });
  rt.innerHTML = `<div style="font-weight:600;font-size:20px;letter-spacing:-.03em;margin-bottom:4px">${band(rd.overall)[2]}</div>
    <div class="src">The solid arc is your readiness. The faint one behind it is the plain average of the three domains, <b>${mean}</b> — the distance between them is what the weakest-domain weighting costs you.</div>`;
  top.appendChild(rt);
  s0.appendChild(top);
  ['research','clinical','professional'].forEach(d => s0.appendChild(domainRow(d, rd[d], mv[d])));
  s0.appendChild(el('div', { class:'meta', style:'margin-top:16px',
    html: `<b>${dueCount()}</b> due<span class="sep">·</span><b>${unseenCount()}</b> not yet seen<span class="sep">·</span><b>${Object.keys(S.c).length}</b> of ${DATA.concepts.nodes.length} concepts met` }));
  w.appendChild(s0);

  /* calibration */
  const s1 = section('Calibration', { note:'the gap between how sure you were and whether you were right' });
  if (cal.score === null) {
    s1.appendChild(el('p', { class:'src',
      text:'No data yet. Every item asks how sure you are before you answer; the gap between that and the outcome is what gets scored here.' }));
  } else {
    const head = el('div', { class:'row', style:'gap:20px;align-items:flex-start;margin-bottom:16px' });
    const n = el('div', { class:'statline', style:'flex:none' });
    n.innerHTML = `<span class="dnum v" style="color:${band(cal.score)[3]}">${cal.score}</span><span class="u">/ 100</span>`;
    head.appendChild(n);
    head.appendChild(el('p', { class:'src', style:'flex:1 1 auto;max-width:44ch',
      text:'The goal is calibrated confidence, not maximum confidence. Being sure and wrong costs more than being unsure and right.' }));
    s1.appendChild(head);
    s1.appendChild(plate([
      prow({ name:'Sure and wrong', sub:'Highest priority — the belief felt settled', val: cal.hcw }),
      prow({ name:'Unsure and right', sub:'Knowledge you have but do not trust', val: cal.lcr }),
      prow({ name:'Rated answers', val: cal.n }),
    ]));
  }
  w.appendChild(s1);

  /* movement — real events, not a synthetic delta */
  const anyMv = ['research','clinical','professional'].some(d => mv[d].up || mv[d].dn);
  if (anyMv) {
    const s2 = section('Movement', { note:'last 7 days' });
    s2.appendChild(plate(['research','clinical','professional'].map(d => {
      const m = mv[d];
      const tone = m.up > m.dn ? 'up' : m.dn > m.up ? 'dn' : 'fl';
      const word = tone === 'up' ? 'gaining' : tone === 'dn' ? 'losing ground' : 'holding';
      return prow({ lead: dotEl(d), name: d[0].toUpperCase() + d.slice(1),
        sub: `${m.up} concept${m.up === 1 ? '' : 's'} advanced a level · ${m.dn} error${m.dn === 1 ? '' : 's'}`,
        tail: el('span', { class:'mv ' + tone, text: word }) });
    })));
    w.appendChild(s2);
  }

  /* weakest held — with the depth ladder drawn, not just a percentage */
  const weak = weakConcepts(8);
  if (weak.length) {
    const s3 = section('Weakest held', { note:'depth demonstrated, not questions answered' });
    s3.appendChild(plate(weak.map(x => prow({
      lead: dotEl(x.n.domain), name: x.n.label,
      sub: (x.rec && x.rec.hcw ? `sure and wrong ×${x.rec.hcw} · ` : '') + (LEVELS[(x.rec && x.rec.d) || 0] || 'unseen'),
      tail: rungsEl((x.rec && x.rec.d) || 0, x.n.domain),
      val: x.m, onclick: () => showConcept(x.n.id) }))));
    w.appendChild(s3);
  }

  const s4 = section('Deeper');
  const links = el('div', { class:'grid g2' });
  [['atlas', 'The Atlas', 'atlas', 'A live map of ' + DATA.concepts.nodes.length + ' concepts. Nodes brighten as you demonstrate depth, and dim hubs with many links are the highest-leverage targets.'],
   ['ledger', 'The Ledger', 'ledger', S.errors.length + ' recorded errors, classified, ordered by what will cost you most.']]
   .forEach(([id, nm, mk, blurb]) => {
    const b = el('button', { class:'tile', onclick: () => go(id) });
    b.innerHTML = `<span class="tmk">${icon(mk)}</span><h3>${nm}</h3><p>${esc(blurb)}</p>`;
    links.appendChild(b);
  });
  s4.appendChild(links);
  w.appendChild(s4);
  stage.appendChild(w);
}


/* ============================================================
   DRILL
   ============================================================ */
let SESSION = null;

function startDrill(minutes) {
  const n = Math.max(6, Math.round(minutes * 0.85));
  const items = buildSession(n);
  if (!items.length) { toast('Nothing to drill right now — try the papers or the Panel'); return; }
  SESSION = { items, idx:0, right:0, started:Date.now(), answers:[], minutes, wasWins: S.wins.length };
  go('drill');
}

function quitDrill() {
  const midway = SESSION && SESSION.answers.length && SESSION.idx < SESSION.items.length;
  if (!midway) { SESSION = null; go('today'); return; }
  const left = SESSION.items.length - SESSION.idx;
  confirmDialog({
    title: 'Leave this session?',
    text: `${left} item${left === 1 ? '' : 's'} left. Everything you have already answered is saved, ` +
          'and the scheduler has it — nothing is lost by stopping here.',
    cancel: 'Keep going',
    confirm: 'Leave',
    onConfirm: () => { SESSION = null; go('today'); },
  });
}

function vDrill(stage) {
  if (!SESSION) { go('practice', undefined, { replace: true }); return; }
  if (SESSION.idx >= SESSION.items.length) return drillDone(stage);

  focusMode(true);
  const item = SESSION.items[SESSION.idx];

  const bar = el('div', { id:'sessbar' });
  const pct = SESSION.idx / SESSION.items.length * 100;
  bar.innerHTML = `<button class="x" title="Leave" aria-label="Leave this session">✕</button>
    <div class="track" role="progressbar" aria-label="Session progress"
         aria-valuemin="0" aria-valuemax="${SESSION.items.length}" aria-valuenow="${SESSION.idx}"><i></i></div>
    <span class="lbl" style="flex:none">${SESSION.idx + 1}/${SESSION.items.length}</span>`;
  $('.x', bar).addEventListener('click', quitDrill);
  stage.appendChild(bar);
  /* The bar is a new element on every item, so it had nothing to animate from
     and arrived as a jump. Start it where the last one finished and let the
     width transition carry it — the one place in the drill where motion means
     something. */
  const track = $('.track i', bar);
  track.style.width = (SESSION.lastPct || 0) + '%';
  requestAnimationFrame(() => requestAnimationFrame(() => { track.style.width = pct + '%'; }));
  SESSION.lastPct = pct;

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

  /* go('drill') rebuilds the stage for every item, which dropped focus to
     <body> each time and made a keyboard user re-tab from the top on every
     question. Put focus on the new question instead, and say where we are. */
  requestAnimationFrame(() => {
    const stem = $('.qstem, .qctx', host);
    if (stem) {
      stem.setAttribute('tabindex', '-1');
      stem.focus({ preventScroll: true });
    }
    announce(`Question ${SESSION.idx + 1} of ${SESSION.items.length}. ${
      (item.stem || '').slice(0, 160)}`);
  });

  renderItem(host, item, res => {
    SESSION.answers.push(res);
    if (res.correct) SESSION.right++;
    SESSION.idx++;
    if (res.hiConfWrong && SESSION.items.length < 60) {
      SESSION.items.splice(Math.min(SESSION.items.length, SESSION.idx + 4), 0, item);
    }
    go('drill', undefined, { replace: true });
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

  const w = el('div', { class:'wrap narrow stg', style:'padding-top:56px' });
  const head = el('div', { class:'row', style:'gap:22px;align-items:center;margin-bottom:28px' });
  head.appendChild(ringEl(pct, 84, 8, band(pct)[3], pct + '%', ''));
  const ht = el('div', { style:'flex:1 1 auto' });
  ht.innerHTML = `<h1 style="font-size:24px">${pct >= 80 ? 'Strong session.' : pct >= 50 ? 'Session complete.' : 'Useful session.'}</h1>
    <p class="src" style="margin-top:6px;max-width:38ch">${
      pct >= 80 ? 'Hold that. The scheduler will push these further out and bring you harder versions.'
    : pct >= 50 ? 'The errors are the valuable part — they are already scheduled to come back.'
                : 'A low score early is information, not a verdict. The engine now knows where to aim.'}</p>`;
  head.appendChild(ht);
  w.appendChild(head);

  w.appendChild(plate([
    prow({ name:'Answered', val: n }),
    prow({ name:'Correct', val: SESSION.right + ' of ' + n }),
    prow({ name:'Time', val: fmtTime(secs) }),
  ]));

  if (newWins.length) {
    setTimeout(() => coachOn('depth'), 520);
    const s1 = section("What you can now do that you couldn't");
    s1.appendChild(plate(newWins.slice(0, 6).map(win => {
      const node = CONCEPT[win.cid];
      return prow({ lead: dotEl(node ? node.domain : 'research'), name: win.text });
    })));
    w.appendChild(s1);
  }

  if (hcw.length) {
    const c = el('div', { class:'flag', style:'margin-top:28px;background:var(--warning-soft);border-left-color:var(--warning)' });
    c.innerHTML = `<div class="lbl" style="color:var(--warning);margin-bottom:5px">Highest priority</div>
      You were confident and wrong on <b>${hcw.length}</b> item${hcw.length === 1 ? '' : 's'}. That combination matters more than the score: it means the belief felt settled. Those are scheduled to return today.`;
    w.appendChild(c);
  }

  const btns = el('div', { class:'row', style:'margin-top:32px;flex-wrap:wrap' });
  btns.appendChild(el('button', { class:'btn lg ghost', text:'Done', onclick: () => { SESSION = null; go('today'); } }));
  btns.appendChild(el('div', { class:'spacer', style:'flex:1 1 auto' }));
  btns.appendChild(el('button', { class:'btn pri lg', text:'Another session', onclick: () => startDrill(SESSION.minutes) }));
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
const CONF_LABEL = ['Guessing', 'Doubtful', 'Even', 'Fairly sure', 'Certain'];

function confControl(onPick) {
  setTimeout(() => coachOn('confidence'), 420);
  const wrap = el('div', { class:'confwrap' });
  wrap.appendChild(el('span', { class:'cl', id:'conflbl', text:'Sure?' }));
  /* A radiogroup, so the choice is announced as "Fairly sure, 4 of 5" rather
     than as the digit on the button face. */
  const pips = el('div', { class:'pips', role:'radiogroup', 'aria-labelledby':'conflbl' });
  for (let i = 1; i <= 5; i++) {
    pips.appendChild(el('button', { class:'pip', text:i, role:'radio', 'aria-checked':'false',
      'aria-label': `${CONF_LABEL[i-1]} — ${i} of 5`, title: CONF_LABEL[i-1],
      onclick: e => {
        $$('.pip', pips).forEach(b => { b.classList.remove('on'); b.setAttribute('aria-checked','false'); });
        e.currentTarget.classList.add('on');
        e.currentTarget.setAttribute('aria-checked','true');
        announce('Confidence: ' + CONF_LABEL[i-1]);
        onPick(i);
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

  /* Selection was visual only: .sel carried no state a screen reader could
     read. Single-answer items are a radiogroup, select-all items are toggle
     buttons, and both announce the letter with the option text. */
  const box = el('div', { class:'choices', role: multi ? 'group' : 'radiogroup',
                          'aria-label': multi ? 'Select all that apply' : 'Answer options' });
  const setSel = (node, on) => {
    node.classList.toggle('sel', on);
    node.setAttribute(multi ? 'aria-pressed' : 'aria-checked', String(on));
  };
  item.options.forEach((o, i) => {
    const letter = String.fromCharCode(65 + i);
    const b = el('button', { class:'choice', 'data-id':o.id,
                             role: multi ? undefined : 'radio',
                             'aria-label': letter + '. ' + o.text }, [
      el('span', { class:'key', text: letter, 'aria-hidden':'true' }),
      el('span', { class:'ctx' }, [el('span', { text: o.text })]),
    ]);
    b.setAttribute(multi ? 'aria-pressed' : 'aria-checked', 'false');
    b.addEventListener('click', () => {
      if (locked) return;
      if (multi) { const on = !picked.has(o.id); on ? picked.add(o.id) : picked.delete(o.id); setSel(b, on); }
      else {
        picked = new Set([o.id]);
        $$('.choice', box).forEach(x => setSel(x, x === b));
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
      b.setAttribute('aria-disabled', 'true');
      b.removeAttribute('aria-checked'); b.removeAttribute('aria-pressed');
      b.removeAttribute('role');
      const chose = picked.has(o.id);
      b.setAttribute('aria-label',
        `${b.getAttribute('aria-label')} — ${o.correct ? 'correct answer' : 'incorrect'}` +
        (chose ? ', you chose this' : ''));
      if (o.correct) b.classList.add('ok');
      else if (chose) b.classList.add('bad');
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
    const L = el('button', { class:'sidebtn', text:'◀', 'aria-pressed':'false',
                             'aria-label': `Put "${p.text}" under ${item.left}` });
    const R = el('button', { class:'sidebtn', text:'▶', 'aria-pressed':'false',
                             'aria-label': `Put "${p.text}" under ${item.right}` });
    row.append(L, el('span', { class:'t', text: p.text }), R);
    [[L,'L'],[R,'R']].forEach(([btn, side]) => btn.addEventListener('click', () => {
      if (locked) return;
      answers[i] = side;
      L.classList.toggle('on', side === 'L'); R.classList.toggle('on', side === 'R');
      L.setAttribute('aria-pressed', String(side === 'L'));
      R.setAttribute('aria-pressed', String(side === 'R'));
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
    $$('.choice', track).forEach(c => { c.classList.remove('faded'); c.setAttribute('aria-disabled','false'); });
    Act.hide();
    announce('Steps unlocked. Choose the first step.');
  })], []);

  function next() {
    if (rung >= item.rungs.length) return finish();
    const r = item.rungs[rung];
    const blk = el('div', { class:'card', style:'margin-bottom:12px' });
    blk.appendChild(el('div', { class:'lbl', text:'Step ' + (rung + 1) + ' of ' + item.rungs.length }));
    blk.appendChild(el('div', { style:'font-size:18px;font-weight:600;letter-spacing:-.015em;margin:7px 0 14px;line-height:1.35', text: r.q }));
    const opts = el('div', { class:'choices' });
    r.options.forEach((o, i) => {
      const letter = String.fromCharCode(65 + i);
      const b = el('button', { class:'choice' + (live ? '' : ' faded'),
                               'aria-label': letter + '. ' + o.text,
                               'aria-disabled': live ? 'false' : 'true',
                               style:'box-shadow:none;border-color:var(--line)' }, [
        el('span', { class:'key', text: letter, 'aria-hidden':'true' }),
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
          x.setAttribute('aria-disabled', 'true');
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
    body.appendChild(el('p', { style:'color:var(--warning);font-weight:600;font-size:14.5px;margin-bottom:10px',
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
      const t = el('button', { class:'pill act', title: hint, text: nm });
      t.addEventListener('click', () => {
        $$('.pill.act', row).forEach(x => x.classList.remove('on'));
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

  /* Advance exactly once, by whichever route the learner takes, and take the
     key handler with us. Previously this listener was removed only when Enter
     fired, so advancing with the mouse left it bound: the listeners stacked and
     one later Enter ran all of them, skipping unseen items and recording
     answers nobody gave. */
  let spent = false;
  function advance() {
    if (spent) return;
    spent = true;
    document.removeEventListener('keydown', onKey);
    VERDICT_OFF = null;
    onNext();
  }
  function onKey(e) {
    if (e.key !== 'Enter') return;
    const t = e.target;
    if (t && t.matches && t.matches('textarea, input, select')) return;
    e.preventDefault();
    advance();
  }

  const btn = el('button', { class: 'btn lg ' + (correct ? 'ok' : 'no'), text:'Continue', onclick: advance });
  Act.result(correct ? 'good' : 'bad', body, btn);
  if (correct) tick(880, .08, .05); else tick(300, .12, .045);

  document.addEventListener('keydown', onKey);
  VERDICT_OFF = () => { spent = true; document.removeEventListener('keydown', onKey); };

  /* The verdict is the moment the learner is waiting on, so it takes focus
     and is announced once — as a sentence, not as a re-read of the panel. */
  requestAnimationFrame(() => btn.focus({ preventScroll: true }));
  announce((correct ? 'Correct. ' : 'Not quite. ') +
           (rec.hiConfWrong ? 'You were confident. ' : '') +
           (item.teach || '').slice(0, 240));
  scrollEnd();
  return advance;
}

function scrollEnd() {
  requestAnimationFrame(() => {
    const st = $('#stage');
    st.scrollTo({ top: st.scrollHeight, behavior: 'smooth' });
  });
}
