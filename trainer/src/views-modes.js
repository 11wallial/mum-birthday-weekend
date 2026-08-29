/* ============================================================
   VIEWS — Bench, Panel, Studio, Room, Atlas, Ledger
   ============================================================ */

/* ---------------------------------------------------------- BENCH (written papers) */
let EXAM = null;

function vBench(stage, exId) {
  if (EXAM && EXAM.phase !== 'done') return benchRun(stage);
  if (exId) return benchStart(stage, exId);
  const w = el('div', { class:'wrap stg' });
  w.appendChild(pageHead(null, 'The Bench',
    "Real written papers, run to their real clock. When the time is up the paper closes, exactly as it does on the day. Afterwards your text is matched against the marking scheme point by point — and you confirm or override every award, because comparing your own answer to a marker's list is where most of the learning is.", true));
  const sec = section('Papers', { note:'timed, then marked against the scheme' });
  sec.appendChild(plate(DATA.written.exercises.map(ex => {
    const prev = S.written[ex.id];
    return prow({
      name: ex.title,
      sub: `${ex.course} ${ex.year} · ${ex.minutes} min · ${ex.questions.length} question${ex.questions.length===1?'':'s'} · ${ex.totalMarks} marks`,
      tail: prev ? el('span', { class:'meta', html:`last <b>${prev.score}/${prev.max}</b>` }) : null,
      onclick: () => benchStart(stage, ex.id) });
  })));
  w.appendChild(sec);
  stage.appendChild(w);
}

function benchStart(stage, exId) {
  const ex = DATA.written.exercises.find(e => e.id === exId);
  EXAM = { ex, phase:'brief', answers:{}, awarded:{}, started:0, qi:0 };
  benchRun(stage);
}

function benchRun(stage) {
  stage.innerHTML = '';
  const ex = EXAM.ex;
  if (EXAM.phase === 'brief') {
    const w = el('div', { class:'wrap stg' });
    w.appendChild(el('div', { class:'lbl', text: ex.course + ' · ' + ex.year }));
    w.appendChild(el('h1', { style:'margin:6px 0 14px', text: ex.title }));
    w.appendChild(el('p', { class:'serif', style:'color:var(--ink-2);margin-bottom:18px', text: ex.brief }));
    const p = el('div', { class:'card', style:'margin-bottom:20px' });
    p.innerHTML = `<div class="lbl">Provenance</div><p class="src" style="margin-top:7px;font-style:normal">${esc(ex.provenance)}</p>`;
    w.appendChild(p);
    const warn = el('div', { class:'card', style:'margin-bottom:22px;border-color:color-mix(in srgb,var(--warning) 30%,transparent)' });
    warn.innerHTML = `<div class="lbl" style="color:var(--warning)">${ex.minutes} minutes, then it closes</div>
      <p style="margin-top:7px;font-size:13.5px;color:var(--ink-2)">Do it under the clock or the practice is worth much less. You can move between questions freely. There is no spellcheck in the real Birmingham test, and presentation is marked.</p>`;
    w.appendChild(warn);
    w.appendChild(el('div', { style:'display:flex;gap:10px;flex-wrap:wrap' }, [
      el('button', { class:'btn pri lg', text:'Begin — start the clock', onclick: () => { EXAM.phase='run'; EXAM.started=Date.now(); go('bench'); } }),
      el('button', { class:'btn lg', text:'Untimed', onclick: () => { EXAM.phase='run'; EXAM.started=Date.now(); EXAM.untimed=true; go('bench'); } }),
      el('button', { class:'btn ghost lg', text:'Back', onclick: () => { EXAM=null; go('bench'); } }),
    ]));
    stage.appendChild(w);
    return;
  }

  if (EXAM.phase === 'run') {
    focusMode(true);
    const bar = el('div', { id:'exambar' });
    const inner = el('div', { style:'max-width:812px;margin:0 auto;display:flex;align-items:center;gap:16px;flex-wrap:wrap' });
    const tEl = el('div', { class:'timer', text: fmtTime(ex.minutes * 60) });
    inner.appendChild(tEl);
    inner.appendChild(el('div', { class:'lbl', text: EXAM.untimed ? 'untimed' : 'remaining' }));
    inner.appendChild(el('div', { class:'spacer', style:'flex:1' }));
    inner.appendChild(el('button', { class:'btn', text:'Finish & mark', onclick: benchFinish }));
    bar.appendChild(inner);
    const tb = el('div', { class:'timerbar', style:'margin-top:10px;max-width:812px;margin-left:auto;margin-right:auto' });
    tb.innerHTML = '<i></i>';
    bar.appendChild(tb);
    stage.appendChild(bar);

    if (!EXAM.untimed) {
      const total = ex.minutes * 60;
      const iv = setInterval(() => {
        const left = total - (Date.now() - EXAM.started) / 1000;
        tEl.textContent = fmtTime(left);
        $('i', tb).style.width = Math.max(0, left / total * 100) + '%';
        const cls = left < 60 ? 'out' : left < 300 ? 'warn' : '';
        tEl.className = 'timer ' + cls; tb.className = 'timerbar ' + cls;
        if (left <= 0) { clearInterval(iv); toast('Time. Paper closed.'); benchFinish(); }
      }, 500);
      TIMERS.push(iv);
    }

    const w = el('div', { class:'wrap' });
    // stimulus
    const paper = el('div', { class:'paper' });
    ex.stimulus.forEach(s => paper.appendChild(renderStim(s)));
    w.appendChild(paper);
    // questions
    ex.questions.forEach((q, i) => {
      const blk = el('div', { style:'margin-bottom:26px' });
      const hd = el('div', { style:'display:flex;justify-content:space-between;gap:14px;align-items:baseline;margin-bottom:8px' });
      hd.innerHTML = `<div class="lbl">Question ${i+1}</div><div class="lbl">${q.marks} marks</div>`;
      blk.appendChild(hd);
      blk.appendChild(el('div', { class:'qstem', style:'font-size:15.5px;margin-bottom:10px', text: q.prompt }));
      const ta = el('textarea', { placeholder:'Write in full sentences.', rows:8 });
      ta.value = EXAM.answers[q.id] || '';
      ta.addEventListener('input', () => { EXAM.answers[q.id] = ta.value; wc.textContent = (ta.value.match(/\S+/g)||[]).length + ' words'; });
      blk.appendChild(ta);
      const wc = el('div', { class:'lbl', style:'margin-top:6px;text-align:right', text: ((EXAM.answers[q.id]||'').match(/\S+/g)||[]).length + ' words' });
      blk.appendChild(wc);
      w.appendChild(blk);
    });
    w.appendChild(el('button', { class:'btn pri lg', style:'margin-top:8px', text:'Finish & mark', onclick: benchFinish }));
    stage.appendChild(w);
    return;
  }

  benchMark(stage);
}

function renderStim(s) {
  if (s.t === 'h') return el('h4', { text: s.v });
  if (s.t === 'note') return el('p', { class:'note', text: s.v });
  if (s.t === 'table') {
    const wrap = el('div', { class:'tblwrap' });
    const t = el('table', { class:'dt' });
    if (s.caption) t.appendChild(el('caption', { text: s.caption }));
    const th = el('thead'), tr = el('tr');
    s.head.forEach(h => tr.appendChild(el('th', { text: h })));
    th.appendChild(tr); t.appendChild(th);
    const tb = el('tbody');
    s.rows.forEach(r => { const x = el('tr'); r.forEach(c => x.appendChild(el('td', { text: c }))); tb.appendChild(x); });
    t.appendChild(tb); wrap.appendChild(t);
    const out = el('div');
    out.appendChild(wrap);
    if (s.note) out.appendChild(el('p', { class:'note', style:'margin-top:-8px', text: s.note }));
    return out;
  }
  return el('p', { text: s.v });
}

function benchFinish() {
  clearTimers();
  EXAM.elapsed = (Date.now() - EXAM.started) / 1000;
  EXAM.phase = 'mark';
  // auto-detect against every rubric point, then let the learner adjudicate
  EXAM.ex.questions.forEach(q => {
    const res = scoreText(EXAM.answers[q.id] || '', q.rubric, q.traps);
    EXAM.awarded[q.id] = res.hits;
    EXAM.trapsFired = EXAM.trapsFired || {};
    EXAM.trapsFired[q.id] = res.traps;
  });
  go('bench');
}

function benchMark(stage) {
  const ex = EXAM.ex;
  focusMode(false);
  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('div', { class:'lbl', text: ex.course + ' · ' + ex.year }));
  w.appendChild(el('h1', { style:'margin:6px 0 4px', text:'Marking' }));

  const scoreLine = el('div', { class:'card', style:'margin:18px 0 24px' });
  w.appendChild(scoreLine);
  const note = el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:22px;max-width:70ch' });
  note.innerHTML = 'Ticks were placed automatically by matching your text against each rubric point. <b>The matcher is literal and you are not.</b> Read each point, and click the tick to award or remove it yourself — that adjudication is the exercise. Points you made in different words still count.';
  w.appendChild(note);

  function recompute() {
    let got = 0, max = 0;
    ex.questions.forEach(q => { const t = rubricTotals(q.rubric, EXAM.awarded[q.id] || {}); got += t.got; max += t.max; });
    const pct = max ? Math.round(got / max * 100) : 0;
    scoreLine.innerHTML = `<div style="display:flex;gap:26px;align-items:flex-end;flex-wrap:wrap">
      <div><div class="lbl">Score</div><div class="dnum" style="font-size:40px;line-height:1">${got}<span style="font-size:19px;color:var(--ink-3)">/${max}</span></div></div>
      <div><div class="lbl">Percentage</div><div class="dnum" style="font-size:40px;line-height:1;color:${band(pct)[3]}">${pct}%</div></div>
      <div><div class="lbl">Time taken</div><div class="dnum" style="font-size:22px;line-height:1.6">${fmtTime(EXAM.elapsed)}</div></div>
      <div style="flex:1 1 160px"><div class="lbl">${band(pct)[2]}</div>
        <div class="meter" style="margin-top:7px"><i style="width:${pct}%;background:${band(pct)[3]}"></i></div></div>
    </div>`;
    S.written[ex.id] = { ts: Date.now(), score: got, max, pct, elapsed: EXAM.elapsed };
    save();
  }

  ex.questions.forEach((q, i) => {
    const blk = el('div', { style:'margin-bottom:34px' });
    const hd = el('div', { style:'display:flex;justify-content:space-between;gap:14px;align-items:baseline;margin-bottom:8px' });
    const t = rubricTotals(q.rubric, EXAM.awarded[q.id] || {});
    hd.innerHTML = `<div class="lbl">Question ${i+1}</div><div class="lbl" id="qs${i}">${t.got} / ${t.max}</div>`;
    blk.appendChild(hd);
    blk.appendChild(el('div', { class:'qstem', style:'font-size:15px;margin-bottom:12px', text: q.prompt }));

    const yours = el('details', { class:'disc' });
    yours.innerHTML = `<summary>Your answer (${((EXAM.answers[q.id]||'').match(/\S+/g)||[]).length} words)</summary>`;
    const yc = el('div', { class:'dc' });
    yc.appendChild(el('p', { class:'serif', style:'white-space:pre-wrap;color:var(--ink-2)',
      text: EXAM.answers[q.id] || '(nothing written)' }));
    yours.appendChild(yc);
    blk.appendChild(yours);

    if (q.guidance) {
      const g = el('div', { class:'card', style:'margin-top:10px' });
      g.innerHTML = `<div class="lbl">What this question is actually testing</div><p style="margin-top:6px;font-size:13.5px;color:var(--ink-2)">${esc(q.guidance)}</p>`;
      blk.appendChild(g);
    }

    (EXAM.trapsFired[q.id] || []).forEach(tr => {
      const t2 = el('div', { class:'flag' });
      t2.innerHTML = `<div class="lbl">Flagged in your answer</div>${esc(tr.msg)}`;
      blk.appendChild(t2);
    });

    const rub = el('div', { class:'rub' });
    q.rubric.forEach(r => {
      const on = !!(EXAM.awarded[q.id] || {})[r.id];
      const row = el('div', { class:'rubpt' + (on ? ' hit' : '') + (r.tier === 'advanced' ? ' adv' : '') });
      const tick = el('button', { class:'tick', text:'✓', title:'Award or remove this point' });
      tick.addEventListener('click', () => {
        EXAM.awarded[q.id][r.id] = !EXAM.awarded[q.id][r.id];
        row.classList.toggle('hit', EXAM.awarded[q.id][r.id]);
        const tt = rubricTotals(q.rubric, EXAM.awarded[q.id]);
        $('#qs' + i).textContent = tt.got + ' / ' + tt.max;
        recompute();
      });
      row.append(tick, el('span', { class:'tx', text: r.text }), el('span', { class:'wt', text: r.weight }));
      rub.appendChild(row);
    });
    blk.appendChild(rub);

    const model = el('details', { class:'disc' });
    model.innerHTML = `<summary>A strong answer</summary>`;
    const mc = el('div', { class:'dc' });
    mc.appendChild(el('p', { class:'serif', style:'white-space:pre-wrap', text: q.model }));
    model.appendChild(mc);
    blk.appendChild(model);
    w.appendChild(blk);
  });

  if (ex.debrief) {
    const d = el('div', { class:'card', style:'margin-bottom:20px;border-color:color-mix(in srgb,var(--accent) 36%,transparent)' });
    d.innerHTML = `<div class="lbl" style="color:var(--accent)">What this paper is really testing</div>
      <p style="margin-top:8px;font-size:14px">${esc(ex.debrief)}</p>`;
    w.appendChild(d);
  }
  w.appendChild(el('div', { style:'display:flex;gap:10px;flex-wrap:wrap' }, [
    el('button', { class:'btn pri', text:'Back to the Bench', onclick: () => { EXAM = null; go('bench'); } }),
    el('button', { class:'btn', text:'Retake this paper', onclick: () => benchStart(stage, ex.id) }),
  ]));
  stage.appendChild(w);
  recompute();
}

/* ---------------------------------------------------------- PANEL (interview) */
let PANEL = null;

function vPanel(stage, arg) {
  if (PANEL) return panelRun(stage);
  const w = el('div', { class:'wrap stg' });
  w.appendChild(pageHead(null, 'The Panel',
    'Every question here was actually asked. Answer out loud, against the clock. Afterwards you get what the panel is listening for, the follow-up they push with, and the failure mode most candidates fall into.', true));

  const filt = section('Run a set', { note:'answered aloud, timed' });
  const btns = el('div', { style:'display:flex;gap:8px;flex-wrap:wrap' });
  [['Mixed panel — 5 questions', () => startPanel(shuffle(DATA.interview.questions).slice(0, 5))],
   ['Clinical panel', () => startPanel(shuffle(DATA.interview.questions.filter(q => q.panel === 'clinical')).slice(0, 5))],
   ['Academic panel', () => startPanel(shuffle(DATA.interview.questions.filter(q => q.panel === 'academic')).slice(0, 5))],
   ['Personal / professional', () => startPanel(shuffle(DATA.interview.questions.filter(q => q.panel === 'personal')).slice(0, 5))],
   ['Cardiff only', () => startPanel(shuffle(DATA.interview.questions.filter(q => q.course === 'Cardiff')).slice(0, 6))],
   ['Rapid fire — 60 seconds each', () => startPanel(shuffle(DATA.interview.questions).slice(0, 8), '60s')],
  ].forEach(([nm, fn], i) => btns.appendChild(el('button', { class:'btn' + (i ? '' : ' pri'), text:nm, onclick:fn })));
  filt.appendChild(btns);
  w.appendChild(filt);

  const bt = section('By theme', { note:'what each one is really testing' });
  const themeCount = {};
  DATA.interview.questions.forEach(q => themeCount[q.theme] = (themeCount[q.theme] || 0) + 1);
  bt.appendChild(plate(DATA.interview.themes.slice()
    .sort((a,b) => (themeCount[b.id]||0) - (themeCount[a.id]||0))
    .map(t => prow({
      name: t.label,
      sub: t.why.slice(0, 150) + (t.why.length > 150 ? '…' : ''),
      tail: el('span', { class:'meta', text: (themeCount[t.id]||0) + ' q' }),
      onclick: () => showTheme(t.id) }))));
  w.appendChild(bt);
  stage.appendChild(w);
}

function startPanel(qs, forceMode) {
  if (!qs.length) { toast('No questions match'); return; }
  PANEL = { qs, idx:0, forceMode, results:[] };
  go('panel');
}

function panelRun(stage) {
  if (PANEL.idx >= PANEL.qs.length) return panelSummary(stage);
  focusMode(true);
  const q = PANEL.qs[PANEL.idx];
  const theme = DATA.interview.themes.find(t => t.id === q.theme);
  const mode = PANEL.forceMode || q.mode;
  const secs = mode === '60s' ? 60 : 180;

  const bar = el('div', { id:'sessbar' });
  bar.innerHTML = `<button class="x" title="Leave">✕</button>
    <div class="track"><i></i></div>
    <span class="lbl" style="flex:none">${PANEL.idx + 1}/${PANEL.qs.length}</span>`;
  $('.x', bar).addEventListener('click', () => { PANEL = null; go('panel'); });
  stage.appendChild(bar);
  requestAnimationFrame(() => { $('.track i', bar).style.width = (PANEL.idx / PANEL.qs.length * 100) + '%'; });

  const w = el('div', { class:'wrap centred' });
  const tags = el('div', { class:'tagrow', style:'margin-bottom:20px' });
  tags.innerHTML = `<span class="pill on">${esc(q.course)} ${q.year}</span>
    <span class="pill">${esc(q.panel)}</span>
    <span class="pill">${mode === '60s' ? '60 seconds' : '3 minutes'}</span>`;
  w.appendChild(tags);

  // the question is the hero: this is somebody asking you something
  const ask = el('div', { class:'askq' });
  ask.innerHTML = `<span class="q">“</span><p>${esc(q.text)}</p>`;
  w.appendChild(ask);

  const clock = el('div', { class:'clockwrap' });
  const tEl = el('div', { class:'timer bigclock', text: fmtTime(secs) });
  clock.appendChild(tEl);
  const tb = el('div', { class:'timerbar', style:'margin-top:14px' });
  tb.innerHTML = '<i></i>';
  clock.appendChild(tb);
  clock.appendChild(el('p', { class:'src', style:'margin-top:12px;text-align:center',
    text:'Answer out loud. Reading a good answer is not the same skill as producing one under a clock.' }));
  w.appendChild(clock);

  const trBox = el('div', { class:'card', style:'margin-top:18px;display:none' });
  trBox.innerHTML = `<div class="lbl">Live transcript</div>`;
  const trText = el('p', { class:'serif', style:'margin-top:8px;color:var(--ink-2);min-height:2em' });
  trBox.appendChild(trText);
  w.appendChild(trBox);
  stage.appendChild(w);

  let running = false, left = secs, iv = null;
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  let rec = null, transcript = '';

  const startBtn = el('button', { class:'btn pri lg', text:'Start' });
  const doneBtn  = el('button', { class:'btn lg', text:'Finished', disabled:'' });
  const micBtn = SR ? el('button', { class:'btn sm ghost', html: icon('panel', 15) + ' Transcribe' }) : null;
  if (micBtn) micBtn.addEventListener('click', () => {
    try {
      rec = new SR(); rec.continuous = true; rec.interimResults = true; rec.lang = 'en-GB';
      rec.onresult = e => {
        let t = '';
        for (let i = 0; i < e.results.length; i++) t += e.results[i][0].transcript + ' ';
        transcript = t; trText.textContent = t;
      };
      rec.onerror = () => toast('Transcription unavailable — self-scoring still works');
      rec.start(); trBox.style.display = 'block'; micBtn.remove();
      toast('Listening. Your speech stays in this browser.');
    } catch (err) { toast('Transcription unavailable in this browser'); }
  });
  Act.row([micBtn], [doneBtn, startBtn]);

  startBtn.addEventListener('click', () => {
    if (running) return;
    running = true; startBtn.disabled = true; doneBtn.disabled = false;
    iv = setInterval(() => {
      left--; tEl.textContent = fmtTime(left);
      $('i', tb).style.width = Math.max(0, left / secs * 100) + '%';
      const cls = left <= 10 ? 'out' : left <= 30 ? 'warn' : '';
      tEl.className = 'timer bigclock ' + cls; tb.className = 'timerbar ' + cls;
      if (left === 30 || left === 10) tick(660, .07, .04);
      if (left <= 0) { clearInterval(iv); tick(420, .3, .06); toast('Time.'); finish(); }
    }, 1000);
    TIMERS.push(iv);
  });
  doneBtn.addEventListener('click', finish);

  function finish() {
    running = false; clearInterval(iv);
    try { if (rec) rec.stop(); } catch (e) {}
    if ($('#panelfb')) return;
    w.classList.remove('centred');   // feedback is long; stop centring
    w.appendChild(panelFeedback(q, theme, secs - left, transcript, () => { PANEL.idx++; go('panel'); }));
    scrollEnd(w);
  }
}

function panelFeedback(q, theme, spent, transcript, onNext) {
  focusMode(false);   // the timed part is over — give the navigation back
  Act.hide();
  const wrap = el('div', { id:'panelfb', style:'margin-top:24px' });
  const auto = transcript ? scoreText(transcript, theme.listen.map((l, i) => ({ id:'l'+i, cues:l.cues, weight:1, text:l.text })), []) : null;
  const awarded = {};
  theme.listen.forEach((l, i) => awarded['l'+i] = auto ? auto.hits['l'+i] : false);

  const head = el('div', { class:'card', style:'margin-bottom:14px' });
  const scoreEl = el('div');
  head.appendChild(scoreEl);
  wrap.appendChild(head);

  const intro = el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:14px' });
  intro.innerHTML = transcript
    ? 'Ticks below were placed by matching your transcript. Adjust any that are wrong — speech recognition is rough and the matcher is literal.'
    : 'Score yourself honestly against what the panel is listening for. Tick only what you actually said out loud.';
  wrap.appendChild(intro);

  const rub = el('div', { class:'rub' });
  theme.listen.forEach((l, i) => {
    const id = 'l' + i;
    const row = el('div', { class:'rubpt' + (awarded[id] ? ' hit' : '') + (l.tier === 'advanced' ? ' adv' : '') });
    const tick2 = el('button', { class:'tick', text:'✓' });
    tick2.addEventListener('click', () => { awarded[id] = !awarded[id]; row.classList.toggle('hit', awarded[id]); recompute(); });
    row.append(tick2, el('span', { class:'tx', text: l.text }));
    rub.appendChild(row);
  });
  wrap.appendChild(rub);

  function recompute() {
    const got = Object.values(awarded).filter(Boolean).length, max = theme.listen.length;
    const pct = Math.round(got / max * 100);
    scoreEl.innerHTML = `<div style="display:flex;gap:24px;align-items:flex-end;flex-wrap:wrap">
      <div><div class="lbl">Moves hit</div><div class="dnum" style="font-size:34px;line-height:1">${got}<span style="font-size:16px;color:var(--ink-3)">/${max}</span></div></div>
      <div><div class="lbl">Time used</div><div class="dnum" style="font-size:20px;line-height:1.7">${fmtTime(spent)}</div></div>
      <div style="flex:1 1 150px"><div class="lbl">${band(pct)[2]}</div>
        <div class="meter" style="margin-top:7px"><i style="width:${pct}%;background:${band(pct)[3]}"></i></div></div></div>`;
    S.panel[q.id] = { ts: Date.now(), got, max, spent }; save();
  }
  recompute();

  if (transcript) {
    const d = el('details', { class:'disc' });
    d.innerHTML = '<summary>Your transcript</summary>';
    const dc = el('div', { class:'dc' });
    dc.appendChild(el('p', { class:'serif', style:'color:var(--ink-2)', text: transcript }));
    d.appendChild(dc); wrap.appendChild(d);
  }

  const shape = el('div', { class:'card', style:'margin-top:14px;border-color:color-mix(in srgb,var(--accent) 34%,transparent)' });
  shape.innerHTML = `<div class="lbl" style="color:var(--accent)">The shape of a strong answer</div>
    <p style="margin-top:8px;font-size:14px">${esc(theme.shape)}</p>`;
  wrap.appendChild(shape);

  const fail = el('div', { class:'flag', style:'margin-top:12px' });
  fail.innerHTML = `<div class="lbl">The common failure</div>${esc(theme.failure)}`;
  wrap.appendChild(fail);

  const fu = el('div', { class:'card', style:'margin-top:12px' });
  fu.innerHTML = `<div class="lbl">They will push with</div>`;
  const list = el('div', { style:'margin-top:9px;display:grid;gap:7px' });
  shuffle(theme.followups).slice(0, 4).forEach(f => list.appendChild(
    el('p', { class:'serif', style:'margin:0;font-size:15px', text: '“' + f + '”' })));
  fu.appendChild(list);
  const pressBtn = el('button', { class:'btn', style:'margin-top:13px', text:'Answer one now — 60 seconds' });
  pressBtn.addEventListener('click', () => {
    pressBtn.disabled = true;
    const f = pick(theme.followups);
    const box = el('div', { class:'card', style:'margin-top:12px;border-color:var(--warning)' });
    const t = el('div', { class:'timer', style:'font-size:30px' , text:'1:00' });
    box.innerHTML = `<div class="lbl" style="color:var(--warning)">Pressure follow-up</div>
      <p class="serif" style="font-size:17px;margin:8px 0 12px">“${esc(f)}”</p>`;
    box.appendChild(t);
    fu.appendChild(box);
    let l = 60;
    const iv = setInterval(() => { l--; t.textContent = fmtTime(l); if (l <= 0) { clearInterval(iv); t.className = 'timer out'; tick(420,.3,.06); } }, 1000);
    TIMERS.push(iv);
    scrollEnd(wrap);
  });
  fu.appendChild(pressBtn);
  wrap.appendChild(fu);

  wrap.appendChild(el('button', { class:'btn pri lg wide', style:'margin-top:20px',
    text: 'Next question', onclick: onNext }));
  return wrap;
}

function panelSummary(stage) {
  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('h1', { text:'Panel complete' }));
  w.appendChild(el('p', { style:'color:var(--ink-2);margin:8px 0 22px',
    text:'Answering aloud is the whole point — reading a good answer is not the same skill as producing one under a clock with three people watching.' }));
  w.appendChild(el('div', { style:'display:flex;gap:10px;flex-wrap:wrap' }, [
    el('button', { class:'btn pri', text:'Another set', onclick: () => { PANEL = null; go('panel'); } }),
    el('button', { class:'btn', text:'Back to Today', onclick: () => { PANEL = null; go('today'); } }),
  ]));
  stage.appendChild(w);
  PANEL = null;
}

function showTheme(id) {
  const t = DATA.interview.themes.find(x => x.id === id);
  const qs = DATA.interview.questions.filter(q => q.theme === id);
  const body = el('div');
  body.appendChild(el('p', { style:'color:var(--ink-2);font-size:13.5px;margin-bottom:16px', text: t.why }));
  body.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text:'What the panel is listening for' }));
  const rub = el('div', { class:'rub', style:'margin-bottom:18px' });
  t.listen.forEach(l => {
    const r = el('div', { class:'rubpt' + (l.tier === 'advanced' ? ' adv' : '') });
    r.append(el('span', { class:'tick', style:'cursor:default' }), el('span', { class:'tx', text: l.text }));
    rub.appendChild(r);
  });
  body.appendChild(rub);
  const sh = el('div', { class:'card', style:'margin-bottom:12px' });
  sh.innerHTML = `<div class="lbl" style="color:var(--accent)">The shape of a strong answer</div><p style="margin-top:7px;font-size:13.5px">${esc(t.shape)}</p>`;
  body.appendChild(sh);
  const fl = el('div', { class:'flag', style:'margin-bottom:16px' });
  fl.innerHTML = `<div class="lbl">The common failure</div>${esc(t.failure)}`;
  body.appendChild(fl);
  body.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text: qs.length + ' real questions in this theme' }));
  qs.forEach(q => {
    const r = el('div', { class:'listrow', style:'align-items:flex-start' }, [
      el('span', { class:'nm', style:'white-space:normal;color:var(--ink)', text: q.text }),
      el('span', { class:'vv', text: q.course.split(' ')[0] + ' ' + q.year }),
    ]);
    body.appendChild(r);
  });
  const run = el('button', { class:'btn pri lg', style:'margin-top:18px', text:'Practise this theme — 4 questions',
    onclick: () => { closeModal(); startPanel(shuffle(qs).slice(0, 4)); } });
  body.appendChild(run);
  openModal(t.label, body);
}

/* ---------------------------------------------------------- STUDIO (formulation) */
function vStudio(stage, vid) {
  if (vid) return studioCase(stage, vid);
  const w = el('div', { class:'wrap stg' });
  w.appendChild(pageHead(null, 'The Studio',
    'One case, several lenses. You write your own formulation first, then compare it against an account from each model — including what that model illuminates, what it misses, and how you would know it was wrong. This is the question Birmingham used to catch a whole cohort out: name a model, and then be told to formulate with a different one.', true));
  const sc = section('Cases', { note:'write yours first, then compare' });
  sc.appendChild(plate(DATA.formulation.vignettes.map(v => prow({
    name: v.title,
    sub: v.models.map(m => m.model).join(' · '),
    tail: S.formul[v.id] ? el('span', { class:'pill on', text:'attempted' }) : null,
    onclick: () => studioCase(stage, v.id) }))));
  w.appendChild(sc);
  stage.appendChild(w);
}

function studioCase(stage, vid) {
  const v = DATA.formulation.vignettes.find(x => x.id === vid);
  stage.innerHTML = '';
  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('button', { class:'btn ghost', style:'margin-bottom:16px', text:'← All cases', onclick: () => go('studio') }));
  w.appendChild(el('h1', { text: v.title }));
  w.appendChild(el('p', { class:'src', style:'margin:6px 0 18px', text: v.source }));

  const paper = el('div', { class:'paper' });
  paper.appendChild(el('p', { text: v.text }));
  w.appendChild(paper);

  const ask = el('div', { class:'card', style:'margin-bottom:20px;border-color:color-mix(in srgb,var(--accent) 34%,transparent)' });
  ask.innerHTML = `<div class="lbl" style="color:var(--accent)">The question</div><p style="margin-top:7px;font-size:15px">${esc(v.ask)}</p>`;
  w.appendChild(ask);

  const yourBox = el('div', { style:'margin-bottom:26px' });
  yourBox.appendChild(el('div', { class:'lbl', style:'margin-bottom:8px', text:'Write your formulation first — then reveal' }));
  const ta = el('textarea', { rows:7, placeholder:'What is happening, on what account, and what would follow from it?' });
  ta.value = (S.formul[v.id] || {}).text || '';
  ta.addEventListener('input', () => { S.formul[v.id] = Object.assign(S.formul[v.id] || {}, { text: ta.value, ts: Date.now() }); save(); });
  yourBox.appendChild(ta);
  w.appendChild(yourBox);

  w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'The lenses' })]));
  v.models.forEach(m => {
    const d = el('details', { class:'disc', style:'margin-bottom:10px' });
    d.innerHTML = `<summary><b style="font-weight:600;color:var(--ink)">${esc(m.model)}</b></summary>`;
    const dc = el('div', { class:'dc' });
    const rows = [
      ['Core mechanism', m.mech, 'var(--accent)'],
      ['The formulation', m.form, null],
      ['What this lens adds', m.adds, 'var(--good)'],
      ['What it overlooks', m.misses, 'var(--serious)'],
      ['The intervention that follows', m.intervention, null],
      ['How you would know it was wrong', m.test, 'var(--warning)'],
    ];
    rows.forEach(([l, txt, col]) => {
      dc.appendChild(el('div', { class:'lbl', style:'margin:14px 0 5px' + (col ? ';color:' + col : ''), text: l }));
      dc.appendChild(el('p', { style:'font-size:13.8px;line-height:1.6;color:var(--ink-2);margin:0', text: txt }));
    });
    d.appendChild(dc);
    w.appendChild(d);
  });

  const cmp = el('div', { class:'card', style:'margin-top:20px;border-color:color-mix(in srgb,var(--accent) 36%,transparent)' });
  cmp.innerHTML = `<div class="lbl" style="color:var(--accent)">Choosing between them</div>
    <p style="margin-top:8px;font-size:14px;line-height:1.62">${esc(v.compare)}</p>`;
  w.appendChild(cmp);

  const drill = el('div', { class:'card', style:'margin-top:16px' });
  drill.innerHTML = `<div class="lbl">Now do it aloud</div>
    <p style="margin-top:7px;font-size:13.5px;color:var(--ink-2)">Pick two of these models. Sixty seconds each: core principle, what maintains the problem on that account, what intervention follows. Then one sentence on what the second lens adds that the first missed.</p>`;
  const go60 = el('button', { class:'btn', style:'margin-top:12px', text:'Start 60-second clock' });
  const t60 = el('div', { class:'timer', style:'margin-left:14px;display:inline-block;vertical-align:middle', text:'1:00' });
  go60.addEventListener('click', () => {
    let l = 60; go60.disabled = true;
    const iv = setInterval(() => { l--; t60.textContent = fmtTime(l);
      t60.className = 'timer ' + (l <= 10 ? 'out' : l <= 20 ? 'warn' : '');
      if (l <= 0) { clearInterval(iv); go60.disabled = false; tick(420,.3,.06); } }, 1000);
    TIMERS.push(iv);
  });
  drill.append(go60, t60);
  w.appendChild(drill);
  stage.appendChild(w);
}

/* ---------------------------------------------------------- ROOM (role-play) */
let RP = null;

function vRoom(stage, sid) {
  if (RP) return roomRun(stage);
  const w = el('div', { class:'wrap stg' });
  w.appendChild(pageHead(null, 'The Room',
    'Branching conversations from the courses that use role-play. You are scored on process, not content: whether you open the space, reflect, validate and stay with the person — or reach for a solution. Glasgow states it outright in their brief: there is no expectation that you resolve the problem.', true));
  const rs = section('Scenarios', { note:'scored on process, not on solving it' });
  rs.appendChild(plate(DATA.roleplay.scenarios.map(sc => {
    const prev = S.rp[sc.id];
    return prow({
      name: sc.title, sub: sc.setting + ' · ' + sc.source,
      tail: prev ? el('span', { class:'meta', html:`best <b>${prev.score}</b>` }) : null,
      onclick: () => { RP = { s: sc, turn:0, score:0, max:0, log:[] }; go('room'); } });
  })));
  w.appendChild(rs);
  stage.appendChild(w);
}

function roomRun(stage) {
  stage.innerHTML = '';
  focusMode(true);
  const s = RP.s;
  const w = el('div', { class:'wrap' });
  w.appendChild(el('button', { class:'btn ghost', style:'margin-bottom:14px', text:'← Leave', onclick: () => { RP = null; go('room'); } }));

  const brief = el('div', { class:'card', style:'margin-bottom:20px' });
  brief.innerHTML = `<div class="lbl">Your brief</div>
    <p style="margin-top:7px;font-size:13.5px;color:var(--ink-2)">${esc(s.brief)}</p>
    <p style="margin-top:9px;font-size:12.5px;color:var(--ink-3)"><b>${esc(s.character)}</b> · ${esc(s.setting)}</p>`;
  w.appendChild(brief);

  const script = el('div');
  w.appendChild(script);

  // opening
  script.appendChild(turnEl('them', s.character.split(',')[0], s.opening));
  RP.log.forEach(entry => {
    script.appendChild(turnEl('you', 'You', entry.said));
    const fb = el('div', { class:'fbnote ' + (entry.s > 0 ? 'pos' : entry.s < 0 ? 'neg' : '') });
    fb.innerHTML = `<b>${entry.s > 0 ? '+' : ''}${entry.s}</b> · ${esc(entry.f)}`;
    script.appendChild(fb);
    if (entry.next) script.appendChild(turnEl('them', s.character.split(',')[0], entry.next));
  });

  if (RP.turn >= s.turns.length) return roomEnd(stage, w, script);

  const t = s.turns[RP.turn];
  if (RP.turn > 0 || RP.log.length === 0) {
    // the character's line for this turn is shown once
  }
  if (RP.log.length === 0) script.appendChild(turnEl('them', s.character.split(',')[0], t.says));
  else if (!RP.log[RP.log.length - 1].next) script.appendChild(turnEl('them', s.character.split(',')[0], t.says));

  const opts = el('div', { class:'choices', style:'margin-top:18px' });
  shuffle(t.options).forEach(o => {
    const b = el('button', { class:'choice' }, [
      el('span', { class:'key', text:'›' }),
      el('span', {}, [el('span', { text: o.t })]),
    ]);
    b.addEventListener('click', () => {
      const nextTurn = s.turns[RP.turn + 1];
      RP.log.push({ said:o.t, s:o.s, f:o.f, d:o.d, next: nextTurn ? nextTurn.says : null });
      RP.score += o.s;
      RP.max += 3;
      RP.turn++;
      go('room');
    });
    opts.appendChild(b);
  });
  w.appendChild(opts);
  stage.appendChild(w);
  requestAnimationFrame(() => scrollEnd(w));
}

function turnEl(who, name, text) {
  const t = el('div', { class:'turn' + (who === 'you' ? ' you' : '') });
  t.innerHTML = `<div class="av">${who === 'you' ? 'You' : name.slice(0,1)}</div>
    <div class="sp"><div class="who">${esc(who === 'you' ? 'You' : name)}</div>
    <div class="tx">${esc(text)}</div></div>`;
  return t;
}

function roomEnd(stage, w, script) {
  focusMode(false);
  const s = RP.s;
  const pct = Math.round(Math.max(0, RP.score) / RP.max * 100);
  const prev = S.rp[s.id];
  if (!prev || RP.score > prev.score) S.rp[s.id] = { ts: Date.now(), score: RP.score, max: RP.max };
  save();

  const dims = {};
  RP.log.forEach(l => dims[l.d] = (dims[l.d] || 0) + 1);
  const res = el('div', { class:'card', style:'margin-top:22px' });
  res.innerHTML = `<div style="display:flex;gap:26px;align-items:flex-end;flex-wrap:wrap">
      <div><div class="lbl">Process score</div><div class="dnum" style="font-size:38px;line-height:1;color:${band(pct)[3]}">${RP.score}<span style="font-size:17px;color:var(--ink-3)">/${RP.max}</span></div></div>
      <div style="flex:1 1 180px"><div class="lbl">${band(pct)[2]}</div>
        <div class="meter" style="margin-top:7px"><i style="width:${pct}%;background:${band(pct)[3]}"></i></div></div>
    </div>`;
  const dimRow = el('div', { class:'tagrow', style:'margin-top:16px' });
  Object.entries(dims).forEach(([d, n]) => dimRow.appendChild(
    el('span', { class:'pill' + (['fix','close','self'].includes(d) ? '' : ' on'),
                 text: (DATA.roleplay.dims[d] || d) + ' ×' + n })));
  res.appendChild(dimRow);
  w.appendChild(res);

  const db = el('div', { class:'card', style:'margin-top:14px;border-color:color-mix(in srgb,var(--accent) 34%,transparent)' });
  db.innerHTML = `<div class="lbl" style="color:var(--accent)">Debrief</div>
    <p style="margin-top:8px;font-size:14px;line-height:1.62">${esc(s.debrief)}</p>`;
  w.appendChild(db);

  w.appendChild(el('div', { style:'display:flex;gap:10px;margin-top:18px;flex-wrap:wrap' }, [
    el('button', { class:'btn pri', text:'Run it again', onclick: () => { RP = { s, turn:0, score:0, max:0, log:[] }; go('room'); } }),
    el('button', { class:'btn', text:'Other scenarios', onclick: () => { RP = null; go('room'); } }),
  ]));
  stage.appendChild(w);
  requestAnimationFrame(() => scrollEnd(w));
}

/* ---------------------------------------------------------- ATLAS */
let ATLAS = null;

function vAtlas(stage, domainFilter) {
  const w = el('div', { class:'wrap wide' });
  w.appendChild(el('h1', { text:'The Atlas' }));
  w.appendChild(el('p', { style:'color:var(--ink-2);margin:8px 0 18px;max-width:70ch',
    text:'Every concept the trainer knows about, and how they connect. A node brightens as you demonstrate depth in it — not as you tick items off. Dim nodes with many links are the ones worth attacking, because strengthening a hub carries its neighbours with it.' }));

  const bar = el('div', { style:'display:flex;gap:8px;align-items:center;margin-bottom:14px;flex-wrap:wrap' });
  const filters = ['all','research','clinical','professional'];
  let active = domainFilter || 'all';
  filters.forEach(f => {
    const b = el('button', { class:'pill' + (f === active ? ' on' : ''), style:'cursor:pointer;padding:6px 12px;font-size:12px' },
      [f !== 'all' ? el('span', { class:'dot ' + f }) : null, el('span', { text: f === 'all' ? 'All domains' : f[0].toUpperCase() + f.slice(1) })]);
    b.addEventListener('click', () => { $$('.pill', bar).forEach(x => x.classList.remove('on')); b.classList.add('on'); active = f; buildAtlas(active); });
    bar.appendChild(b);
  });
  w.appendChild(bar);

  const holder = el('div', { style:'position:relative' });
  const cv = el('canvas', { id:'atlas' });
  holder.appendChild(cv);
  holder.appendChild(el('div', { id:'atlastip' }));
  w.appendChild(holder);

  const legend = el('div', { style:'display:flex;gap:16px;flex-wrap:wrap;margin-top:14px;align-items:center' });
  const swatch = v => ['research','clinical','professional']
    .map(d => `<i style="width:11px;height:11px;border-radius:50%;display:inline-block;
      background:color-mix(in srgb, var(--d-${d}) ${8 + v * 0.92}%, var(--card));
      border:1.5px solid var(--d-${d})"></i>`).join('');
  legend.innerHTML =
    `<span class="lbl">Colour = domain · fill = mastery</span>` +
    [0, 40, 75, 100].map(v => `<span style="display:inline-flex;align-items:center;gap:3px;font-size:11.5px;color:var(--ink-3)">
      ${swatch(v)}<span style="margin-left:4px">${v}</span></span>`).join('') +
    `<span style="font-size:11.5px;color:var(--ink-3);margin-left:auto">Size = how central the concept is · click a node for its exact formulation</span>`;
  w.appendChild(legend);
  stage.appendChild(w);
  buildAtlas(active);
}

function hex2rgb(h) {
  h = (h || '').trim().replace('#','');
  if (h.length === 3) h = h.split('').map(c => c + c).join('');
  const n = parseInt(h || '888888', 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function mixHex(a, b, t) {
  const A = hex2rgb(a), B = hex2rgb(b);
  return `rgb(${Math.round(A[0]+(B[0]-A[0])*t)},${Math.round(A[1]+(B[1]-A[1])*t)},${Math.round(A[2]+(B[2]-A[2])*t)})`;
}
function seqColor(pct) {
  const st = ['--seq-1','--seq-2','--seq-3','--seq-4','--seq-5','--seq-6','--seq-7'];
  if (pct <= 0) return 'var(--bg-2)';
  const i = Math.min(6, Math.floor(pct / 100 * 6.99));
  return getComputedStyle(document.documentElement).getPropertyValue(st[i]).trim() || '#3987e5';
}

function buildAtlas(domain) {
  const cv = $('#atlas'); if (!cv) return;
  const tip = $('#atlastip');
  const nodes = DATA.concepts.nodes.filter(n => domain === 'all' || n.domain === domain);
  const ids = new Set(nodes.map(n => n.id));
  const links = [];
  nodes.forEach(n => {
    (n.parents || []).forEach(p => { if (ids.has(p)) links.push([n.id, p, 1]); });
    (n.related || []).forEach(r => { if (ids.has(r) && n.id < r) links.push([n.id, r, 0.45]); });
  });

  const deg = {};
  links.forEach(([a, b]) => { deg[a] = (deg[a] || 0) + 1; deg[b] = (deg[b] || 0) + 1; });

  const W = cv.clientWidth || 900, H = Math.max(440, Math.min(650, W * 0.52));
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  cv.width = W * dpr; cv.height = H * dpr; cv.style.height = H + 'px';
  const ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

  // Three domain lobes. Separating the domains is not decoration: the whole
  // point of the map is to show which of the three is dark.
  const PAD = 46;
  const doms = ['research','clinical','professional'];
  const present = doms.filter(d => nodes.some(n => n.domain === d));
  const lobe = {};
  present.forEach((d, i) => {
    if (present.length === 1) { lobe[d] = { x: W/2, y: H/2 }; return; }
    const a = -Math.PI/2 + (i / present.length) * Math.PI * 2;
    lobe[d] = { x: W/2 + Math.cos(a) * W * 0.29, y: H/2 + Math.sin(a) * H * 0.27 };
  });

  // deterministic seeded start so the map is stable between visits
  const P = {};
  nodes.forEach(n => {
    let h = 0; for (let k = 0; k < n.id.length; k++) h = (h * 31 + n.id.charCodeAt(k)) | 0;
    const a = (Math.abs(h) % 3600) / 3600 * Math.PI * 2;
    const r = 24 + (Math.abs(h >> 7) % 1000) / 1000 * 110;
    const L = lobe[n.domain] || { x: W/2, y: H/2 };
    P[n.id] = { x: L.x + Math.cos(a) * r, y: L.y + Math.sin(a) * r, vx:0, vy:0 };
  });

  const ITER = 420;
  for (let iter = 0; iter < ITER; iter++) {
    const cool = 1 - iter / ITER;
    for (let i = 0; i < nodes.length; i++) {
      const a = P[nodes[i].id];
      for (let j = i + 1; j < nodes.length; j++) {
        const b = P[nodes[j].id];
        let dx = a.x - b.x, dy = a.y - b.y, d2 = dx*dx + dy*dy;
        if (d2 > 34000 || d2 === 0) continue;
        const d = Math.sqrt(d2), f = 620 / d2;
        const ux = dx / d * f, uy = dy / d * f;
        a.vx += ux; a.vy += uy; b.vx -= ux; b.vy -= uy;
      }
    }
    links.forEach(([x, y, wgt]) => {
      const a = P[x], b = P[y];
      const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 1;
      const f = (d - 72) * 0.014 * wgt;
      const ux = dx / d * f, uy = dy / d * f;
      a.vx += ux; a.vy += uy; b.vx -= ux; b.vy -= uy;
    });
    nodes.forEach(n => {
      const p = P[n.id], L = lobe[n.domain] || { x: W/2, y: H/2 };
      p.vx += (L.x - p.x) * 0.014; p.vy += (L.y - p.y) * 0.014;
      p.x += p.vx * cool; p.y += p.vy * cool;
      p.vx *= 0.76; p.vy *= 0.76;
      p.x = Math.max(PAD, Math.min(W - PAD, p.x));
      p.y = Math.max(PAD, Math.min(H - PAD, p.y));
    });
  }

  const css = getComputedStyle(document.documentElement);
  const domCol = { research: css.getPropertyValue('--d-research').trim(),
                   clinical: css.getPropertyValue('--d-clinical').trim(),
                   professional: css.getPropertyValue('--d-professional').trim() };
  const inkDim = css.getPropertyValue('--ink-3').trim();
  const unseenCol = css.getPropertyValue('--bg-2').trim();
  const surfaceCol = css.getPropertyValue('--card').trim();
  const chipBg = css.getPropertyValue('--card').trim();
  // link ink follows the theme: dark strokes on a light ground, light on dark
  const darkUI = document.documentElement.getAttribute('data-theme') === 'dark';
  const linkRGB = darkUI ? '150,170,210' : '70,90,130';
  const now = Date.now();
  let hover = null, t = 0;

  function radius(n) { return 3.4 + Math.min(7, (deg[n.id] || 0) * 0.62) + (n.tier === 1 ? 2 : n.tier === 2 ? 0.8 : 0); }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    // lobe captions sit above each cluster's real extent, not over its nodes
    present.forEach(d => {
      const pts = nodes.filter(n => n.domain === d).map(n => P[n.id]);
      if (!pts.length) return;
      const cx = pts.reduce((a, q) => a + q.x, 0) / pts.length;
      const top = Math.min.apply(null, pts.map(q => q.y));
      ctx.font = '700 10.5px Inter, system-ui, sans-serif';
      ctx.textAlign = 'center'; ctx.textBaseline = 'alphabetic';
      ctx.fillStyle = domCol[d];
      ctx.globalAlpha = .7;
      if ('letterSpacing' in ctx) ctx.letterSpacing = '1.5px';
      ctx.fillText(d.toUpperCase(), cx, Math.max(15, top - 24));
      if ('letterSpacing' in ctx) ctx.letterSpacing = '0px';
      ctx.globalAlpha = 1;
    });
    ctx.lineWidth = 1;
    links.forEach(([a, b, wgt]) => {
      const pa = P[a], pb = P[b];
      const ma = mastery(a, now), mb = mastery(b, now);
      const lit = (ma + mb) / 200;
      ctx.strokeStyle = `rgba(${linkRGB},${(darkUI ? 0.05 : 0.07) + lit * 0.17})`;
      if (hover && (a === hover || b === hover)) ctx.strokeStyle = `rgba(${linkRGB},.55)`;
      ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.lineTo(pb.x, pb.y); ctx.stroke();
    });
    nodes.forEach(n => {
      const p = P[n.id], m = mastery(n.id, now), r = radius(n);
      const isHover = hover === n.id;
      if (m > 0) {
        const pulse = 1 + Math.sin(t / 30 + p.x) * 0.03 * (m / 100);
        ctx.beginPath(); ctx.arc(p.x, p.y, r * 2.9 * (m / 100) * pulse, 0, 7);
        ctx.fillStyle = domCol[n.domain] + '18'; ctx.fill();
      }
      // One channel per variable: hue carries the domain, intensity carries
      // mastery. A blue mastery ramp inside a blue domain lobe encodes nothing.
      ctx.beginPath(); ctx.arc(p.x, p.y, r * (isHover ? 1.35 : 1), 0, 7);
      ctx.fillStyle = mixHex(surfaceCol, domCol[n.domain], 0.08 + (m / 100) * 0.92);
      ctx.fill();
      ctx.lineWidth = 1.5;
      ctx.strokeStyle = m > 0 ? domCol[n.domain] : mixHex(surfaceCol, domCol[n.domain], 0.34);
      ctx.stroke();
    });
    // labels last, with a coarse occupancy grid so they never pile up
    const CW = 92, CH = 20, taken = new Set();
    const order = nodes.slice().sort((a, b) =>
      (b.id === hover ? 1e6 : 0) - (a.id === hover ? 1e6 : 0) ||
      (a.tier - b.tier) || ((deg[b.id]||0) - (deg[a.id]||0)));
    ctx.textAlign = 'center';
    order.forEach(n => {
      const m = mastery(n.id, now), isHover = hover === n.id;
      if (!(isHover || (n.tier === 1 && (deg[n.id] || 0) >= 3) || m >= 55)) return;
      const p = P[n.id], r = radius(n), ly = p.y - r - 6;
      const gx = Math.round(p.x / CW), gy = Math.round(ly / CH);
      const keys = [gx + ':' + gy, (gx+1) + ':' + gy, (gx-1) + ':' + gy];
      if (!isHover && keys.some(k => taken.has(k))) return;
      keys.forEach(k => taken.add(k));
      const lbl = n.label.length > 20 ? n.label.slice(0, 18) + '…' : n.label;
      ctx.font = (isHover ? '600 ' : '500 ') + '10.5px Inter, sans-serif';
      if (isHover) {
        const wgt = ctx.measureText(lbl).width;
        ctx.fillStyle = chipBg;
        ctx.fillRect(p.x - wgt/2 - 6, ly - 11, wgt + 12, 15);
      }
      ctx.fillStyle = isHover ? css.getPropertyValue('--ink').trim() : inkDim;
      ctx.fillText(lbl, p.x, ly);
    });
    t++;
  }
  draw();
  const iv = setInterval(draw, 70); TIMERS.push(iv);

  function hit(mx, my) {
    let best = null, bd = 16;
    nodes.forEach(n => {
      const p = P[n.id], d = Math.hypot(p.x - mx, p.y - my);
      if (d < Math.max(bd, radius(n) + 6) && d < bd) { bd = d; best = n; }
    });
    return best;
  }
  cv.onmousemove = e => {
    const r = cv.getBoundingClientRect();
    const n = hit(e.clientX - r.left, e.clientY - r.top);
    hover = n ? n.id : null;
    cv.style.cursor = n ? 'pointer' : 'grab';
    if (n) {
      const m = mastery(n.id, now), rec = S.c[n.id];
      tip.style.opacity = '1';
      tip.style.left = Math.min(r.width - 320, e.clientX - r.left + 14) + 'px';
      tip.style.top = (e.clientY - r.top + 14) + 'px';
      tip.innerHTML = `<b>${esc(n.label)}</b>
        <div class="pz">${esc(n.precision.slice(0, 190))}${n.precision.length > 190 ? '…' : ''}</div>
        <div style="margin-top:7px;display:flex;gap:12px;align-items:center">
          <span class="lbl">${m > 0 ? band(m)[2] : 'Not yet met'}</span>
          <span class="dnum" style="font-size:15px">${m}</span>
          ${rec && rec.d ? `<span class="lbl">${LEVELS[rec.d]}</span>` : ''}
        </div>`;
    } else tip.style.opacity = '0';
  };
  cv.onmouseleave = () => { hover = null; tip.style.opacity = '0'; };
  cv.onclick = e => {
    const r = cv.getBoundingClientRect();
    const n = hit(e.clientX - r.left, e.clientY - r.top);
    if (n) showConcept(n.id);
  };
}

/* ---------------------------------------------------------- LEDGER */
function vLedger(stage) {
  const w = el('div', { class:'wrap stg' });
  w.appendChild(el('h1', { text:'The Ledger' }));
  w.appendChild(el('p', { style:'color:var(--ink-2);margin:8px 0 22px;max-width:68ch',
    text:'Every error, kept. The list is only useful when it shrinks, so it is ordered by what will cost you most: errors you were confident about, then errors that keep recurring, then everything else.' }));

  if (!S.errors.length) {
    w.appendChild(el('div', { class:'empty' }, [
      el('h3', { text:'Nothing recorded yet' }),
      el('p', { text:'Errors appear here as you make them. That is the point of them.' }),
    ]));
    stage.appendChild(w); return;
  }

  const clusters = misconceptionClusters(5);
  if (clusters.length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'Shared misconceptions' })]));
    const p = el('div', { class:'card', style:'margin-bottom:14px' });
    p.appendChild(el('p', { style:'font-size:13px;color:var(--ink-2);margin-bottom:12px',
      text:'These concepts sit underneath more than one of your errors. Teaching the node is worth more than correcting the instances.' }));
    clusters.forEach(c => {
      const row = el('div', { class:'listrow', onclick: () => showConcept(c.cid) }, [
        el('span', { class:'dot ' + c.node.domain }),
        el('span', { class:'nm', style:'color:var(--ink)', text: c.node.label }),
        el('span', { class:'vv', text: Math.round(c.n) + ' × · ' + c.m + '%' }),
      ]);
      p.appendChild(row);
    });
    w.appendChild(p);
  }

  const byType = {};
  S.errors.forEach(e => { if (e.type) byType[e.type] = (byType[e.type] || 0) + 1; });
  if (Object.keys(byType).length) {
    w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'How you go wrong' })]));
    const p = el('div', { class:'card', style:'margin-bottom:14px' });
    const total = Object.values(byType).reduce((a, b) => a + b, 0);
    ERROR_TYPES.forEach(([id, nm]) => {
      const n = byType[id] || 0; if (!n) return;
      const row = el('div', { style:'margin-bottom:11px' });
      row.innerHTML = `<div style="display:flex;justify-content:space-between;font-size:12.5px;margin-bottom:5px">
          <span>${nm}</span><span class="dnum" style="color:var(--ink-3)">${n}</span></div>
        <div class="meter"><i style="width:${n/total*100}%"></i></div>`;
      p.appendChild(row);
    });
    w.appendChild(p);
  }

  w.appendChild(el('div', { class:'divider' }, [el('span', { class:'lbl', text:'The errors' })]));
  const sorted = S.errors.slice().sort((a, b) => (b.conf - a.conf) || (b.ts - a.ts));
  sorted.slice(0, 60).forEach(e => {
    const item = ITEM[e.id];
    const d = el('details', { class:'disc', style:'margin-bottom:8px' });
    const cs = (e.concepts || []).map(c => (CONCEPT[c] || {}).label).filter(Boolean).slice(0, 2).join(', ');
    d.innerHTML = `<summary>
        <span style="flex:1 1 auto;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(e.stem || cs)}</span>
        ${e.conf >= 4 ? '<span class="pill" style="border-color:var(--warning);color:var(--warning)">confident</span>' : ''}
        <span class="lbl">${relTime(e.ts)}</span></summary>`;
    const dc = el('div', { class:'dc' });
    if (cs) dc.appendChild(el('p', { class:'lbl', style:'margin-bottom:8px', text: cs }));
    if (item) {
      dc.appendChild(el('p', { style:'font-size:13.5px;color:var(--ink-2)', text: item.teach }));
      if (item.precision) {
        const pr = el('div', { class:'precision' });
        pr.innerHTML = `<div class="lbl">Say it exactly like this</div><p>${esc(item.precision)}</p>`;
        dc.appendChild(pr);
      }
    }
    (e.concepts || []).slice(0, 3).forEach(cid => {
      const n = CONCEPT[cid]; if (!n) return;
      dc.appendChild(el('button', { class:'btn ghost', style:'margin:10px 8px 0 0', text: n.label + ' →',
        onclick: () => showConcept(cid) }));
    });
    d.appendChild(dc);
    w.appendChild(d);
  });
  stage.appendChild(w);
}

/* ---------------------------------------------------------- concept card */
function showConcept(id) {
  const n = CONCEPT[id]; if (!n) return;
  const m = mastery(id), rec = S.c[id];
  const body = el('div');

  const top = el('div', { style:'display:flex;gap:20px;align-items:flex-end;flex-wrap:wrap;margin-bottom:18px' });
  top.innerHTML = `<div><div class="lbl">Mastery</div>
      <div class="dnum" style="font-size:36px;line-height:1;color:${band(m)[3]}">${m}</div></div>
    <div><div class="lbl">Depth reached</div>
      <div style="font-size:15px;font-weight:600;margin:5px 0 6px">${rec && rec.d ? LEVELS[rec.d] : 'not yet met'}</div>
      <div class="rungs ${n.domain}">${[1,2,3,4,5].map(i => `<i class="${i <= ((rec && rec.d) || 0) ? 'on' : ''}"></i>`).join('')}</div></div>
    <div style="flex:1 1 140px"><div class="lbl">${band(m)[2]}</div>
      <div class="meter" style="margin-top:7px"><i style="width:${m}%;background:${band(m)[3]}"></i></div></div>`;
  body.appendChild(top);

  const p = el('div', { class:'card', style:'margin-bottom:12px;border-color:color-mix(in srgb,var(--good) 34%,transparent)' });
  p.innerHTML = `<div class="lbl" style="color:var(--good)">The precise formulation</div>
    <p style="margin-top:7px;font-size:14.5px;line-height:1.6">${esc(n.precision)}</p>`;
  body.appendChild(p);

  if (n.notThis && n.notThis.length) {
    const q = el('div', { class:'flag' });
    q.innerHTML = `<div class="lbl">It is NOT</div>` +
      n.notThis.map(x => `<div style="margin-top:5px">✕ ${esc(x)}</div>`).join('');
    body.appendChild(q);
  }

  const rel = (n.parents || []).concat(n.related || []).filter((v, i, a) => a.indexOf(v) === i);
  if (rel.length) {
    body.appendChild(el('div', { class:'lbl', style:'margin:16px 0 8px', text:'Sits next to' }));
    const row = el('div', { class:'tagrow' });
    rel.forEach(r => {
      const rn = CONCEPT[r]; if (!rn) return;
      const b = el('button', { class:'pill act' },
        [el('span', { class:'dot ' + rn.domain }), el('span', { text: rn.label }),
         el('span', { style:'color:var(--ink-3)', text: mastery(r) })]);
      b.addEventListener('click', () => showConcept(r));
      row.appendChild(b);
    });
    body.appendChild(row);
  }

  const related = DATA.items.items.filter(it => it.concepts.includes(id));
  if (related.length) {
    const b = el('button', { class:'btn pri lg', style:'margin-top:20px',
      text: `Drill this — ${related.length} item${related.length===1?'':'s'}`,
      onclick: () => { closeModal(); SESSION = { items: shuffle(related), idx:0, right:0, started:Date.now(), answers:[], minutes:10 }; go('drill'); } });
    body.appendChild(b);
  }
  openModal(n.label, body, n.domain);
}

/* ---------------------------------------------------------- modal */
function openModal(title, body, domain) {
  const m = $('#modal');
  m.innerHTML = '';
  const h = el('div', { class:'mh' });
  h.appendChild(el('div', { style:'display:flex;justify-content:space-between;align-items:flex-start;gap:14px' }, [
    el('h2', { style:'display:flex;align-items:center;gap:9px' },
      [domain ? el('span', { class:'dot ' + domain }) : null, el('span', { text: title })]),
    el('button', { class:'iconbtn', text:'✕', onclick: closeModal }),
  ]));
  m.appendChild(h);
  const b = el('div', { class:'mb' });
  b.appendChild(body);
  m.appendChild(b);
  m.classList.add('on'); $('#scrim').classList.add('on');
}
function closeModal() { $('#modal').classList.remove('on'); $('#scrim').classList.remove('on'); }
