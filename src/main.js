// Wiring: the night catalogue, the trading day, the receipt.

import {
  auditModifiers, buildContent, emptySlots, findInstance, fixtureInstances,
  isRatchet, loadRawData, ownedIds, ratchetCount, ratchetUpkeepOf,
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
let landed = null; // the slot a fixture just went into, so it can land
let bossHeard = false; // the inspection stab fires once a night, not per render

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
  $('vlabel').textContent = 'Today looks like';
  // Rolling, not snapping. A figure that snaps has to be re-read; one that
  // rolls tells you which way it moved without being read at all.
  roll($('p-footfall'), p.footfall, (v) => Math.round(v).toLocaleString('en-GB'));
  roll($('p-conv'), p.conversion, (v) => pct(v));
  roll($('p-basket'), p.basket, money);
  roll($('p-margin'), p.margin, (v) => pct(v));
  roll($('p-trading'), p.trading, money);
  // Which term did that decision actually move? The card says "×1.42 Basket"
  // and the panel silently becomes a different number; marking the term that
  // changed is what joins the two, and it is the whole reason the formula is
  // on screen at all.
  markMovedTerms({
    'p-footfall': p.footfall,
    'p-conv': p.conversion,
    'p-basket': p.basket,
    'p-margin': p.margin,
  });
  showCosts(p.rent, -p.shrink, p.upkeep + (d.ratchetUpkeep || 0));
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

const lastTerms = new Map();

/** Flash the terms whose value moved since the panel last rendered. */
function markMovedTerms(values) {
  for (const [id, v] of Object.entries(values)) {
    const el = $(id);
    const was = lastTerms.get(id);
    lastTerms.set(id, v);
    if (was === undefined || Math.abs(v - was) < 1e-9) continue;
    const term = el.parentElement;
    term.classList.remove('moved', 'moved-down');
    void term.offsetWidth;
    term.classList.add(v > was ? 'moved' : 'moved-down');
  }
}

/**
 * The three costs, with the one that is hurting you marked.
 *
 * They were set identically, which on a day where theft takes £243 out of £245
 * of takings reads exactly like a day where it takes nothing. The biggest of
 * the three is the one the night's decision should be about, so it says so.
 */
function showCosts(rent, shrink, upkeep) {
  const worst = Math.max(rent, shrink, upkeep);
  const set = (id, label, v) => {
    const el = $(id);
    el.textContent = `${label} ${money(-v)}`;
    el.classList.toggle('worst', v > 0 && v === worst);
  };
  set('p-rent', 'rent', rent);
  set('p-shrink', 'shrink', shrink);
  set('p-upkeep', 'upkeep', upkeep);
}

/**
 * The same panel, but reporting instead of predicting.
 *
 * Left alone it went on showing the morning's projection while the receipt
 * beside it showed a different number — the screen contradicted itself at the
 * exact moment the player is checking their working. It shows what actually
 * happened, in the same four terms, so the plan and the outcome can be read
 * against each other in one place.
 */
function renderPanelActual(s, target) {
  const conv = s.served > 0 ? s.sales / s.served : 0;
  const basket = s.sales > 0 ? s.revenue / s.sales : 0;
  const margin = s.revenue > 0 ? s.tradingProfit / s.revenue : 0;
  $('vlabel').textContent = 'Today came in at';
  roll($('p-footfall'), s.footfall, (v) => Math.round(v).toLocaleString('en-GB'));
  roll($('p-conv'), conv, (v) => pct(v));
  roll($('p-basket'), basket, money);
  roll($('p-margin'), margin, (v) => pct(v));
  roll($('p-trading'), s.tradingProfit, money);
  showCosts(s.rent, -s.shrink, s.upkeep + s.ratchetUpkeep);
  const gap = s.profit - target;
  const short = gap < 0;
  const pel = $('p-profit');
  roll(pel, s.profit, money, 520);
  pel.className = `vprofit ${short ? 'short' : 'clear'}`;
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
  const away = next ? next.encounter - run.encounter : 0;
  $('l-boss').innerHTML = b
    ? `<span class="boss-flag">${b.name} — today</span>`
    : next
      ? `<span class="chip warn">${next.boss.name} <b>in ${away} day${away === 1 ? '' : 's'}</b></span>`
      : '';
}

// --------------------------------------------------------------- night ----

function renderOffers() {
  const wrap = $('offers');
  wrap.innerHTML = '';
  for (const def of game.run.offers) {
    const owned = findInstance(game.shop, def.id);
    const lvl = owned ? Math.min(3, owned.inst.level + 1) : 1;
    const el = document.createElement('div');
    // Once the pick is made, the page becomes a record of what you chose —
    // the one you took is stamped ORDERED and the rest go quiet. Dimming all
    // four equally made the whole screen read as broken rather than settled.
    const taken = game.run.pickedId === def.id;
    el.className = `entry r-${def.rarity}${game.run.picked ? (taken ? ' ordered' : ' passed') : ''}`;
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
      ${taken ? '<div class="ordered-stamp">Ordered</div>' : ''}
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

// ------------------------------------------------------------- inspection ----
// A placed fixture was a name and a term word in a 62px box. Everything that
// made it worth taking — what it does, what it needs beside it, what it has
// grown into, what it is costing you — was on a catalogue card that no longer
// exists. So the back half of the run asked the player to choose what to scrap
// from four names they could not read.

/** How much a growing fixture has actually put on, in the term's own units. */
function grownText(inst) {
  const r = inst.ratchet || 0;
  if (!isRatchet(inst.def) || r === 0) return '';
  const term = TERM_WORD[inst.def.term] || '';
  const op = inst.def.effect.op;
  if (op === 'ratchet') {
    const v = inst.def.term === 'basket' ? money(r)
      : inst.def.term === 'footfall' ? Math.round(r).toLocaleString('en-GB')
        : `${(r * 100).toFixed(1)}pp`;
    return `Grown to <b>+${v} ${term}</b> in ${inst.age} day${inst.age === 1 ? '' : 's'}`;
  }
  return `Running at <b>×${(1 + r).toFixed(2)} ${term}</b> after ${inst.age} day${inst.age === 1 ? '' : 's'}`;
}

/** The catalogue entry for something you already own, plus what it became. */
function inspectHtml(inst, aisle, slot, replacing) {
  const def = inst.def;
  const cond = conditionText(def);
  const target = game.target(game.run.encounter);
  const up = ratchetUpkeepOf(content, game.shop, target, inst);
  const bits = [];
  const grown = grownText(inst);
  if (grown) bits.push(`<div class="grown">${grown}</div>`);
  if (up > 0) {
    bits.push(`<div class="cost">Upkeep <b>${money(up)}</b> a day, and it climbs with the target</div>`);
  }
  if (inst.staff) bits.push(`<div class="cost">Staffed — ${inst.staff}</div>`);
  return `
    <div class="ihead">
      <div class="iname">${def.name}${inst.level > 1 ? ` <span class="ilv">L${inst.level}</span>` : ''}</div>
      <div class="iwhere">Aisle ${aisle + 1}, slot ${slot + 1} &middot; ${stockCode(def.id)}</div>
    </div>
    <div class="ieff">${describe(def, inst.level)}</div>
    ${cond ? `<div class="icond">${cond}</div>` : ''}
    ${bits.join('')}
    ${replacing
    ? `<div class="iact">
         <button class="ghost danger" id="i-yes">Scrap it for ${replacing.name}</button>
         <button class="ghost" id="i-no">Keep it</button>
       </div>`
    : '<div class="iact"><button class="ghost" id="i-no">Close</button></div>'}`;
}

/** Anchor the card to the slot it describes, clamped inside the window. */
function showInspect(inst, aisle, slot, anchor, replacing) {
  const el = $('inspect');
  el.innerHTML = inspectHtml(inst, aisle, slot, replacing);
  el.hidden = false;
  const r = anchor.getBoundingClientRect();
  const b = el.getBoundingClientRect();
  const x = Math.max(8, Math.min(window.innerWidth - b.width - 8, r.left + r.width / 2 - b.width / 2));
  const above = r.bottom + b.height + 12 > window.innerHeight && r.top - b.height - 8 > 0;
  el.style.left = `${x}px`;
  el.style.top = `${above ? r.top - b.height - 8 : r.bottom + 8}px`;
  const no = $('i-no');
  if (no) no.onclick = closeInspect;
  const yes = $('i-yes');
  if (yes) {
    yes.onclick = () => {
      closeInspect();
      game.take(pending.id, { aisle, slot });
      audio.place();
      pending = null;
      $('place-hint').textContent = '';
      renderNight();
    };
  }
}

function closeInspect() { $('inspect').hidden = true; }

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
           ${inst.staff ? `<div class="st">${inst.staff[0].toUpperCase()}</div>` : ''}
           ${isRatchet(inst.def) ? '<div class="gr">▲</div>' : ''}`
        : '<div class="tm">empty</div>';
      cell.title = inst ? `${inst.def.name} — ${describe(inst.def, inst.level)}` : '';
      cell.onclick = () => {
        closeInspect();
        // Scrapping is permanent, it happens on a single click, and until now
        // it happened with no statement of what was being destroyed. Read it
        // first, then decide.
        if (inst) { showInspect(inst, ai, si, cell, takeable ? pending : null); return; }
        if (!takeable) return;
        game.take(pending.id, { aisle: ai, slot: si });
        audio.place();
        pending = null;
        $('place-hint').textContent = '';
        landed = { aisle: ai, slot: si };
        renderNight();
      };
      // The slot a fixture just went into lands rather than blinking. The
      // animation existed; nothing ever added the class that fired it.
      if (landed && landed.aisle === ai && landed.slot === si) {
        cell.classList.add('landed');
        landed = null;
      }
      row.appendChild(cell);
    });
    wrap.appendChild(row);
  });
}

/**
 * Shopfitting, in four departments.
 *
 * It was one flat run of buttons — tills, floorspace, staff and marketing all
 * the same shape in one grid, so the page gave no help at all with the actual
 * question, which is what KIND of thing this cash should become. Four headed
 * groups, in the order they matter, and an unaffordable line says what it is
 * short by rather than just going grey.
 */
function renderBuys() {
  const { shop } = game;
  const wrap = $('buys');
  wrap.innerHTML = '';
  let group = null;
  const dept = (name) => {
    const h = document.createElement('h3');
    h.className = 'dept';
    h.textContent = name;
    wrap.appendChild(h);
    group = document.createElement('div');
    group.className = 'deptrow';
    wrap.appendChild(group);
  };
  const add = (label, opt, note) => {
    const cost = game.costOf(opt);
    if (!Number.isFinite(cost)) return;
    const b = document.createElement('button');
    const short = shop.cash < cost;
    b.className = `buy${short ? ' short' : ''}`;
    b.innerHTML = `<span class="n">${label}${note ? `<br><span class="code">${note}</span>` : ''}</span>
                   <span class="c">${cost === 0 ? '—' : money(cost)}</span>`;
    b.disabled = short;
    // A grey button says no. It does not say how much more you need, which is
    // the whole of the decision about whether to take the cash tonight.
    if (short) b.title = `${money(cost - shop.cash)} short`;
    b.onclick = () => { if (game.buy(opt)) { audio.place(); renderNight(); } };
    group.appendChild(b);
  };

  dept('Throughput');
  add('Extra till', 'till', 'more served per tick');
  if (shop.supplierTier < 5) add(`Supplier Tier ${shop.supplierTier + 1}`, 'tier', 'better catalogue, free pick');

  dept('Floorspace');
  for (const s of content.economy.structural) {
    if (s.id === 'extra_till') continue;
    if (!s.repeatable && shop.structural.has(s.id)) continue;
    add(s.name, `struct:${s.id}`);
  }

  dept('Staff');
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
    dept('Marketing');
    for (const c of content.campaigns) {
      if (shop.marketing.includes(c.id)) continue;
      add(c.name, `marketing:${c.id}`, `upkeep ${money(c.upkeep)}/day`);
    }
  }
  // An empty department is a heading with nothing under it.
  for (const row of wrap.querySelectorAll('.deptrow')) {
    if (!row.children.length) { row.previousElementSibling.remove(); row.remove(); }
  }
  // What you have to spend, where you spend it. It was in the ledger, at the
  // top of a different part of the screen.
  const affordable = wrap.querySelectorAll('.buy:not(:disabled)').length;
  $('purse').innerHTML = `<b class="money">${money(shop.cash)}</b> to spend &middot; `
    + (affordable ? `${affordable} within reach` : 'nothing within reach yet');
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

/**
 * What is landing on you today, and what it will do.
 *
 * The ledger named the inspection and stopped there, and you cannot plan
 * against a name — the whole point of a boss is that you rebuild the night
 * around it, which needs the effect stated at the moment you are choosing.
 */
function renderBossToday() {
  const b = game.boss();
  const next = game.nextBoss();
  const el = $('bosstoday');
  el.hidden = !b && !next;
  if (el.hidden) return;
  if (b) {
    el.className = 'today';
    el.innerHTML = `<span class="bt-when">Today</span>
      <span class="bt-name">${b.name}</span>
      <span class="bt-eff">${bossText(b)}</span>`;
  } else {
    const away = next.encounter - game.run.encounter;
    el.className = 'soon';
    el.innerHTML = `<span class="bt-when">In ${away} day${away === 1 ? '' : 's'}</span>
      <span class="bt-name">${next.boss.name}</span>
      <span class="bt-eff">${bossText(next.boss)}</span>`;
  }
}

function renderNight() {
  renderLedger();
  renderPanel();
  renderOffers();
  renderFloorplan();
  renderBuys();
  renderBossChoice();
  renderBossToday();
  if (game.boss() && !bossHeard) { bossHeard = true; audio.boss(); }
  $('cat-tier').textContent = `Tier ${game.shop.supplierTier}`;
  const ready = game.run.picked && !game.run.pendingBossChoice;
  const open = $('btn-open');
  open.hidden = false;
  open.disabled = !ready;
  // The panel has said all night that today does not clear, and then the
  // button that commits you to it looked exactly like the button on a day you
  // were winning. It is the last moment anything can be changed, so it says so.
  const gap = game.projection().profit - game.target(game.run.encounter);
  const doomed = ready && gap < 0;
  open.classList.toggle('danger', doomed);
  open.innerHTML = doomed
    ? `Open the doors <em>${money(-gap)} short</em>`
    : 'Open the doors';
  $('tip').textContent = pending
    ? 'Pick a slot. An additive bump placed before a multiplier gets multiplied.'
    : game.run.pendingBossChoice ? 'Choose which day is coming.'
      : doomed ? 'As it stands this is a losing day. Spend, re-place, or open anyway.'
        : ready ? 'Doors when you are ready.' : 'Take one from the catalogue.';
}

// ----------------------------------------------------------------- day ----

function openDoors() {
  audio.unlock();
  audio.tannoy();
  particles = createParticles();
  setPaused(false);
  // Once the doors are open the panel is a record of the plan, not a live
  // reading — the day bar is the live reading. Saying so stops the two
  // disagreeing in a way that looks like a bug.
  showWiped('day', () => {
    $('vlabel').textContent = 'Today was planned at';
    // Restart the shutter: an element that is already in the DOM will not
    // replay its animation without being taken out of the flow first.
    const sh = $('shutter');
    sh.hidden = true;
    void sh.offsetWidth;
    sh.hidden = false;
    maybeCoach('day');
  });
  day = createTradingDay(content, game.shop, game.ctx(), game.run.rng);
  $('btn-open').hidden = true;
  $('tip').textContent = 'Tap anyone waiting to take them next. Tap anybody to see who they are.';
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
    const st = day.state;
    const through = Math.min(1, st.tick / st.ticks);
    $('d-clock').textContent = shopClock(through);
    $('d-prog').style.width = `${through * 100}%`;
    roll($('d-sales'), st.sales, n, 300);
    roll($('d-walk'), st.walkouts, n, 300);
    // Takings is what went through the till. Theft is a separate line, because
    // netting the two produced a "takings" figure that could read negative on
    // a day the shop was busy — which is not what the word means.
    roll($('d-profit'), st.tradingProfit, money, 300);
    $('d-shrinkrow').hidden = st.shrink >= 0;
    if (st.shrink < 0) roll($('d-shrink'), -st.shrink, money, 300);
    // What the day is going to come to if it carries on like this. Without it
    // the player watches a takings figure climb with no way to know whether it
    // is climbing fast enough, which is the only question the day poses.
    const pel = $('d-pace');
    const fixed = (st.projection.rent || 0) + (st.projection.ratchetUpkeep || 0)
      + (game.shop.marketingUpkeep || 0);
    const raw = (st.tradingProfit + st.shrink) / Math.max(0.02, through) - fixed;
    // Blended out of the morning's plan rather than extrapolated from nothing.
    // Six sales at ten past ten extrapolate to numbers that swing by thousands
    // between frames, which is not a reading — it is noise wearing a label.
    const trust = Math.max(0, Math.min(1, (through - 0.14) / 0.34));
    const pace = st.projection.profit * (1 - trust) + raw * trust;
    const tgt = game.target(game.run.encounter);
    roll(pel, pace, money, 320);
    pel.className = pace < tgt ? 'short' : 'clear';
    $('d-triage').textContent = st.triageLeft;
    $('d-triage').parentElement.classList.toggle('spent', st.triageLeft <= 0);
    if (day.state.finished) { settle(); return; }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

/** Nine in the morning to half five, because "54% of the day" is not a time. */
function shopClock(through) {
  const mins = 9 * 60 + through * (17.5 * 60 - 9 * 60);
  const h = Math.floor(mins / 60);
  return `${h}:${String(Math.floor(mins % 60)).padStart(2, '0')}`;
}

function settle() {
  document.documentElement.style.setProperty('--frenzy', '0');
  audio.quiet();
  audio.receipt();
  const s = day.state;
  const entry = game.settle(s);
  // The cadence lands under the printer, so the verdict is heard a beat before
  // it is read.
  audio.verdict(!entry.fatal);
  // The target is only the fail condition. The number the run is remembered by
  // is the best day it ever had, and a good run overshoots its last target
  // fifty times over.
  if (s.profit > peakDay) peakDay = s.profit;
  showWiped('settle', () => { renderPanelActual(s, entry.target); maybeCoach('settle'); });
  $('tip').textContent = entry.fatal
    ? 'The landlord does not take instalments.'
    : 'Cash up, lock the door, order for tomorrow.';
  const row = (k, v, cls = '') => `<div class="r ${cls}"><span>${k}</span><span>${v}</span></div>`;
  const n = (v) => Math.round(v).toLocaleString('en-GB');
  const gap = s.profit - entry.target;
  const plan = s.profit - s.projection.profit;
  const ch = content.characterById.get(character);
  // A day's trading, printed off the till. The gap is the only number on it
  // that decides anything, so it is the only one set at size — the rest is
  // the working that produced it, in the order a till roll would print it.
  $('receipt').innerHTML = `
    <div class="rhead">
      <div class="rmast">FOOTFALL</div>
      <div class="rshop">${ch.name.toUpperCase()} &middot; NO. 24 HIGH STREET</div>
    </div>
    <div class="rmeta">
      <span>DAY ${entry.encounter}/${content.run.encounters}</span>
      <span>QUARTER ${game.shop.quarter}</span>
      <span>${game.shop.tills} TILL${game.shop.tills > 1 ? 'S' : ''}</span>
    </div>
    ${game.boss() ? `<div class="rboss">${game.boss().name.toUpperCase()}</div>` : ''}
    <div class="rule"></div>
    ${row('Through the door', n(s.footfall))}
    ${row('Served', n(s.served))}
    ${row('Sales', n(s.sales))}
    ${row('Walked out', n(s.walkouts) + (s.rescued ? ` (${n(s.rescued)} caught)` : ''))}
    <div class="rule"></div>
    ${row('Trading profit', money(s.tradingProfit))}
    ${row('Shrink', money(s.shrink))}
    ${s.refunds ? row('Refunds', money(-s.refunds)) : ''}
    ${row('Rent', money(-s.rent))}
    ${row('Upkeep', money(-(s.upkeep + s.ratchetUpkeep)))}
    <div class="rule"></div>
    ${row('PROFIT', money(s.profit), 'big')}
    ${row('Target', money(entry.target))}
    <div class="rgap ${entry.fatal ? 'fail' : 'pass'}">
      <i>${entry.fatal ? 'Short by' : 'Cleared by'}</i><b>${money(Math.abs(gap))}</b>
    </div>
    <div class="rplan">You planned ${money(s.projection.profit)} &mdash;
      ${Math.abs(plan) < 1 ? 'called it exactly'
    : `the day came in ${money(Math.abs(plan))} ${plan > 0 ? 'over' : 'under'}`}</div>
    ${entry.interest ? row('Interest earned', money(entry.interest)) : ''}
    <div class="stampline">
      <span class="rstamp ${entry.fatal ? 'fail' : 'pass'}">
        ${entry.fatal ? 'Closing down' : 'Target met'}</span>
    </div>
    <div class="rfoot">
      <div class="barcode"></div>
      ${entry.fatal ? 'NO REFUNDS &middot; NO EXCHANGES' : 'THANK YOU &middot; PLEASE CALL AGAIN'}
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
  closeInspect();
  // The tune never stops or restarts; the mix moves. Doing it here means every
  // route into a phase gets it, including the ones that skip showWiped.
  if (audio) audio.setPhase(which);
  for (const id of ['title', 'night', 'day', 'settle']) $(id).hidden = id !== which;
  $('btn-open').hidden = which !== 'night';
  $('btn-continue').hidden = which !== 'settle';
  $('btn-start').hidden = which !== 'title';
  $('tip').textContent = which === 'title' ? 'Pick a shop and an audit, then open up.' : '';
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
  bossHeard = false;
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

  $('receipt').innerHTML = `
    <div class="rhead">
      <div class="rmast">${won ? 'Eight quarters' : 'Closing down'}</div>
      <div class="rshop">${ch.name.toUpperCase()} &middot; AUDIT ${roman(audit)}</div>
    </div>
    <div class="headline ${won ? 'pass' : 'fail'}">${money(peakDay)}</div>
    <div class="sub">best day&rsquo;s profit${outcome.record ? ' &mdash; a personal record' : ''}</div>
    ${outcome.unlocked ? `<div class="unlock">Audit ${roman(outcome.unlocked)} unlocked</div>` : ''}
    <div class="rule"></div>
    <div class="r"><span>Days traded</span><span>${days} / ${content.run.encounters}</span></div>
    <div class="r"><span>Climb, first day to last</span><span>${climb >= 1 ? `&times;${Math.round(climb).toLocaleString('en-GB')}` : '&mdash;'}</span></div>
    <div class="r"><span>Banked</span><span>${money(game.shop.cash)}</span></div>
    <div class="r"><span>Seed</span><span>${game.run.seed}</span></div>
    <div class="rule"></div>
    ${game.run.log.slice(-5).map((e) => `<div class="r"><span>Day ${e.encounter}</span><span>${money(e.profit)} / ${money(e.target)}</span></div>`).join('')}
    <div class="build">${build.join(' &middot; ') || 'an empty shop'}</div>
    <div class="stampline">
      <span class="rstamp ${won ? 'pass' : 'fail'}">${won ? 'The shop survives' : `Ended day ${days}`}</span>
    </div>
    <div class="rfoot"><div class="barcode"></div>
      ${won ? 'TRADING CONTINUES' : 'FIXTURES &amp; FITTINGS TO BE SOLD'}</div>`;
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
    ? 'Paused. You can still take someone to the till, or tap anyone to see who they are.'
    : 'Tap anyone waiting to take them next. Tap anybody to see who they are.';
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

/**
 * The season ahead, drawn as the curve it is.
 *
 * A player choosing an Audit was choosing from a sentence — "targets ×1.15" —
 * with nothing to compare it against, and a player choosing a shop had no idea
 * what twenty-four days actually asks for. The curve multiplies, so day one
 * tells you nothing about day twenty-four; this shows both ends and the shape
 * between them, and it moves when the audit changes.
 */
function renderSeason() {
  const mods = auditModifiers(content, audit);
  const mul = mods.targetMultiplier || 1;
  const bossEvery = mods.bossEvery || content.run.bossEvery;
  const total = content.run.encounters;
  const first = content.targets[0] * mul;
  const last = content.targets[total - 1] * mul;
  const lo = Math.log(first);
  const hi = Math.log(last);
  let bars = '';
  for (let e = 1; e <= total; e++) {
    const t = content.targets[e - 1] * mul;
    const hgt = Math.max(3, Math.round(((Math.log(t) - lo) / (hi - lo)) * 34) + 3);
    const q = e % content.run.daysPerQuarter === 1 && e > 1 ? ' qstart' : '';
    bars += `<i class="sbar${q}${e % bossEvery === 0 ? ' boss' : ''}"
      style="height:${hgt}px" title="Day ${e} — ${money(t)}"></i>`;
  }
  $('season').innerHTML = `
    <h2>The season <span class="hint">${content.run.quarters} quarters, ${total} trading days</span></h2>
    <div class="sbars">${bars}</div>
    <div class="sends">
      <span>Day 1 asks <b>${money(first)}</b></span>
      <span class="red">Day ${total} asks <b>${money(last)}</b></span>
    </div>
    <p class="snote">A target that multiplies by
      <b>×${(content.targets[1] / content.targets[0]).toFixed(2)}</b> a day, and an
      inspection every ${bossEvery === 1 ? 'day' : `${bossEvery} days`}. Flat cards
      cannot chase a curve; that is what the compounding lines are for.</p>`;
}

function renderTitle() {
  renderCharacters();
  renderAudits();
  renderSeason();
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
  // The rules sheet carries a slot for the customer legend, which is built
  // from the data rather than written out, so it can never drift from the
  // eight silhouettes the floor actually draws.
  const who = $('whoswho');
  if (who) who.innerHTML = whoHtml();
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
  one changes a rule permanently, and each shop climbs its own ladder.</p>

  <h4>Who comes in</h4>
  <p>Eight of them, each drawn differently on the floor. Some cards only fire
  for certain types, and some inspections only let certain types buy.</p>
  <div id="whoswho"></div>`;

// The colours the floor draws them in. Kept here rather than imported so the
// renderer stays a renderer.
const TYPE_INK = {
  family: '#d6206a', student: '#0aa3c2', pensioner: '#7a5cbf', trade: '#e07b1a',
  luxury: '#0f8a4a', tourist: '#f2b90c', browser: '#9a9086', shoplifter: '#2a2622',
};
const PATIENCE_WORD = {
  very_low: 'bolts', low: 'impatient', medium: 'will wait a bit',
  high: 'patient', very_high: 'will wait all day',
};

/**
 * The customer legend.
 *
 * The day draws eight silhouettes in eight colours and the game never once
 * said what any of them were — so a player watching a shop full of people had
 * no way to connect "Pensioners never convert" on a card to anybody on their
 * own floor.
 */
function whoHtml() {
  return content.types.map((t) => `
    <div class="who">
      <i style="background:${TYPE_INK[t.id] || '#8a8175'}"></i>
      <span class="wn">${t.name}</span>
      <span class="wd">${Math.round(t.conversion * 100)}% convert &middot;
        ${t.basket ? `${money(t.basket)} basket` : 'no basket'} &middot;
        ${PATIENCE_WORD[t.patience] || t.patience}</span>
      <span class="wnote">${t.note || ''}</span>
    </div>`).join('');
}

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

  // One continuous strip rather than eight rows of three. Broken into
  // quarters, every row restarted at the left and the climb — which is the
  // entire subject of the chart — was invisible. Log scale: the curve
  // multiplies by 1.24 for twenty-four steps, which is 140x end to end, and on
  // a linear axis day one is a hairline against a wall.
  const H = 118;
  const lo = Math.log(content.targets[0]);
  const hi = Math.log(maxTarget);
  const yOf = (v) => Math.max(7, Math.min(H, ((Math.log(Math.max(1, v)) - lo) / (hi - lo)) * H));
  let rows = '';
  for (let enc = 1; enc <= total; enc++) {
    const t = game.target(enc);
    const e = log.get(enc);
    // Every inspection day is marked, not only the ones whose landlord has
    // been dealt yet — the schedule is knowable from day one and hiding it
    // makes the run look arbitrary.
    const named = game.bossAt ? game.bossAt(enc) : null;
    const boss = named || enc % run.bossEvery === 0;
    const state = e ? (e.fatal ? 'lost' : 'won') : enc === run.encounter ? 'now' : 'todo';
    const qstart = enc > 1 && enc % per === 1 ? ' qstart' : '';
    const over = e && e.profit > maxTarget;
    rows += `<div class="rmday ${state}${qstart}"
      title="Day ${enc} — target ${money(t)}${e ? `, traded ${money(e.profit)}` : ''}${named ? ` — ${named.name}` : ''}">
      <span class="rmt" style="height:${yOf(t)}px"></span>
      ${e ? `<span class="rma ${e.fatal ? 'lost' : 'won'}" style="height:${yOf(e.profit)}px"></span>` : ''}
      ${over ? '<span class="rmover">&#9650;</span>' : ''}
      ${boss ? '<span class="rmboss"></span>' : ''}
      ${enc % 3 === 0 || enc === 1 ? `<span class="rmn">${enc}</span>` : ''}
    </div>`;
  }
  rows = `<div class="rmchart" style="height:${H}px">${rows}</div>`;

  // What you are actually holding, in walk order. The floorplan is only on the
  // night screen, so mid-day there was no way to answer "what have I got?".
  const target = game.target(run.encounter);
  let held = '';
  shop.aisles.forEach((aisle, ai) => {
    const rows = aisle.slots.map((inst, si) => {
      if (!inst) return `<div class="srow empty"><span>${si + 1}</span><span>&mdash;</span><span></span></div>`;
      const up = ratchetUpkeepOf(content, shop, target, inst);
      const grown = grownText(inst);
      return `<div class="srow">
        <span class="sn">${si + 1}</span>
        <span><b>${inst.def.name}${inst.level > 1 ? ` L${inst.level}` : ''}</b>
          <i>${describe(inst.def, inst.level)}</i>
          ${grown ? `<em>${grown}</em>` : ''}</span>
        <span class="su">${up > 0 ? money(up) : ''}</span>
      </div>`;
    }).join('');
    held += `<div class="saisle"><h5>Aisle ${ai + 1}${aisle.closed ? ' — closed' : ''}</h5>${rows}</div>`;
  });

  const cleared = save.clearedFor(character);
  return `<h3>The run</h3>
    <p>Twenty-four trading days in eight quarters. Every day sets a target and
    every third day the landlord sends someone. Miss once and that is the run.</p>
    <div class="mkey">
      <span><i class="sw todo"></i> the target</span>
      <span><i class="sw won"></i> what you traded</span>
      <span><i class="sw now"></i> today</span>
      <span><i class="sw boss"></i> inspection</span>
    </div>
    <div class="mmap">${rows}</div>
    <div class="mfoot"><span>Day 1 &mdash; ${money(content.targets[0] * (game.run.auditMods.targetMultiplier || 1))}</span>
      <span>Day ${total} &mdash; ${money(maxTarget)}</span></div>
    <h4>The shop as it stands</h4>
    <p class="sublead">Front to back, the order they fire in. The right-hand
    column is what that fixture charges you in upkeep today.</p>
    <div class="shoplist">${held}</div>
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
  lastTerms.clear();     // a new run is not a change to the last one
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
  // Sound was on the M key and nowhere else, which is not a control, it is a
  // secret.
  const showMute = (m) => {
    $('btn-mute').innerHTML = m ? '&#9834;&#8202;&#10005;' : '&#9835;';
    $('btn-mute').classList.toggle('off', m);
  };
  showMute(save.get().muted);
  $('btn-mute').onclick = () => showMute(save.setMuted(audio.toggleMute()));
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
    const hit = floor.pick(e.clientX - r.left, e.clientY - r.top);
    if (!hit) return;
    if (hit.queued && day.triage(hit.id)) { audio.triage(); return; }
    // Not servable, or out of triage: say who they are instead. Eight
    // silhouettes on the floor and eight names on the cards that single them
    // out, and until now nothing connected the two mid-day.
    const t = hit.type;
    $('tip').textContent = `${t.name} — ${Math.round(t.conversion * 100)}% convert, `
      + `${t.basket ? `${money(t.basket)} basket` : 'no basket'}, `
      + `${PATIENCE_WORD[t.patience] || t.patience}`;
  };
  // The first touch anywhere is the gesture the audio context is waiting for,
  // and every button press after it gets a click. Silence on a press reads as
  // a broken control.
  document.addEventListener('pointerdown', (e) => {
    audio.unlock();
    if (e.target instanceof Element && e.target.closest('button')) audio.ui();
  }, { capture: true });

  // Anywhere off the card closes it, except the slots themselves — those
  // re-open it on the thing you just clicked.
  document.addEventListener('click', (e) => {
    if ($('inspect').hidden) return;
    const t = e.target;
    if (t instanceof Element && (t.closest('#inspect') || t.closest('.slot'))) return;
    closeInspect();
  });
  window.addEventListener('keydown', (e) => {
    if (e.target && e.target.tagName === 'INPUT') return;
    if (e.key === 'm') showMute(save.setMuted(audio.toggleMute()));
    if (e.key === 'Escape') { $('sheet').hidden = true; closeInspect(); }
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
