// Wiring: the night catalogue, the trading day, the receipt.

import {
  buildContent, emptySlots, findInstance, fixtureInstances, loadRawData,
  ownedIds, ratchetCount,
} from './engine.js';
import { createRun } from './run.js';
import { createTradingDay } from './trading-day.js';
import { createFloorRenderer } from './floor.js';
import { createAudio } from './audio.js';

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
      return `Gains +${def.term === 'basket' ? `£${v}` : v} ${term} permanently, every trading day`;
    case 'rule': return ruleText(def, L);
    default: return '';
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
  $('p-footfall').textContent = p.footfall;
  $('p-conv').textContent = pct(p.conversion);
  $('p-basket').textContent = money(p.basket);
  $('p-margin').textContent = pct(p.margin);
  $('p-trading').textContent = money(p.trading);
  $('p-rent').textContent = `Rent ${money(-p.rent)}`;
  $('p-shrink').textContent = `Shrink ${money(p.shrink)}`;
  $('p-upkeep').textContent = `Upkeep ${money(-(p.upkeep + (d.ratchetUpkeep || 0)))}`;
  $('p-profit').textContent = `Profit ${money(d.profit)}`;
  const gap = d.profit - target;
  const el = $('p-gap');
  el.textContent = `Gap ${money(gap)}`;
  el.className = `gap ${gap < 0 ? 'short' : 'clear'}`;
}

function renderLedger() {
  const { shop, run } = game;
  $('l-quarter').textContent = `${shop.quarter} / 8`;
  $('l-day').textContent = `${run.encounter} / ${content.run.encounters}`;
  $('l-target').textContent = money(game.target(run.encounter));
  $('l-cash').textContent = money(shop.cash);
  $('l-tills').textContent = shop.tills;
  $('l-tier').textContent = `Tier ${shop.supplierTier}`;
  const b = game.boss();
  const next = game.nextBoss();
  $('l-boss').innerHTML = b
    ? `<span class="boss-flag">${b.name}</span>`
    : next ? `<span class="k">Coming, day ${next.encounter}</span><span class="v">${next.boss.name}</span>` : '';
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
    el.innerHTML = `
      <div><div class="name">${def.name}</div><div class="code">${stockCode(def.id)}</div></div>
      <div class="tier">${def.rarity}</div>
      <div class="eff">${describe(def, lvl)}${cond ? ` <span class="code">— ${cond}</span>` : ''}</div>
      <div class="copy">${def.class.replace('_', '-')}${def.tags && def.tags.length ? ` · ${def.tags.join(' · ')}` : ''}</div>
      ${owned ? `<div class="combine">You hold one — combines to L${lvl}</div>` : ''}`;
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
  $('place-hint').textContent = `Placing ${def.name} — pick a slot. Order matters.`;
  renderNight();
}

function renderFloorplan() {
  const wrap = $('aisles');
  wrap.innerHTML = '';
  game.shop.aisles.forEach((aisle, ai) => {
    const row = document.createElement('div');
    row.className = `aisle${aisle.closed ? ' closed' : ''}`;
    row.innerHTML = `<div class="lbl">Aisle ${ai + 1}</div>`;
    aisle.slots.forEach((inst, si) => {
      const cell = document.createElement('div');
      const free = !inst;
      cell.className = `slot${inst ? ' filled' : ''}${pending && free ? ' target' : ''}`;
      cell.innerHTML = inst
        ? `<div class="fx">${inst.def.name}</div><div class="tm">${TERM_WORD[inst.def.term] || '—'}</div>
           ${inst.level > 1 ? `<div class="lv">L${inst.level}</div>` : ''}
           ${inst.staff ? `<div class="st">${inst.staff[0].toUpperCase()}</div>` : ''}`
        : '<div class="tm">empty</div>';
      cell.onclick = () => {
        if (!pending || !free) return;
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
  show('day');
  day = createTradingDay(content, game.shop, game.ctx(), game.run.rng);
  $('btn-open').hidden = true;
  $('tip').textContent = 'Tap a waiting customer to serve them next.';
  let acc = 0;
  let last = performance.now();

  function frame(now) {
    const dt = Math.min(120, now - last);
    last = now;
    acc += dt;
    const msPerTick = 90 / speed;
    let guard = 0;
    while (acc >= msPerTick && !day.state.finished && guard++ < 40) {
      const before = day.state.sales;
      const beforeLost = day.state.walkouts;
      day.step();
      if (day.state.sales > before) audio.sale();
      if (day.state.walkouts > beforeLost) audio.walkout();
      acc -= msPerTick;
    }
    audio.setFrenzy(day.state.frenzy);
    document.documentElement.style.setProperty('--frenzy', day.state.frenzy.toFixed(2));
    floor.draw(day, game.shop);
    $('d-clock').textContent = `${Math.min(100, Math.round(day.state.tick / day.state.ticks * 100))}%`;
    $('d-sales').textContent = day.state.sales;
    $('d-walk').textContent = day.state.walkouts;
    $('d-profit').textContent = money(day.state.tradingProfit + day.state.shrink);
    $('d-triage').textContent = day.state.triageLeft;
    if (day.state.finished) { settle(); return; }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}

function settle() {
  document.documentElement.style.setProperty('--frenzy', '0');
  audio.setFrenzy(0);
  audio.receipt();
  const s = day.state;
  const entry = game.settle(s);
  show('settle');
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

function show(which) {
  for (const id of ['title', 'night', 'day', 'settle']) $(id).hidden = id !== which;
  $('btn-open').hidden = which !== 'night';
}

function nextEncounter() {
  if (game.run.over) return endRun();
  game.beginNight();
  if (game.run.over) return endRun();
  pending = null;
  show('night');
  renderNight();
}

function endRun() {
  show('settle');
  const won = game.run.won;
  const best = game.run.log.length;
  $('receipt').innerHTML = `<h3>${won ? 'EIGHT QUARTERS' : 'CLOSING DOWN'}</h3>
    <div class="rule"></div>
    <div class="r"><span>Days traded</span><span>${best}</span></div>
    <div class="r"><span>Seed</span><span>${game.run.seed}</span></div>
    <div class="rule"></div>
    ${game.run.log.slice(-6).map((e) => `<div class="r"><span>Day ${e.encounter}</span><span>${money(e.profit)} / ${money(e.target)}</span></div>`).join('')}
    <div class="verdict ${won ? 'pass' : 'fail'}">${won ? 'THE SHOP SURVIVES' : `IT ENDED ON DAY ${best}`}</div>`;
  $('btn-continue').textContent = 'Open another shop';
  $('btn-continue').onclick = () => location.reload();
}

function renderCharacters() {
  const wrap = $('charpick');
  wrap.innerHTML = '';
  for (const c of content.characters) {
    const b = document.createElement('button');
    b.className = `charbtn${c.id === character ? ' on' : ''}`;
    b.innerHTML = `<div class="cn">${c.name}</div><div class="cr">${c.rule}</div>`;
    b.onclick = () => { character = c.id; renderCharacters(); };
    wrap.appendChild(b);
  }
}

async function boot() {
  const raw = await loadRawData();
  content = buildContent(raw);
  audio = createAudio();
  floor = createFloorRenderer($('floor'));
  renderCharacters();

  $('btn-start').onclick = () => {
    audio.unlock();
    game = createRun(content, { characterId: character });
    nextEncounter();
  };
  $('btn-open').onclick = openDoors;
  $('btn-continue').onclick = () => nextEncounter();
  $('btn-reroll').onclick = () => { if (game.reroll()) { audio.place(); renderNight(); } };
  $('btn-skip').onclick = () => { if (game.skipPick()) { audio.sale(); renderNight(); } };
  $('btn-speed').onclick = () => {
    speed = speed === 1 ? 2 : speed === 2 ? 4 : 1;
    $('btn-speed').innerHTML = `&raquo; ${speed}&times;`;
  };
  $('floor').onclick = (e) => {
    if (!day || day.state.finished) return;
    const r = $('floor').getBoundingClientRect();
    const id = floor.pick(e.clientX - r.left, e.clientY - r.top);
    if (id && day.triage(id)) audio.triage();
  };
  window.addEventListener('keydown', (e) => {
    if (e.key === 'm') audio.toggleMute();
  });
}

boot().catch((err) => {
  document.body.innerHTML = `<pre style="padding:24px;font:14px/1.6 monospace">
FOOTFALL could not start.

${err.message}

If you opened this file directly, run tools/bundle-data.mjs first,
or serve the repository over http.</pre>`;
});
