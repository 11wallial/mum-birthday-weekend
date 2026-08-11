// The trading day, customer by customer.
//
// Section 2 says customers enter one at a time, walk an aisle, and every
// fixture they pass fires in path order. That is what happens here — this is
// not an animation of an aggregate result, it is the actual resolution, using
// the same walker verify.js checks the aggregate resolver against.
//
// The projection panel shows the aggregate expectation. This is the roll around
// it. That split is the game: you plan against a number and then trade the day.

import {
  baseMarginFor, collectFlags, resolveDay, walkIndividual,
} from './engine.js';

export const PHASE = { WALKING: 'walking', QUEUE: 'queue', DONE: 'done', LOST: 'lost' };

export function createTradingDay(content, shop, ctx, rng) {
  // One aggregate resolution up front: it gives the authoritative Footfall and
  // the projection the player was shown, and costs one day-sim.
  const projection = resolveDay(content, shop, { ...ctx, sampleRng: null });
  const flags = collectFlags(content, shop, ctx);
  const baseMargin = baseMarginFor(content, shop, shop.saleOn);

  const ticks = content.economy.day.ticks;
  const openAisles = shop.aisles
    .map((a, i) => i)
    .filter((i) => !shop.aisles[i].closed && i !== flags.closedAisle);
  if (!openAisles.length) openAisles.push(0);

  const footfall = Math.max(0, Math.round(projection.footfall));
  const traversals = shop.flags.traversals || 1;

  // Who turns up is a draw, not a quota.
  const pool = shop.pool;
  const entries = content.types
    .map((t) => [t, pool[t.id] || 0])
    .filter(([, w]) => w > 0);

  const walkTicks = Math.max(1, content.economy.day.walkTicksPerSlot
    * Math.max(...openAisles.map((a) => shop.aisles[a].slots.length)));

  const micro = content.economy.micro;
  const triageBudget = micro && micro.triage
    ? Math.max(micro.triage.floor, footfall * micro.triage.fractionOfFootfall)
    : 0;

  const state = {
    tick: 0,
    ticks,
    projection,
    footfall,
    openAisles,
    customers: [],
    queue: [],
    served: 0,
    sales: 0,
    revenue: 0,
    tradingProfit: 0,
    salesByType: Object.create(null),
    shrink: 0,
    walkouts: 0,
    triageLeft: Math.round(triageBudget),
    triageUsed: 0,
    rescued: 0,
    finished: false,
    // Frenzy: customers processed per second, normalised. Drives audio and the
    // visual escalation from one parameter (section 35).
    frenzy: 0,
    recentServed: [],
  };

  // Spawn schedule: uniform arrivals across the day.
  const spawns = [];
  for (let n = 0; n < footfall * traversals; n++) {
    const type = rng.weighted(entries);
    spawns.push({ type, at: Math.floor((n / Math.max(1, footfall * traversals)) * ticks) });
  }
  spawns.sort((a, b) => a.at - b.at);
  let spawnIdx = 0;

  let nextId = 1;

  function admit(type) {
    // Security and Security Tag act before anyone reaches the floor.
    let t = type;
    if (t.special === 'steals') {
      if (flags.blockShoplifters) return null;
      if (flags.shoplifterBecomes) {
        t = content.typeById.get(flags.shoplifterBecomes) || t;
      } else {
        state.shrink += t.basket; // a flat loss, and they never queue
        return null;
      }
    }
    let aisle = shop.signage[t.id];
    if (aisle == null || !openAisles.includes(aisle)) aisle = openAisles[0];
    if (t.routing === 'random') aisle = openAisles[rng.int(openAisles.length)];

    const fired = [];
    const r = walkIndividual(content, shop, aisle, t, flags, baseMargin, rng,
      (slot) => fired.push({ slot, at: 0 }));

    return {
      id: nextId++,
      type: t,
      aisle,
      terms: r.terms,
      fired,
      phase: PHASE.WALKING,
      progress: 0,
      waited: 0,
      patience: Math.max(1, r.terms.patience),
      lane: openAisles.indexOf(aisle),
    };
  }

  function sell(c) {
    state.served++;
    state.recentServed.push(state.tick);
    const buys = rng() < c.terms.conversion;
    if (buys) {
      state.sales++;
      state.salesByType[c.type.id] = (state.salesByType[c.type.id] || 0) + 1;
      state.revenue += c.terms.basket;
      state.tradingProfit += c.terms.basket * c.terms.margin;
    }
    c.bought = buys;
    c.phase = PHASE.DONE;
    c.exitAt = state.tick;
    return buys;
  }

  /** Pull one queued customer straight to the till. The whole micro decision. */
  function triage(id) {
    if (state.triageLeft <= 0) return false;
    const i = state.queue.findIndex((c) => c.id === id);
    if (i < 0) return false;
    const [c] = state.queue.splice(i, 1);
    state.triageLeft--;
    state.triageUsed++;
    state.rescued++;
    sell(c);
    return true;
  }

  function step() {
    if (state.finished) return;
    const t = state.tick;

    while (spawnIdx < spawns.length && spawns[spawnIdx].at <= t) {
      const c = admit(spawns[spawnIdx].type);
      spawnIdx++;
      if (c) state.customers.push(c);
    }

    for (const c of state.customers) {
      if (c.phase !== PHASE.WALKING) continue;
      c.progress += 1 / walkTicks;
      if (c.progress >= 1) {
        c.progress = 1;
        c.phase = PHASE.QUEUE;
        c.joinedAt = t;
        state.queue.push(c);
      }
    }

    // Patience drains while waiting; at zero it is a walkout.
    for (let i = state.queue.length - 1; i >= 0; i--) {
      const c = state.queue[i];
      c.waited = t - c.joinedAt;
      if (c.waited > c.patience) {
        state.queue.splice(i, 1);
        c.phase = PHASE.LOST;
        c.exitAt = t;
        state.walkouts++;
      }
    }

    let capacity = (shop.tills + flags.tillDelta) * content.economy.day.tillRate
      + flags.throughputBonus;
    capacity = Math.min(capacity, flags.throughputCap);
    let budget = Math.max(0, capacity);
    while (budget >= 1 && state.queue.length) {
      sell(state.queue.shift());
      budget--;
    }

    // Frenzy from throughput over the last stretch of the day.
    const window = 12;
    state.recentServed = state.recentServed.filter((x) => x > t - window);
    state.frenzy = Math.min(1, state.recentServed.length / (window * 2.5));

    state.tick++;
    if (state.tick > ticks && !state.queue.length
        && !state.customers.some((c) => c.phase === PHASE.WALKING)) {
      finish();
    }
  }

  function finish() {
    if (state.finished) return;
    // Anyone still holding at close leaves.
    for (const c of state.queue) {
      c.phase = PHASE.LOST;
      state.walkouts++;
    }
    state.queue.length = 0;
    state.finished = true;

    const rent = projection.rent;
    const upkeep = (shop.marketingUpkeep || 0);
    const refunds = (flags.refundShare || 0) * Math.max(0, shop.lastTradingProfit || 0);
    state.rent = rent;
    state.upkeep = upkeep;
    state.refunds = refunds;
    state.profit = state.tradingProfit + state.shrink - refunds - rent - upkeep
      - (projection.ratchetUpkeep || 0);
    state.ratchetUpkeep = projection.ratchetUpkeep || 0;

    // Tomorrow's Footfall carry, same rules as the resolver: a SHARE of today,
    // never an absolute count. See the note in sim/day.js — Footfall is a
    // product built up from a base of about 120, so an absolute carry taken
    // from post-multiplier quantities can wipe the base out entirely.
    const w = content.economy.walkouts;
    const unsold = state.served - state.sales;
    const denom = Math.max(1, footfall);
    const share = state.walkouts / denom;
    const healthy = w.healthyWalkoutShare ?? 0;
    let carry = share > healthy
      ? 1 - Math.min(w.maxPenaltyShare ?? 1, (share - healthy) * w.footfallPenaltyPerWalkout)
      : 1 + (w.recoverPerDay ?? 0);
    if (flags.unsoldToFootfall > 0) carry += (unsold / denom) * flags.unsoldToFootfall;
    if (flags.walkoutsToFootfall) carry += share;
    carry = Math.max(w.minCarryMul ?? 0.05,
      Math.min(w.maxCarryMul ?? 1.6, (shop.carryFootfallMul ?? 1) * carry));
    state.rateMul = flags.ratchetRateMul || 1;
    state.carry = carry;
    state.avgSaleProfit = state.sales > 0 ? state.tradingProfit / state.sales : 0;
  }

  return { state, step, triage, finish, flags, walkTicks };
}
