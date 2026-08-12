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

  // Who turns up is a draw, not a quota — and it is the same pool the resolver
  // drew from. The Car Dealership's forced all-Luxury pool was applied in
  // day.js and ignored here, so the browser build was sending it families and
  // shoplifters while the panel promised nothing but Luxury.
  const pool = flags.poolOverride || shop.flags.forcedPool || shop.pool;
  const entries = content.types
    .map((t) => [t, pool[t.id] || 0])
    .filter(([, w]) => w > 0);

  const walkTicks = Math.max(1, content.economy.day.walkTicksPerSlot
    * Math.max(...openAisles.map((a) => shop.aisles[a].slots.length)));

  const arrivals = footfall * traversals;
  const maxWalkers = content.economy.day.maxWalkers || Infinity;
  const spawnCount = Math.max(1, Math.min(Math.round(arrivals), maxWalkers));
  const weight = arrivals / spawnCount;

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
    triageLeft: Math.max(1, Math.round(triageBudget / weight)),
    triageUsed: 0,
    rescued: 0,
    finished: false,
    // Frenzy: customers processed per second, normalised. Drives audio and the
    // visual escalation from one parameter (section 35).
    frenzy: 0,
    recentServed: [],
    // How many people each sprite stands for. 1 below the sampling threshold.
    walkerWeight: weight,
    walkers: spawnCount,
  };

  // Spawn schedule: uniform arrivals across the day.
  //
  // Above a threshold the walk becomes a weighted SAMPLE. A shop pulling
  // 80,000 people cannot draw 80,000 sprites, and it should not try: the
  // arithmetic of the day is settled by the aggregate resolver either way, and
  // the walk exists so the player can read the shop and reach into the queue.
  // Each walker then stands for `weight` people and every total they touch —
  // served, sales, revenue, walkouts — is counted in those units, so the day
  // still adds up. Throughput and the triage budget are already quoted per
  // tick against Footfall, so they scale with it untouched.
  const openFor = Math.max(1, ticks - walkTicks);
  const spawns = [];
  for (let n = 0; n < spawnCount; n++) {
    const type = rng.weighted(entries);
    spawns.push({ type, at: Math.floor((n / spawnCount) * openFor) });
  }
  spawns.sort((a, b) => a.at - b.at);
  let spawnIdx = 0;

  let nextId = 1;
  let tillCredit = 0;

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
    state.served += weight;
    state.recentServed.push(state.tick);
    const buys = rng() < c.terms.conversion;
    if (buys) {
      state.sales += weight;
      state.salesByType[c.type.id] = (state.salesByType[c.type.id] || 0) + weight;
      state.revenue += c.terms.basket * weight;
      state.tradingProfit += c.terms.basket * c.terms.margin * weight;
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
    state.rescued += weight;
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
        state.walkouts += weight;
      }
    }

    let capacity = (shop.tills + flags.tillDelta) * content.economy.day.tillRate
      + flags.throughputBonus;
    capacity = Math.min(capacity, flags.throughputCap);
    // Till capacity accrues as a credit rather than being spent within the
    // tick. One sprite costs `weight` people of it, and weight can be larger
    // than a whole tick's capacity — spend-within-the-tick would then never
    // clear the bar and the shop would serve nobody at all.
    tillCredit += Math.max(0, capacity);
    while (tillCredit >= weight && state.queue.length) {
      sell(state.queue.shift());
      tillCredit -= weight;
    }
    // An idle till is idle time lost, not time saved: the credit banked during
    // the fifteen ticks it takes the first customers to cross the floor must
    // not be spendable later, or the day serves a full 180 ticks' worth where
    // the resolver serves 165. Only while the queue is EMPTY, though — one
    // sprite can cost more than a whole tick's capacity, and capping then
    // throws away throughput the shop really has.
    if (!state.queue.length) tillCredit = Math.min(tillCredit, Math.max(0, capacity));

    // Frenzy from throughput over the last stretch of the day.
    const window = 12;
    state.recentServed = state.recentServed.filter((x) => x > t - window);
    state.frenzy = Math.min(1, state.recentServed.length / (window * 2.5));

    state.tick++;
    // The shop closes at closing time. Anyone still walking or still holding
    // in the queue has not bought anything, and finish() counts them.
    if (state.tick > ticks) finish();
  }

  function finish() {
    if (state.finished) return;
    // Anyone still holding at close leaves, and so does anyone still crossing
    // the floor towards a till that is about to shut.
    for (const c of state.queue) {
      c.phase = PHASE.LOST;
      state.walkouts += weight;
    }
    state.queue.length = 0;
    for (const c of state.customers) {
      if (c.phase !== PHASE.WALKING) continue;
      c.phase = PHASE.LOST;
      state.walkouts += weight;
    }
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
    let carry = share > (w.healthyWalkoutShare ?? 0)
      ? (w.allowedOverload ?? 1.6) * Math.max(0, 1 - share)
      : 1 + (w.recoverPerDay ?? 0);
    if (flags.unsoldToFootfall > 0) carry += (unsold / denom) * flags.unsoldToFootfall;
    if (flags.walkoutsToFootfall) carry += share;
    carry = Math.min(1 + (w.recoverPerDay ?? 0), Math.max(w.minDailyCarry ?? 0.25, carry));
    carry = Math.min((shop.carryFootfallMul ?? 1) * carry, w.maxCarryMul ?? 1.6);
    state.rateMul = flags.ratchetRateMul || 1;
    state.carry = carry;
    state.avgSaleProfit = state.sales > 0 ? state.tradingProfit / state.sales : 0;
  }

  return { state, step, triage, finish, flags, walkTicks };
}
