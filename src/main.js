// Wiring: the night catalogue, the trading day, the receipt.

import {
  buildContent, emptySlots, findInstance, fixtureInstances, loadRawData,
  ownedIds, ratchetCount,
} from './engine.js';
import { createRun } from './run.js';
import { createTradingDay } from './trading-day.js';
import { createFloorRenderer } from './floor.js';
import { createAudio } from './audio.js';
import { save } from './save.js';
import { createParticles, roll, wipe } from './motion.js';

const $ = (id) => document.getElementById(id);
const money = (v) => `${v < 0 ? '−' : ''}£${Math.abs(Math.round(v)).toLocaleString('en-GB')}`;
const pct = (v) => `${Math.round(v * 100)}%`;

let content = null;
let game = null;
let day = null;
let floor = null;
let audio = null;
let pending = null; // fixture awaiting placement
let speed = 1;
let character = 'default_shop';
let audit = 1;
// Peak day of the current run. The target is the fail condition; this is the
// number the run is actually about, and a good one overshoots it fifty times.
let peakDay = 0;
let particles = null;
let lastShort = null;
let paused = false;

// ---------------------------------------------------------------- copy ----

const TERM_WORD = { footfall: 'Footfall', conversion: 'Conversion', basket: 'Basket', margin: 'Margin', none: '' };

/** Catalogue sales copy, generated from the data so it can never drift. */
function describe(def, level = 1) {
  const L = level - 1;
  const v = def.effect.value[L];
  const term = TERM_WORD[def.term] || '';
  switch (def.effect.op) {
    case 'add':
      return def.term === 'conversion' || def.term === 'margin'
        ? `+${Math.round(v * 100)}% ${term}`
        : `+${def.term === 'basket' ? `£${v}` : v} ${term}`;
    case 'multiply':
      return `×${v} ${term}`;
    case 'ratchet':
      return `Gains +${def.term === 'basket' ? `£${v}` : v} ${term} permanently, ${feedWord(def)}`
        + (def.effect.accel ? `, and that gain grows by ${def.effect.accel[L]} a day` : '');
    case 'ratchet_mult':
      return `Its ${term} multiplier grows by ${(v * 100).toFixed(1)}% ${feedWord(def)}`;
    // The one exponential op, and the card has to say so plainly: what makes
    // it different is not the size of the number but that it multiplies.
    case 'compound':
      return `×${v.toFixed(2)} ${term} ${feedWord(def)} — compounding`;
    case 'rule': return ruleText(def, L);
    default: return '';
  }
}

/** What feeds this ratchet. Reads as the tail of a sentence. */
function feedWord(def) {
  switch (def.effect.per || 'day') {
    case 'sale': return 'per sale';
    case 'type_sale': return `per ${def.effect.perType} served`;
    case 'walkout': return 'per walkout, up to the number you served';
    case 'boss': return 'per inspection survived';
    case 'win': return 'on every day you beat the target';
    default: return 'every trading day';
  }
}

function ruleText(def, L) {
  const v = def.effect.value[L];
  const d = def.drawback ? def.drawback.value[L] : null;
  switch (def.effect.rule) {
    case 'shoplifters_become_browsers': return `Shoplifters become Browsers. −${Math.round(d * 100)}% Margin`;
    case 'no_skip': return `Every customer passes every slot in their aisle. ${d} Patience`;
    case 'throughput': return `+${v} till throughput. Pensioners ${d >= 1 ? 'never convert' : `convert at ${Math.round((1 - d) * 100)}%`}`;
    case 'unsold_to_footfall': return `${Math.round(v * 100)}% of unsold stock becomes Footfall tomorrow`;
    case 'buyers_return': return `Anyone who buys returns once more today, converting at ${Math.round(d * 100)}%`;
    case 'conversion_certain': return `Conversion becomes 100%. Only ${d} customers may enter`;
    case 'footfall_multiply_flat_basket': return `×${v} Footfall. Basket fixed at £${d}`;
    case 'basket_multiply_single_till': return `×${v} Basket. Throughput capped at ${d}`;
    case 'margin_set': return `Margin becomes ${Math.round(v * 100)}%, while you hold ${d} fixtures or fewer`;
    default: return def.effect.rule;
  }
}

function conditionText(def) {
  const bits = [];
  for (const c of def.trigger.conditions || []) {
    if (c.check === 'customer_type_in') bits.push(`${c.value.join(' / ')} only`);
    if (c.check === 'aisle_holds_no_rarity') bits.push(`if this aisle holds no ${c.value} fixture`);
    if (c.check === 'shop_holds_no_tag') bits.push(`if you hold no ${c.value} fixtures`);
    if (c.check === 'slot_is_first') bits.push('front of the aisle only');
    if (c.check === 'slot_is_last') bits.push('back of the aisle only');
    if (c.check === 'slot_index_min') bits.push(`slot ${c.value + 1} or deeper`);
    if (c.check === 'prev_slot_class') bits.push(`if the slot before it is ${c.value}`);
    if (c.check === 'prev_slot_term') bits.push(`if the slot before it is a ${c.value} fixture`);
    if (c.check === 'aisle_holds_no_class') bits.push(`if this aisle holds no ${c.value} fixture`);
    if (c.check === 'aisle_all_share_tag') bits.push(`if every fixture in this aisle is ${c.value}`);
    if (c.check === 'shop_holds_at_least_tag') bits.push(`if you hold ${c.count}+ ${c.value} fixtures`);
  }
  if (def.trigger.scope === 'next_slots') bits.push(`amplifies the next ${def.trigger.count[0]} slot(s)`);
  return bits.join(', ');
}

const stockCode = (id) => id.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 4)
  + '-' + (id.length * 37 % 900 + 100);

// --------------------------------------------------------------- panel ----

function renderPanel() {
  const d = game.projection();
  const p = d.panel;
  const target = game.target(game.run.encounter);
  // Rolling, not snapping. A figure that snaps has to be re-read; one that
  // rolls tells you which way it moved without being read at all.
  roll($('p-footfall'), p.footfall, (v) => Math.round(v).toLocaleString('en-GB'));
  roll($('p-conv'), p.conversion, (v) => pct(v));
  roll($('p-basket'), p.basket, money);
  roll($('p-margin'), p.margin, (v) => pct(v));
  roll($('p-trading'), p.trading, money);
  $('p-rent').textContent = `rent ${money(-p.rent)}`;
  $('p-shrink').textContent = `shrink ${money(p.shrink)}`;
  $('p-upkeep').textContent = `upkeep ${money(-(p.upkeep + (d.ratchetUpkeep || 0)))}`;
  const gap = d.profit - target;
  const short = gap < 0;
  const pel = $('p-profit');
  roll(pel, d.profit, money, 520);
  pel.className = `vprofit ${short ? 'short' : 'clear'}`;
  // The one state change on this panel worth interrupting someone for.
  if (lastShort !== null && lastShort !== short) {
    pel.classList.remove('flip');
    void pel.offsetWidth;
    pel.classList.add('flip');
  }
  lastShort = short;
  const g = $('p-gap');
  g.innerHTML = short
    ? `against ${money(target)} — <b>${money(-gap)} short</b>`
    : `against ${money(target)} — <b>${money(gap)} clear</b>`;
  g.className = `vgap ${short ? 'short' : 'clear'}`;
}

function renderLedger() {
  const { shop, run } = game;
  $('l-quarter').textContent = shop.quarter;
  $('l-day').textContent = `${run.encounter}/${content.run.encounters}`;
  $('l-cash').textContent = money(shop.cash);
  $('l-tills').textContent = shop.tills;
  $('l-tier').textContent = shop.supplierTier;
  const b = game.boss();
  const next = game.nextBoss();
  $('l-boss').innerHTML = b
    ? `<span class="boss-flag">${b.name} today</span>`
    : next ? `<span class="chip">${next.boss.name} <b>day ${next.encounter}</b></span>` : '';
}

// --------------------------------------------------------------- night ----

function renderOffers() {
  const wrap = $('offers');
  wrap.innerHTML = '';
  for (const def of game.run.offers) {
    const owned = findInstance(game.shop, def.id);
    const lvl = owned ? Math.min(3, owned.inst.level + 1) : 1;
    const el = document.createElement('div');
    el.className = `entry r-${def.rarity}${game.run.picked ? ' owned' : ''}`;
    const cond = conditionText(def);
    // A starburst is the catalogue's way of saying "look here", so it goes on
    // the two things worth looking at: the top of the page, and a card you
    // already hold one of.
    const burst = owned
      ? `<div class="burst gold"><b>Makes<br>L${lvl}</b></div>`
      : def.rarity === 'flagship' ? '<div class="burst"><b>Star<br>buy</b></div>'
        : def.rarity === 'rare' ? '<div class="burst"><b>New<br>in</b></div>' : '';
    el.innerHTML = `
      ${burst}
      <div class="name">${def.name}</div>
      <div class="byline"><span class="tier">${def.rarity}</span>
        <span class="code">${stockCode(def.id)}</span></div>
      <div class="eff">${describe(def, lvl)}${cond ? ` <span class="code">— ${cond}</span>` : ''}</div>
      <div class="copy">${def.tags && def.tags.length ? def.tags.join(' · ') : def.class.replace('_', '-')}</div>`;
    el.onclick = () => beginPlace(def);
    wrap.appendChild(el);
  }
  const rc = game.currentRerollCost();
  $('btn-reroll').innerHTML = `Fresh flyer <em>${rc === 0 ? 'free' : money(rc)}</em>`;
  $('btn-reroll').disabled = game.run.picked || game.shop.cash < rc;
  const pay = content.economy.payout;
  const skip = pay.flatBase * Math.pow(pay.flatGrowth, game.run.encounter - 1) * (pay.skipPickReward || 0);
  $('btn-skip').innerHTML = `Take the cash instead <em>${money(skip)}</em>`;
  $('btn-skip').disabled = game.run.picked;
}

function beginPlace(def) {
  if (game.run.picked) return;
  const owned = findInstance(game.shop, def.id);
  if (owned) { // a duplicate combines; there is no placement to make
    const lvl = Math.min(3, owned.inst.level + 1);
    game.take(def.id, null);
    audio.combine(lvl);
    pending = null;
    renderNight();
    return;
  }
  pending = def;
  $('place-hint').textContent = emptySlots(game.shop).length
    ? `Placing ${def.name} — pick a slot. Order matters.`
    : game.shop.flags.fixturesPermanent
      ? `Placing ${def.name} — the shop is full, and nothing here can be removed.`
      : `Placing ${def.name} — the shop is full. Pick what it goes on top of.`;
  renderNight();
}

function renderFloorplan() {
  const wrap = $('aisles');
  wrap.innerHTML = '';
  const full = emptySlots(game.shop).length === 0;
  game.shop.aisles.forEach((aisle, ai) => {
    const row = document.createElement('div');
    row.className = `aisle${aisle.closed ? ' closed' : ''}`;
    row.innerHTML = `<div class="lbl">Aisle ${ai + 1}</div>`;
    aisle.slots.forEach((inst, si) => {
      const cell = document.createElement('div');
      const free = !inst;
      // A full shop does not end the run's decisions, it sharpens them: the
      // pick lands on top of something, and choosing what to clear out is the
      // whole of the back half of the game.
      const takeable = pending && (free || (full && !game.shop.flags.fixturesPermanent));
      cell.className = `slot${inst ? ' filled' : ''}${takeable ? ' target' : ''}`
        + `${takeable && !free ? ' scrap' : ''}`;
      cell.innerHTML = inst
        ? `<div class="fx">${inst.def.name}</div><div class="tm">${TERM_WORD[inst.def.term] || '—'}</div>
           ${inst.level > 1 ? `<div class="lv">L${inst.level}</div>` : ''}
           ${inst.staff ? `<div class="st">${inst.staff[0].toUpperCase()}</div>` : ''}`
        : '<div class="tm">empty</div>';
      cell.onclick = () => {
        if (!takeable) return;
        game.take(pending.id, { aisle: ai, slot: si });
        audio.place();
        pending = null;
        $('place-hint').textContent = '';
        renderNight();
      };
      row.appendChild(cell);
    });
    wrap.appendChild(row);
  });
}

function renderBuys() {
  const { shop } = game;
  const wrap = $('buys');
  wrap.innerHTML = '';
  const add = (label, opt, note) => {
    const cost = game.costOf(opt);
    if (!Number.isFinite(cost)) return;
    const b = document.createElement('button');
    b.className = 'buy';
    b.innerHTML = `<span class="n">${label}${note ? `<br><span class="code">${note}</span>` : ''}</span>
                   <span class="c">${cost === 0 ? '—' : money(cost)}</span>`;
    b.disabled = shop.cash < cost;
    b.onclick = () => { if (game.buy(opt)) { audio.place(); renderNight(); } };
    wrap.appendChild(b);
  };

  add('Extra till', 'till', 'more throughput');
  if (shop.supplierTier < 5) add(`Supplier Tier ${shop.supplierTier + 1}`, 'tier', 'better catalogue, free pick');
  for (const s of content.economy.structural) {
    if (s.id === 'extra_till') continue;
    if (!s.repeatable && shop.structural.has(s.id)) continue;
    add(s.name, `struct:${s.id}`);
  }
  for (const st of content.economy.staff) {
    const pp = `−${Math.round(st.marginCost * 100)}pp Margin`;
    if (!st.attaches) {
      if (shop.staff.some((x) => x.id === st.id)) continue;
      add(st.name, `staff:${st.id}`, pp);
    } else {
      const free = fixtureInstances(shop).filter(({ inst }) => !inst.staff)[0];
      if (free) add(`${st.name} → ${free.inst.def.name}`, `staff:${st.id}@${free.aisle},${free.slot}`, pp);
    }
  }
  if (shop.marketing.length < (content.marketingMaxHeld ?? 99)) {
    for (const c of content.campaigns) {
      if (shop.marketing.includes(c.id)) continue;
      add(c.name, `marketing:${c.id}`, `upkeep ${money(c.upkeep)}/day`);
    }
  }
}

function renderBossChoice() {
  const p = game.run.pendingBossChoice;
  const box = $('bosschoice');
  box.hidden = !p;
  if (!p) return;
  const wrap = $('boss-options');
  wrap.innerHTML = '';
  for (let i = 0; i < p.options.length; i++) {
    const b = p.options[i];
    const el = document.createElement('button');
    el.className = 'bosscard';
    el.innerHTML = `<div class="bn">${b.name}</div><div class="bd">${bossText(b)}</div>`;
    el.onclick = () => { game.chooseBoss(i); renderNight(); };
    wrap.appendChild(el);
  }
}

function bossText(b) {
  const v = b.value;
  switch (b.effect) {
    case 'footfall_multiply': return `Footfall ×${v}`;
    case 'basket_multiply_patience_multiply': return `Basket ×${v[0]}, Patience ×${v[1]}`;
    case 'only_types_convert': return `Only ${v.join(' and ')} customers convert`;
    case 'disable_unstaffed': return 'Any unstaffed fixture is disabled';
    case 'footfall_multiply_till_disable': return `Footfall ×${v[0]}, ${v[1]} till disabled`;
    case 'disable_term_class': return 'Basket-adding fixtures do nothing';
    case 'margin_halved_unless_staffed_aisles': return 'Margin halved unless every aisle holds a staffed fixture';
    case 'footfall_multiply_margin_flat': return `Footfall ×${v[0]}, Margin ${Math.round(v[1] * 100)}pp`;
    case 'close_aisle': return 'One aisle is closed';
    case 'refund_previous': return `${Math.round(v * 100)}% of yesterday's trading profit is refunded`;
    case 'rent_multiply': return `Rent ×${v}`;
    case 'disable_rarity': return 'Flagship fixtures are disabled';
    default: return b.effect;
  }
}

function renderNight() {
  const box = $('bosschoice');
  const night = $('night');
  if (night.firstElementChild !== box) night.insertBefore(box, night.firstElementChild);
  renderLedger();
  renderPanel();
  renderOffers();
  renderFloorplan();
  renderBuys();
  renderBossChoice();
  $('cat-tier').textContent = `Tier ${game.shop.supplierTier}`;
  const ready = game.run.picked && !game.run.pendingBossChoice;
  $('btn-open').hidden = false;
  $('btn-open').disabled = !ready;
  $('tip').textContent = pending
    ? 'Pick a slot. An additive bump placed before a multiplier gets multiplied.'
    : game.run.pendingBossChoice ? 'Choose which day is coming.'
      : ready ? 'Doors when you are ready.' : 'Take one from the catalogue.';
}

// ----------------------------------------------------------------- day ----

function openDoors() {
  audio.unlock();
  audio.tannoy();
  particles = createParticles();
  setPaused(false);
  showWiped('day', () => maybeCoach('day'));
  day = createTradingDay(content, game.shop, game.ctx(), game.run.rng);
  $('btn-open').hidden = true;
  $('tip').textContent = 'Someone waiting? Tap them and take them next.';
  let acc = 0;
  let last = performance.now();

  function frame(now) {
    const dt = Math.min(120, now - last);
    last = now;
    acc += dt;
    const msPerTick = 90 / speed;
    let guard = 0;
    if (paused) acc = 0;
    while (!paused && acc >= msPerTick && !day.state.finished && guard++ < 40) {
      const before = day.state.sales;
      const beforeLost = day.state.walkouts;
      day.step();
      if (day.state.sales > before) {
        audio.sale();
        const at = floor.tillPoint();
        // One coin per event, not per person — at eighty thousand Footfall a
        // coin per sale would take the frame rate with it.
        particles.emit('coin', at.x + (Math.random() - 0.5) * 40, at.y);
      }
      if (day.state.walkouts > beforeLost) {
        audio.walkout();
        const at = floor.tillPoint();
        particles.emit('cross', at.x + (Math.random() - 0.5) * 60, at.y - 20);
        particles.emit('puff', at.x + (Math.random() - 0.5) * 60, at.y - 16);
      }
      acc -= msPerTick;
    }
    audio.setFrenzy(day.state.frenzy);
    document.documentElement.style.setProperty('--frenzy', day.state.frenzy.toFixed(2));
    particles.update();
    floor.draw(day, game.shop, particles);
    const n = (v) => Math.round(v).toLocaleString('en-GB');
    roll($('d-clock'), Math.min(100, day.state.tick / day.state.ticks * 100), (v) => `${Math.round(v)}%`, 200);
    roll($('d-sales'), day.state.sales, n, 300);
    roll($('d-walk'), day.state.walkouts, n, 300);
    roll($('d-profit'), day.state.tradingProfit + day.state.shrink, money, 300);
    $('d-triage').textContent = day.state.triageLeft;
    if (day.state.finished) { settle(); return; }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function settle() {
  document.documentElement.style.setProperty('--frenzy', '0');
  audio.quiet();
  audio.receipt();
  const s = day.state;
  const entry = game.settle(s);
  // The target is only the fail condition. The number the run is remembered by
  // is the best day it ever had, and a good run overshoots its last target
  // fifty times over.
  if (s.profit > peakDay) peakDay = s.profit;
  showWiped('settle', () => maybeCoach('settle'));
  $('tip').textContent = entry.fatal
    ? 'The landlord does not take instalments.'
    : 'Cash up, lock the door, order for tomorrow.';
  const row = (k, v, cls = '') => `<div class="r ${cls}"><span>${k}</span><span>${v}</span></div>`;
  $('receipt').innerHTML = `
    <h3>FOOTFALL</h3>
    <div class="r"><span>Day ${entry.encounter} of ${content.run.encounters}</span><span>Q${game.shop.quarter}</span></div>
    <div class="rule"></div>
    ${row('Footfall', s.footfall)}
    ${row('Served', s.served)}
    ${row('Sales', s.sales)}
    ${row('Walkouts', s.walkouts + (s.rescued ? ` (${s.rescued} rescued)` : ''))}
    <div class="rule"></div>
    ${row('Trading profit', money(s.tradingProfit))}
    ${row('Shrink', money(s.shrink))}
    ${s.refunds ? row('Refunds', money(-s.refunds)) : ''}
    ${row('Rent', money(-s.rent))}
    ${row('Upkeep', money(-(s.upkeep + s.ratchetUpkeep)))}
    <div class="rule"></div>
    ${row('PROFIT', money(s.profit), 'big')}
    ${row('You planned', money(s.projection.profit))}
    ${row('Target', money(entry.target))}
    ${row('Gap', money(s.profit - entry.target), 'big')}
    ${entry.interest ? row('Interest', money(entry.interest)) : ''}
    <div class="verdict ${entry.fatal ? 'fail' : 'pass'}">
      ${entry.fatal ? 'THE LANDLORD IS AT THE DOOR' : 'TARGET MET'}
    </div>`;
  $('btn-continue').textContent = entry.fatal ? 'That was the run'
    : game.run.encounter >= content.run.encounters ? 'You did it' : 'Lock up';
}

// --------------------------------------------------------------- shell ----

/**
 * Phase change behind a page turn. A hard cut between the catalogue and the
 * floor gives the eye nothing to follow, and makes two registers of one
 * publication feel like two programs.
 */
function showWiped(which, after) {
  wipe(document.body, () => { show(which); if (after) after(); });
}

function show(which) {
  for (const id of ['title', 'night', 'day', 'settle']) $(id).hidden = id !== which;
  $('btn-open').hidden = which !== 'night';
  // The ledger and the projection panel are readouts of a run in progress.
  // On the title screen there is no run, and a row of zeroes above the logo
  // reads as a broken game rather than an empty one.
  const inRun = which !== 'title';
  $('ledger').hidden = !inRun;
  $('panel').hidden = !inRun;
}

function nextEncounter() {
  if (game.run.over) return endRun();
  game.beginNight();
  if (game.run.over) return endRun();
  pending = null;
  showWiped('night', () => { renderNight(); maybeCoach('night'); });
}

function endRun() {
  show('settle');
  const won = game.run.won;
  const days = game.run.log.length;
  const first = game.run.log[0] ? game.run.log[0].profit : 0;
  const last = game.run.log[days - 1];
  const climb = first > 0 ? Math.max(0, (last ? last.profit : 0) / first) : 0;

  const outcome = save.record({
    characterId: character,
    audit,
    won,
    days,
    bestDay: peakDay,
    climb,
    seed: game.run.seed,
  });

  const build = fixtureInstances(game.shop)
    .map(({ inst }) => `${inst.def.name}${inst.level > 1 ? ` L${inst.level}` : ''}`);
  const ch = content.characterById.get(character);

  $('receipt').innerHTML = `<h3>${won ? 'Eight quarters' : 'Closing down'}</h3>
    <div class="headline ${won ? 'pass' : 'fail'}">${money(peakDay)}</div>
    <div class="sub">best day&rsquo;s profit${outcome.record ? ' &mdash; a personal record' : ''}</div>
    ${outcome.unlocked ? `<div class="unlock">Audit ${roman(outcome.unlocked)} unlocked</div>` : ''}
    <div class="rule"></div>
    <div class="r"><span>${ch.name}, Audit ${roman(audit)}</span><span>${won ? 'survived' : `day ${days}`}</span></div>
    <div class="r"><span>Days traded</span><span>${days} / ${content.run.encounters}</span></div>
    <div class="r"><span>Climb, first day to last</span><span>${climb >= 1 ? `&times;${Math.round(climb).toLocaleString('en-GB')}` : '&mdash;'}</span></div>
    <div class="r"><span>Banked</span><span>${money(game.shop.cash)}</span></div>
    <div class="r"><span>Seed</span><span>${game.run.seed}</span></div>
    <div class="rule"></div>
    ${game.run.log.slice(-5).map((e) => `<div class="r"><span>Day ${e.encounter}</span><span>${money(e.profit)} / ${money(e.target)}</span></div>`).join('')}
    <div class="build">${build.join(' &middot; ') || 'an empty shop'}</div>
    <div class="verdict ${won ? 'pass' : 'fail'}">${won ? 'THE SHOP SURVIVES' : `IT ENDED ON DAY ${days}`}</div>`;
  $('btn-continue').textContent = 'Open another shop';
  $('btn-continue').onclick = () => { showTitle(); };
}

function hashSeed(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 1;
}

function setPaused(v) {
  paused = v;
  const b = $('btn-pause');
  if (b) b.textContent = paused ? 'Resume' : 'Pause';
  $('tip').textContent = paused
    ? 'Paused. You can still take someone to the till.'
    : 'Someone waiting? Tap them and take them next.';
}

// ------------------------------------------------------------- coaching ----
// Shown once each, on a first run only. A rules sheet nobody opens is not
// onboarding; a line that arrives at the moment it is needed is.

const COACH = [
  ['night', 'Take one line', 'Pick a card from the catalogue and put it in an aisle. Customers walk front to back, and every fixture fires as they pass — so where it goes matters as much as what it is.'],
  ['day', 'Watch the queue', 'They cross the floor, then they wait. Patience runs down while they do; at nothing, they leave — a lost sale AND a quieter tomorrow. Tap anyone waiting to take them next.'],
  ['settle', 'Mind the gap', 'Beat the target and you trade again tomorrow. Miss it once and that is the run. The target climbs every single day, so standing still is losing slowly.'],
];

function maybeCoach(phase) {
  if (save.get().runs > 0) return;            // not on a second run
  const seen = coachSeen;
  const item = COACH.find(([p]) => p === phase && !seen.has(p));
  if (!item) return;
  seen.add(phase);
  $('coach-t').textContent = item[1];
  $('coach-b').textContent = item[2];
  $('coach').hidden = false;
}
const coachSeen = new Set();

const ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
const roman = (n) => ROMAN[n] || String(n);

function renderCharacters() {
  const wrap = $('charpick');
  wrap.innerHTML = '';
  for (const c of content.characters) {
    const cleared = save.clearedFor(c.id);
    const b = document.createElement('button');
    b.className = `charbtn${c.id === character ? ' on' : ''}`;
    b.innerHTML = `<div class="cn">${c.name}</div><div class="cr">${c.rule}</div>`
      + (cleared ? `<div class="lock">cleared to Audit ${roman(cleared)}</div>` : '');
    b.onclick = () => { character = c.id; renderTitle(); };
    wrap.appendChild(b);
  }
}

/**
 * The ladder. Audit n+1 unlocks when this character clears n, so progress is
 * per shop rather than global — the Discounter's run is a different game from
 * the Estate Agent's and clearing one says nothing about the other.
 */
function renderAudits() {
  const wrap = $('auditpick');
  wrap.innerHTML = '';
  const max = content.audits.length;
  const unlocked = save.unlockedFor(character, max);
  if (audit > unlocked) audit = unlocked;
  for (const a of content.audits) {
    const b = document.createElement('button');
    const done = a.id <= save.clearedFor(character);
    b.className = `auditbtn${a.id === audit ? ' on' : ''}${done ? ' done' : ''}`;
    b.textContent = roman(a.id);
    b.disabled = a.id > unlocked;
    b.title = auditText(a);
    b.onclick = () => { audit = a.id; renderTitle(); };
    wrap.appendChild(b);
  }
  const cur = content.audits.find((a) => a.id === audit);
  $('audit-hint').textContent = auditText(cur);
}

const AUDIT_WORDS = {
  rentMultiplier: (v) => `rent ×${v}`,
  targetMultiplier: (v) => `targets ×${v}`,
  rerollCostMultiplier: (v) => `rerolls ×${v}`,
  bossEvery: (v) => `an inspection every ${v} days`,
  flagshipTwoDayCondition: () => 'flagships need two good days',
  supplierCostsFlat: () => 'supplier tiers cost full price',
  quarterlyAisleClosure: () => 'an aisle shuts for a day each quarter, from Q3',
};

function auditText(a) {
  if (!a) return '';
  const bits = Object.entries(a.modifiers || {})
    .map(([k, v]) => (AUDIT_WORDS[k] ? AUDIT_WORDS[k](v) : k));
  return bits.length ? bits.join(', ') : 'the shop as written';
}

function renderTitle() {
  renderCharacters();
  renderAudits();
  const s = save.get();
  $('titlestats').innerHTML = [
    `Runs <b>${s.runs}</b>`,
    `Survived <b>${s.wins}</b>`,
    `Best day <b>${money(s.bestDay)}</b>`,
    s.bestClimb >= 1 ? `Best climb <b>×${Math.round(s.bestClimb).toLocaleString('en-GB')}</b>` : '',
  ].filter(Boolean).join('');
}

// ---------------------------------------------------------------- sheet ----

function openSheet(html) {
  $('sheetbody').innerHTML = html;
  $('sheet').hidden = false;
}

const RULES = `
  <h3>How it works</h3>
  <p>You have eight quarters and twenty-four trading days. Every day has a
  profit target. Miss one and the run is over.</p>
  <div class="formula">Profit = Footfall &times; Conversion &times; Basket &times; Margin &minus; Rent</div>
  <p>Four terms that multiply and one cost that does not. A zero anywhere is a
  zero everywhere, so a run is worth roughly its weakest term.</p>

  <h4>The night</h4>
  <ul>
    <li>Take <b>one fixture</b> from the catalogue and place it in an aisle.
      Order matters: customers walk front to back and each fixture fires as
      they pass, so an amplifier is worth nothing behind the thing it
      amplifies.</li>
    <li>Two copies of a fixture combine to level 2, three to level 3.</li>
    <li>Once the floor is full, a new fixture <b>lands on top of one you
      already own</b>. What you clear out is the decision the back half of the
      run is made of.</li>
    <li>Or decline the pick and take the cash. Cash buys tills, supplier tiers,
      staff, floorspace and marketing &mdash; none of which you can also spend
      on a fixture.</li>
  </ul>

  <h4>The two terms that cap</h4>
  <p>Conversion stops at 90% and Margin at 70%. They are rates: floors you
  defend, not axes you grow. Footfall and Basket have no ceiling, and the whole
  late game lives in those two.</p>

  <h4>Growth</h4>
  <ul>
    <li>A <b>ratchet</b> gains a fixed amount every day. Reliable, and linear.</li>
    <li>A <b>compounder</b> multiplies. It is nearly worthless for its first
      week and then carries the run &mdash; so it is worth whatever is left of
      the run, and buying one on day twenty is a waste.</li>
    <li>Both charge upkeep against the target while you hold them. Scaling is
      never free, and three of them at once in act one is how you die.</li>
  </ul>

  <h4>The day</h4>
  <p>Customers walk in, cross an aisle and join the till queue. Patience drains
  while they wait; at zero they walk out, which is a lost sale <em>and</em> a
  quieter tomorrow. Click anyone in the queue to pull them straight to the
  till &mdash; you get a limited number of those a day.</p>
  <p>Footfall past what your tills can serve is not growth. It is a crowd you
  turn away.</p>

  <h4>The audit ladder</h4>
  <p>Survive all twenty-four days to unlock the next Audit for that shop. Each
  one changes a rule permanently, and each shop climbs its own ladder.</p>`;

function recordsHtml() {
  const s = save.get();
  const rows = s.history.map((h) => {
    const ch = content.characterById.get(h.characterId);
    return `<div class="hrow"><span>${ch ? ch.name : h.characterId} &middot; Audit ${roman(h.audit)}</span>
      <span class="${h.won ? 'w' : 'l'}">${h.won ? 'survived' : `day ${h.days}`} &middot; ${money(h.bestDay)}</span></div>`;
  }).join('');
  return `<h3>Records</h3>
    <div class="hrow"><span>Runs</span><span>${s.runs}</span></div>
    <div class="hrow"><span>Survived</span><span>${s.wins}</span></div>
    <div class="hrow"><span>Best day</span><span>${money(s.bestDay)}</span></div>
    <div class="hrow"><span>Best climb</span><span>${s.bestClimb >= 1 ? `&times;${Math.round(s.bestClimb).toLocaleString('en-GB')}` : '&mdash;'}</span></div>
    <h4>Recent runs</h4>
    ${rows || '<p>Nothing yet.</p>'}
    <h4>&nbsp;</h4>
    <button class="ghost" id="btn-wipe">Wipe everything</button>`;
}

/**
 * The whole run on one page: every day, the target it asks for, the day you
 * traded against it, and every inspection between here and the end.
 *
 * Without this a player sees one target, beats it, and gets another — with no
 * way to know whether the curve is about to bend, when the next inspection
 * lands, or what "eight quarters" is going to cost. One round tells you almost
 * nothing about the shape of a run, and the shape is the game.
 */
function runMapHtml() {
  const { shop, run } = game;
  const total = content.run.encounters;
  const per = content.run.daysPerQuarter;
  const log = new Map(run.log.map((e) => [e.encounter, e]));
  const maxTarget = game.target(total);

  let rows = '';
  for (let q = 1; q <= content.run.quarters; q++) {
    let cells = '';
    for (let i = 0; i < per; i++) {
      const enc = (q - 1) * per + i + 1;
      if (enc > total) break;
      const t = game.target(enc);
      const e = log.get(enc);
      const boss = game.bossAt ? game.bossAt(enc) : null;
      const state = e ? (e.fatal ? 'lost' : 'won') : enc === run.encounter ? 'now' : 'todo';
      // Log scale. The curve multiplies by 1.24 for twenty-four steps, which is
      // 140x end to end — on a linear axis day one is a hairline and the shape
      // reads as a wall rather than a climb.
      const lo = Math.log(content.targets[0]);
      const hi = Math.log(maxTarget);
      const h = Math.max(4, Math.round(((Math.log(t) - lo) / (hi - lo)) * 40) + 4);
      cells += `<div class="mday ${state}">
        <div class="mbar" style="height:${h}px"></div>
        <div class="mnum">${enc}</div>
        <div class="mt">${money(t)}</div>
        ${e ? `<div class="mgot">${money(e.profit)}</div>` : '<div class="mgot">&mdash;</div>'}
        ${boss ? `<div class="mboss" title="${boss.name}">!</div>` : ''}
      </div>`;
    }
    rows += `<div class="mq"><div class="mqlabel">Quarter ${q}</div>
      <div class="mqdays">${cells}</div></div>`;
  }

  const cleared = save.clearedFor(character);
  return `<h3>The run</h3>
    <p>Twenty-four trading days in eight quarters. Every day sets a target and
    every third day the landlord sends someone. Miss once and that is the run.</p>
    <div class="mkey">
      <span><i class="sw now"></i> today</span>
      <span><i class="sw won"></i> traded</span>
      <span><i class="sw todo"></i> to come</span>
      <span><i class="sw boss"></i> inspection</span>
    </div>
    <div class="mmap">${rows}</div>
    <h4>What the curve does</h4>
    <p>The target multiplies by <b>&times;${(content.targets[1] / content.targets[0]).toFixed(2)}</b>
    every day — ${money(content.targets[0])} on day one, <b>${money(maxTarget)}</b> on day
    twenty-four. Flat cards cannot keep up with a curve that multiplies; that is
    what the compounding fixtures are for, and why buying one late is a waste.</p>
    <h4>Where this shop stands</h4>
    <p>${content.characterById.get(character).name} has cleared
    <b>${cleared ? `Audit ${roman(cleared)}` : 'nothing yet'}</b>. Survive all
    twenty-four days to unlock the next rung — each shop climbs its own ladder,
    and there are eight.</p>`;
}

function showTitle() {
  game = null;
  day = null;
  pending = null;
  peakDay = 0;
  show('title');
  renderTitle();
}

async function boot() {
  const raw = await loadRawData();
  content = buildContent(raw);
  audio = createAudio();
  floor = createFloorRenderer($('floor'));
  if (save.get().muted) audio.toggleMute();
  showTitle();

  $('btn-start').onclick = () => {
    audio.unlock();
    // A typed seed makes a run repeatable, which is how anyone compares a
    // decision against the alternative they did not take.
    const typed = $('seed').value.trim();
    const seed = typed === '' ? undefined : (Number(typed) || hashSeed(typed));
    peakDay = 0;
    game = createRun(content, { characterId: character, audit, seed });
    nextEncounter();
  };
  $('btn-rules').onclick = () => openSheet(RULES);
  $('btn-map').onclick = () => { if (game) openSheet(runMapHtml()); };
  // The rules used to live only on the title screen, so the moment a run
  // started there was no way to look anything up.
  $('btn-help').onclick = () => openSheet(RULES);
  $('coach-x').onclick = () => { $('coach').hidden = true; };
  $('btn-records').onclick = () => {
    openSheet(recordsHtml());
    const wipe = $('btn-wipe');
    if (wipe) {
      wipe.onclick = () => {
        wipe.textContent = 'Tap again to confirm';
        wipe.onclick = () => { save.clear(); $('sheet').hidden = true; renderTitle(); };
      };
    }
  };
  $('btn-sheet-close').onclick = () => { $('sheet').hidden = true; };
  $('sheet').onclick = (e) => { if (e.target === $('sheet')) $('sheet').hidden = true; };
  $('btn-open').onclick = openDoors;
  $('btn-continue').onclick = () => nextEncounter();
  $('btn-reroll').onclick = () => { if (game.reroll()) { audio.place(); renderNight(); } };
  $('btn-skip').onclick = () => { if (game.skipPick()) { audio.sale(); renderNight(); } };
  $('btn-speed').onclick = () => {
    speed = speed === 1 ? 2 : speed === 2 ? 4 : 1;
    $('btn-speed').innerHTML = `&raquo; ${speed}&times;`;
  };
  // Pause. The day is the only part of the game with a clock, and there was no
  // way to stop it — including no way to stop it and think about who to serve,
  // which is the one decision the day contains.
  $('btn-pause').onclick = () => setPaused(!paused);
  $('floor').onclick = (e) => {
    if (!day || day.state.finished) return;
    const r = $('floor').getBoundingClientRect();
    const id = floor.pick(e.clientX - r.left, e.clientY - r.top);
    if (id && day.triage(id)) audio.triage();
  };
  window.addEventListener('keydown', (e) => {
    if (e.target && e.target.tagName === 'INPUT') return;
    if (e.key === 'm') save.setMuted(audio.toggleMute());
    if (e.key === 'Escape') $('sheet').hidden = true;
    if (e.key === '?') openSheet(RULES);
    // Space is the one action the current phase wants, whatever it is.
    if (e.key === ' ') {
      e.preventDefault();
      if (day && !day.state.finished && !$('day').hidden) { setPaused(!paused); return; }
      for (const id of ['btn-open', 'btn-continue', 'btn-start']) {
        const b = $(id);
        if (b && !b.hidden && b.offsetParent !== null) { b.click(); break; }
      }
    }
  });
}

boot().catch((err) => {
  document.body.innerHTML = `<pre style="padding:24px;font:14px/1.6 monospace">
FOOTFALL could not start.

${err.message}

If you opened this file directly, run tools/bundle-data.mjs first,
or serve the repository over http.</pre>`;
});
