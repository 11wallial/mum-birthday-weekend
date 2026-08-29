/* ============================================================
   ENGINE — learner model, scheduler, scoring
   ============================================================ */
'use strict';

const LEVELS = ['unseen','recognise','recall','apply','discriminate','transfer'];
const LEVEL_N = { recognise:1, recall:2, apply:3, discriminate:4, transfer:5 };
const BANDS = [
  [0,  39, 'Foundational deficit', 'var(--wrong)'],
  [40, 59, 'Emerging',             'var(--serious)'],
  [60, 74, 'Functional but unreliable', 'var(--warning)'],
  [75, 84, 'Competent',            'var(--seq-5)'],
  [85, 94, 'Strong',               'var(--seq-4)'],
  [95, 100,'Selection-ready',      'var(--good)'],
];
const ERROR_TYPES = [
  ['knowledge',    'Knowledge gap',            "I hadn't learned this"],
  ['concept',      'Conceptual misunderstanding', 'I understood it wrongly'],
  ['terminology',  'Terminology confusion',    'I meant the right thing, wrong word'],
  ['question',     'Question-interpretation',  'I answered a different question'],
  ['application',  'Application error',        'I knew it but misapplied it'],
  ['overgeneral',  'Overgeneralisation',       'I pushed a rule too far'],
  ['reasoning',    'Reasoning error',          'My logic slipped'],
  ['careless',     'Careless',                 'I knew it and misread'],
  ['retrieval',    'Retrieval failure',        "I knew it but couldn't get to it"],
];
const DAY = 864e5;

/* ---------------------------------------------------------- state */
const KEY = 'dclinpsy.trainer.v1';
let S;

function blankState() {
  // light-first, but honour a viewer whose OS is set to dark on a genuinely first run
  const prefersDark = typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: dark)').matches;
  return { v:1, created: Date.now(), interviewDate:null, theme: prefersDark ? 'dark' : 'light', sound:false,
           c:{}, i:{}, cal:[], errors:[], log:[], wins:[], written:{}, panel:{}, rp:{}, formul:{},
           streak:{last:null,n:0}, seenIntro:false, coached:{}, lastMode:'today' };
}
function load() {
  try {
    const raw = localStorage.getItem(KEY);
    S = raw ? Object.assign(blankState(), JSON.parse(raw)) : blankState();
  } catch (e) { S = blankState(); }
}
/* Persistence.

   This used to swallow every write error, so a learner in a private window or
   with a full quota would work for an hour watching progress accumulate on
   screen that was never being stored. A failed write is now surfaced once and
   stays surfaced, because the only recovery is to export.

   The debounce is also flushed when the page is hidden — closing the tab
   within 220ms of an answer used to lose it. */
let saveTimer = null;
let SAVE_BROKEN = false;

function writeState() {
  clearTimeout(saveTimer); saveTimer = null;
  try {
    localStorage.setItem(KEY, JSON.stringify(S));
    if (SAVE_BROKEN) { SAVE_BROKEN = false; hideSaveWarning(); }
    return true;
  } catch (e) {
    if (!SAVE_BROKEN) { SAVE_BROKEN = true; showSaveWarning(e); }
    return false;
  }
}

function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(writeState, 220);
}

function flushSave() { if (saveTimer) writeState(); }

function showSaveWarning(err) {
  if (typeof document === 'undefined' || $('#savewarn')) return;
  const full = err && (err.name === 'QuotaExceededError' || err.code === 22);
  const bar = el('div', { id:'savewarn', role:'alert' });
  bar.innerHTML = `<b>Your progress is not being saved.</b> ` +
    (full ? 'This browser\u2019s storage for the page is full.'
          : 'This browser is blocking local storage \u2014 private windows often do.') +
    ` Answers you give now will be lost when you close the tab.`;
  const b = el('button', { class:'btn sm', text:'Export what you have',
                           onclick: () => { try { exportProgress(); } catch (e) {} } });
  bar.appendChild(b);
  document.body.appendChild(bar);
}
function hideSaveWarning() { const b = $('#savewarn'); if (b) b.remove(); }

/* ---------------------------------------------------------- indexes */
const CONCEPT = {}, ITEM = {};
function buildIndex() {
  DATA.concepts.nodes.forEach(n => CONCEPT[n.id] = n);
  DATA.items.items.forEach(it => ITEM[it.id] = it);
}
function conceptsOf(domain) { return DATA.concepts.nodes.filter(n => n.domain === domain); }

/* ---------------------------------------------------------- mastery */
function cRec(id) {
  if (!S.c[id]) S.c[id] = { d:0, s:1, t:0, n:0, r:0, w:0, hcw:0, cal:[] };
  return S.c[id];
}
function retriev(rec, now) {
  if (!rec.t || !rec.n) return 0;
  const days = (now - rec.t) / DAY;
  return Math.pow(0.9, days / Math.max(0.5, rec.s));
}
function mastery(id, now) {
  const rec = S.c[id];
  if (!rec || !rec.n) return 0;
  const R = retriev(rec, now || Date.now());
  const ceiling = (rec.d / 5) * 100;
  const acc = rec.r + rec.w ? rec.r / (rec.r + rec.w) : 0.5;
  return Math.round(Math.max(0, Math.min(100, ceiling * (0.5 + 0.5 * R) * (0.72 + 0.28 * acc))));
}
function band(pct) { return BANDS.find(b => pct >= b[0] && pct <= b[1]) || BANDS[0]; }

function domainScore(domain, now) {
  const ns = conceptsOf(domain);
  if (!ns.length) return 0;
  // tier-1 concepts weigh triple, tier-2 double — coverage of core before breadth
  let num = 0, den = 0;
  ns.forEach(n => { const w = n.tier === 1 ? 3 : n.tier === 2 ? 2 : 1; num += mastery(n.id, now) * w; den += w; });
  return Math.round(num / den);
}
function readiness(now) {
  now = now || Date.now();
  const r = domainScore('research', now), c = domainScore('clinical', now), p = domainScore('professional', now);
  // the weakest domain drags: selection tests all three, and a candidate is
  // filtered by their weakest panel, not their strongest
  const min = Math.min(r, c, p), mean = (r + c + p) / 3;
  return { research:r, clinical:c, professional:p, overall: Math.round(mean * 0.62 + min * 0.38) };
}

/* ---------------------------------------------------------- scheduling */
function targetRetention() {
  const d = daysToInterview();
  if (d === null) return 1;
  if (d <= 14) return 0.5;   // intervals halve: fluency phase
  if (d <= 45) return 0.7;
  return 1;
}
function daysToInterview() {
  if (!S.interviewDate) return null;
  return Math.ceil((new Date(S.interviewDate).getTime() - Date.now()) / DAY);
}
function iRec(id) {
  if (!S.i[id]) S.i[id] = { s:0.7, t:0, n:0, lapse:0, ok:0 };
  return S.i[id];
}
/* grade: 0 wrong · 1 shaky · 2 right · 3 fluent */
function schedule(rec, grade, hiConfWrong) {
  const now = Date.now();
  const R = rec.t ? Math.pow(0.9, ((now - rec.t) / DAY) / Math.max(0.5, rec.s)) : 0.9;
  if (grade === 0) {
    rec.lapse++;
    // a confident error is the highest-value review in the system: it comes back today
    rec.s = hiConfWrong ? 0.02 : Math.max(0.25, rec.s * 0.32);
  } else {
    // spacing effect: the longer you successfully waited, the more stability you gain
    const gain = (1.15 + 0.5 * grade) * (1 + 0.55 * (1 - R));
    rec.s = Math.min(240, Math.max(0.6, rec.s * gain));
  }
  rec.t = now; rec.n++;
  if (grade > 0) rec.ok++;
  rec.due = now + rec.s * targetRetention() * DAY;
  return rec;
}
function itemDue(id, now) {
  const r = S.i[id];
  if (!r || !r.n) return Infinity;      // unseen handled separately
  return r.due || 0;
}
function priority(item, now) {
  const r = S.i[item.id];
  let p = 0;
  if (!r || !r.n) {
    p = 40;                                    // unseen baseline
  } else {
    const overdueDays = (now - (r.due || now)) / DAY;
    if (overdueDays < 0) return -1;            // not due
    p = 55 + Math.min(45, overdueDays * 9);
    if (r.lapse) p += r.lapse * 12;
  }
  // weight by how weak, and how central, the concepts it touches are
  let boost = 0;
  item.concepts.forEach(cid => {
    const node = CONCEPT[cid]; if (!node) return;
    const m = mastery(cid, now);
    boost += (100 - m) * (node.tier === 1 ? 0.34 : node.tier === 2 ? 0.2 : 0.1);
    const rec = S.c[cid];
    if (rec && rec.hcw) boost += rec.hcw * 14;  // confident errors weigh heavily
  });
  p += boost / Math.max(1, item.concepts.length);
  if (item.level === 'transfer') p += 14;       // transfer is the north star
  if (item.level === 'discriminate') p += 8;
  return p;
}

/* build an interleaved session: never more than two consecutive from a cluster */
function buildSession(n, filterFn) {
  const now = Date.now();
  let pool = DATA.items.items.filter(it => !filterFn || filterFn(it));
  const scored = pool.map(it => ({ it, p: priority(it, now) }))
                     .filter(x => x.p >= 0)
                     .sort((a, b) => b.p - a.p);
  const out = [], recent = [];
  const clusterOf = it => (CONCEPT[it.concepts[0]] || {}).cluster || '?';
  while (out.length < n && scored.length) {
    let idx = scored.findIndex(x => {
      const cl = clusterOf(x.it);
      return !(recent.length >= 2 && recent[recent.length-1] === cl && recent[recent.length-2] === cl);
    });
    if (idx < 0) idx = 0;
    const chosen = scored.splice(idx, 1)[0];
    out.push(chosen.it);
    recent.push(clusterOf(chosen.it));
  }
  return out;
}

/* ---------------------------------------------------------- session plan
   The engine already decides what to practise; this makes that decision
   legible before you commit to it. Nothing here is invented for display —
   it is the same queue buildSession() will hand the drill. */
const CLUSTER_LABEL = {
  bias: 'Bias and confounding', clinical_skills: 'Clinical skills', design: 'Study design',
  edi: 'Equality, diversity and inclusion', epi: 'Epidemiology', ethics: 'Ethics',
  formulation: 'Formulation', inference: 'Statistical inference', measurement: 'Measurement',
  models: 'Therapeutic models', professional: 'Professional issues', qualitative: 'Qualitative methods',
  risk: 'Risk', systems: 'Services and systems', tests: 'Test selection',
};
const REASON_TEXT = {
  confident: 'you were sure and wrong here',
  lapsed:    'you have lost this one before',
  due:       'due for review',
  new:       'not yet seen',
};

function itemReason(item) {
  const r = S.i[item.id];
  if (!r || !r.n) return 'new';
  if (r.lapse) return 'lapsed';
  if (item.concepts.some(cid => (S.c[cid] || {}).hcw)) return 'confident';
  return 'due';
}

function sessionPlan(n) {
  const now = Date.now();
  const items = buildSession(n);
  const by = {};
  items.forEach(it => {
    const node = CONCEPT[it.concepts[0]] || {};
    const key = node.cluster || 'other';
    const g = by[key] || (by[key] = {
      key, label: CLUSTER_LABEL[key] || key, domain: node.domain || 'research',
      n: 0, reasons: {}, weakest: 100 });
    g.n++;
    const r = itemReason(it);
    g.reasons[r] = (g.reasons[r] || 0) + 1;
    it.concepts.forEach(cid => { const m = mastery(cid, now); if (m < g.weakest) g.weakest = m; });
  });
  const groups = Object.values(by).sort((a, b) => b.n - a.n);
  groups.forEach(g => { g.reason = Object.entries(g.reasons).sort((a, b) => b[1] - a[1])[0][0]; });
  return { total: items.length, groups };
}

/* movement over a window, from events that actually happened: depth
   advancements up, recorded errors down. Not a synthetic percentage. */
function recentMovement(days) {
  const cut = Date.now() - (days || 7) * DAY;
  const out = { research: { up:0, dn:0 }, clinical: { up:0, dn:0 }, professional: { up:0, dn:0 } };
  (S.wins || []).forEach(w => {
    const nd = CONCEPT[w.cid];
    if (w.ts >= cut && nd && out[nd.domain]) out[nd.domain].up++;
  });
  (S.errors || []).forEach(e => {
    if ((e.ts || 0) < cut) return;
    const seen = {};
    (e.concepts || []).forEach(cid => {
      const nd = CONCEPT[cid];
      if (nd && out[nd.domain] && !seen[nd.domain]) { seen[nd.domain] = 1; out[nd.domain].dn++; }
    });
  });
  return out;
}

/* ---------------------------------------------------------- recording */
function recordAnswer(item, correct, conf, secs) {
  const now = Date.now();
  const hiConfWrong = !correct && conf >= 4;
  const fast = secs <= (item.time || 60);
  const grade = correct ? (conf >= 4 && fast ? 3 : conf >= 3 ? 2 : 1) : 0;

  schedule(iRec(item.id), grade, hiConfWrong);
  S.i[item.id].ok = correct ? (S.i[item.id].ok || 0) : (S.i[item.id].ok || 0);

  const lvl = LEVEL_N[item.level] || 1;
  item.concepts.forEach(cid => {
    const rec = cRec(cid);
    rec.n++;
    if (correct) {
      rec.r++;
      // depth only advances on a genuine pass at that level — recognition can
      // never register as mastery, however often it is repeated
      if (lvl > rec.d) {
        rec.d = lvl;
        pushWin(cid, item.level);
      }
      schedule(rec, grade, false);
    } else {
      rec.w++;
      if (hiConfWrong) rec.hcw++;
      // a transfer failure costs depth: it means the level was not really held
      if (lvl >= 4 && rec.d >= lvl) rec.d = Math.max(1, rec.d - 1);
      schedule(rec, 0, hiConfWrong);
    }
    rec.cal.push([conf, correct ? 1 : 0]);
    if (rec.cal.length > 40) rec.cal.shift();
  });

  S.cal = S.cal || [];
  S.cal.push([conf, correct ? 1 : 0]);
  if (S.cal.length > 500) S.cal.shift();

  if (!correct) {
    S.errors.unshift({ id:item.id, ts:now, concepts:item.concepts, conf,
                       stem:(item.stem||'').slice(0,150), level:item.level, type:null });
    if (S.errors.length > 400) S.errors.pop();
  }
  touchStreak();
  save();
  return { hiConfWrong, grade };
}

function pushWin(cid, level) {
  const node = CONCEPT[cid]; if (!node) return;
  if (level === 'unseen' || level === 'recognise') return;
  const verb = { recall:'can retrieve', apply:'can apply', discriminate:'can discriminate',
                 transfer:'can transfer to unfamiliar problems' }[level];
  S.wins.unshift({ ts: Date.now(), cid, level, text: `${node.label} — ${verb}` });
  if (S.wins.length > 60) S.wins.pop();
}

function touchStreak() {
  const today = new Date().toDateString();
  if (S.streak.last === today) return;
  const y = new Date(Date.now() - DAY).toDateString();
  S.streak.n = (S.streak.last === y) ? S.streak.n + 1 : 1;
  S.streak.last = today;
}

/* ---------------------------------------------------------- calibration */
function calibration() {
  // Brier-style: mean squared gap between stated confidence (as a probability)
  // and outcome, counted once per ANSWER. Reported 0-100, 100 = perfectly calibrated.
  let n = 0, sum = 0, hcw = 0, lcr = 0;
  (S.cal || []).forEach(([conf, ok]) => {
    const p = (conf - 1) / 4;
    sum += (p - ok) ** 2; n++;
    if (conf >= 4 && !ok) hcw++;
    if (conf <= 2 && ok) lcr++;
  });
  if (!n) return { score:null, n:0, hcw:0, lcr:0 };
  return { score: Math.round((1 - sum / n) * 100), n, hcw, lcr };
}

/* ---------------------------------------------------------- free-text scoring */
function cueHit(text, cue) {
  try {
    if (Array.isArray(cue)) return cue.every(p => new RegExp(p, 'i').test(text));
    return new RegExp(cue, 'i').test(text);
  } catch (e) { return false; }
}
function scoreText(text, rubric, traps) {
  const t = (text || '').replace(/\s+/g, ' ');
  const words = (t.match(/\S+/g) || []).length;
  const hits = {};
  (rubric || []).forEach(r => { hits[r.id] = (r.cues || []).some(c => cueHit(t, c)); });
  // Several traps are negative lookaheads for a missing move. Those match an
  // empty string trivially, so a stub answer would be flagged for everything.
  const fired = words >= 20 ? (traps || []).filter(tr => (tr.cues || []).some(c => cueHit(t, c))) : [];
  return { hits, traps: fired, words };
}
function rubricTotals(rubric, awarded) {
  let got = 0, max = 0;
  (rubric || []).forEach(r => { max += r.weight; if (awarded[r.id]) got += r.weight; });
  return { got, max };
}

/* ---------------------------------------------------------- misconception graph */
/* When several errors point at children of one node, teach the parent instead
   of five isolated facts. */
function misconceptionClusters(limit) {
  const count = {};
  S.errors.slice(0, 90).forEach(e => (e.concepts || []).forEach(cid => {
    const node = CONCEPT[cid]; if (!node) return;
    count[cid] = (count[cid] || 0) + 1;
    (node.parents || []).forEach(p => { count[p] = (count[p] || 0) + 0.75; });
  }));
  return Object.entries(count)
    .map(([cid, n]) => ({ cid, n, node: CONCEPT[cid], m: mastery(cid) }))
    .filter(x => x.node && x.n >= 1.5)
    .sort((a, b) => (b.n * (100 - b.m)) - (a.n * (100 - a.m)))
    .slice(0, limit || 6);
}

/* ---------------------------------------------------------- gaps & queue */
function weakConcepts(limit, domain) {
  const now = Date.now();
  return DATA.concepts.nodes
    .filter(n => (!domain || n.domain === domain))
    .map(n => ({ n, m: mastery(n.id, now), rec: S.c[n.id] }))
    .filter(x => x.rec && x.rec.n)
    .sort((a, b) => (a.m - b.m) || (b.rec.hcw - a.rec.hcw))
    .slice(0, limit || 8);
}
function dueCount() {
  const now = Date.now();
  return DATA.items.items.filter(it => { const r = S.i[it.id]; return r && r.n && (r.due || 0) <= now; }).length;
}
function unseenCount() {
  return DATA.items.items.filter(it => !S.i[it.id] || !S.i[it.id].n).length;
}

/* ---------------------------------------------------------- misc utils */
const $ = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
function el(tag, attrs, kids) {
  const e = document.createElement(tag);
  if (attrs) for (const k in attrs) {
    if (k === 'class') e.className = attrs[k];
    else if (k === 'html') e.innerHTML = attrs[k];
    else if (k === 'text') e.textContent = attrs[k];
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), attrs[k]);
    else if (attrs[k] !== null && attrs[k] !== undefined) e.setAttribute(k, attrs[k]);
  }
  (kids || []).forEach(k => k && e.appendChild(typeof k === 'string' ? document.createTextNode(k) : k));
  return e;
}
function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function fmtTime(sec) {
  sec = Math.max(0, Math.round(sec));
  return Math.floor(sec / 60) + ':' + String(sec % 60).padStart(2, '0');
}
function relTime(ts) {
  const d = Math.floor((Date.now() - ts) / DAY);
  if (d <= 0) return 'today';
  if (d === 1) return 'yesterday';
  if (d < 7) return d + ' days ago';
  if (d < 30) return Math.floor(d / 7) + 'w ago';
  return Math.floor(d / 30) + 'mo ago';
}
function shuffle(a) { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
function pick(a) { return a[Math.floor(Math.random() * a.length)]; }

/* One polite announcer for the whole app. The action bar used to be a live
   region in its entirety, so every re-render read out the confidence pips,
   the button label and the full teaching text. This says one sentence. */
function announce(msg) {
  const a = $('#announcer');
  if (!a) return;
  a.textContent = '';
  setTimeout(() => { a.textContent = msg; }, 40);
}

function toast(msg, ms) {
  announce(msg);
  const t = el('div', { class:'toast', text: msg });
  $('#toasts').appendChild(t);
  setTimeout(() => { t.style.transition = 'opacity .3s, transform .3s'; t.style.opacity = '0'; t.style.transform = 'translateY(8px)'; setTimeout(() => t.remove(), 320); }, ms || 2600);
}

/* a single quiet tick — used only by the interview countdown, off by default */
let AC = null;
function tick(freq, dur, vol) {
  if (!S.sound) return;
  try {
    AC = AC || new (window.AudioContext || window.webkitAudioContext)();
    const o = AC.createOscillator(), g = AC.createGain();
    o.type = 'sine'; o.frequency.value = freq;
    g.gain.setValueAtTime(0, AC.currentTime);
    g.gain.linearRampToValueAtTime(vol || 0.05, AC.currentTime + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, AC.currentTime + (dur || 0.09));
    o.connect(g); g.connect(AC.destination); o.start(); o.stop(AC.currentTime + (dur || 0.09));
  } catch (e) {}
}
