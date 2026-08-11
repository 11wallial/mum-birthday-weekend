// Three decision policies. The gap between greedy and planner is the health
// check for the whole project (section 19): if greedy wins as often as planner,
// there is no skill expression in the design.
//
//   random   - no model of the game at all
//   greedy   - perfect play of today, no model of tomorrow
//   planner  - lookahead on term coverage, placement order, and tempo
//
// Both greedy and planner see the upcoming boss before they buy, because the
// game shows it. That is deliberate: reading the boss is skill, not luck.

import { resolveDay } from './day.js';
import {
  addFixture, autoSign, emptySlots, findInstance, fixtureInstances, ownedIds,
  projectRatchets, totalSlots,
} from './shop.js';
import { rerollCost, supplierUpgradeCost, tillCost } from './offers.js';

export function cloneShop(shop) {
  return {
    ...shop,
    aisles: shop.aisles.map((a) => ({
      ...a,
      slots: a.slots.map((i) => (i ? { ...i } : null)),
    })),
    staff: shop.staff.map((s) => ({ ...s })),
    bench: shop.bench.map((i) => ({ ...i })),
    pool: { ...shop.pool },
    structural: new Set(shop.structural),
    signage: { ...shop.signage },
    marketing: [...shop.marketing],
    history: shop.history,
  };
}

const profitOf = (content, shop, ctx) => resolveDay(content, shop, ctx).profit;

/**
 * Profit this shop would make `days` from now, if nothing else changed.
 * This is the whole point of the planner: a ratchet looks weak today and is
 * the best card in the pool by encounter 20. Greedy has no such method, which
 * is exactly the skill the design wants to reward.
 */
function profitAhead(content, shop, ctx, days) {
  const s = cloneShop(shop);
  projectRatchets(s, days);
  return resolveDay(content, s, { ...ctx, boss: null }).profit;
}

/** Candidate slots for a new fixture, cheapest-first and capped for speed. */
function candidateSlots(shop, limit) {
  const empty = emptySlots(shop);
  if (empty.length <= limit) return empty;
  const out = [];
  const step = empty.length / limit;
  for (let i = 0; i < limit; i++) out.push(empty[Math.floor(i * step)]);
  return out;
}

function placeAndScore(content, shop, ctx, fx, placement) {
  const s = cloneShop(shop);
  addFixture(content, s, fx.id, placement);
  return { profit: profitOf(content, s, ctx), placement };
}

/** Best placement for one offered fixture, judged on today alone. */
function bestPlacement(content, shop, ctx, fx, limit) {
  const owned = findInstance(shop, fx.id);
  if (owned) {
    // A duplicate combines; there is no placement decision to make.
    return placeAndScore(content, shop, ctx, fx, null);
  }
  const cands = candidateSlots(shop, limit);
  if (cands.length === 0) return placeAndScore(content, shop, ctx, fx, null);
  let best = null;
  for (const c of cands) {
    const r = placeAndScore(content, shop, ctx, fx, c);
    if (!best || r.profit > best.profit) best = r;
  }
  return best;
}

// ---------------------------------------------------------------------------

export const randomPolicy = {
  name: 'random',
  chooseBoss(content, shop, ctx, options) { return ctx.rng ? ctx.rng.int(options.length) : 0; },
  night(nc) {
    const { content, shop, rng } = nc;
    const fx = rng.pick(nc.offers);
    const empty = emptySlots(shop);
    const placement = empty.length ? rng.pick(empty) : null;
    nc.take(fx, placement);

    if (rng() < 0.25) {
      const options = [];
      if (shop.cash >= tillCost(content, shop)) options.push('till');
      if (shop.cash >= supplierUpgradeCost(content, shop, nc.ctx.auditMods)) options.push('tier');
      for (const st of content.economy.staff) {
        if (shop.cash >= 200) options.push(`staff:${st.id}`);
      }
      for (const s of content.economy.structural) {
        if (s.id !== 'extra_till' && shop.cash >= s.cost && !shop.structural.has(s.id)) {
          options.push(`struct:${s.id}`);
        }
      }
      if (options.length) nc.buy(rng.pick(options));
    }

    // Signage is free to reassign, so even a random player rerolls it.
    for (const t of content.types) {
      shop.signage[t.id] = rng.int(shop.aisles.length);
    }
  },
};

// ---------------------------------------------------------------------------

export const greedyPolicy = {
  name: 'greedy',
  /** Greedy judges the boss against the board it has today, not the one it will have. */
  chooseBoss(content, shop, ctx, options, futureTarget) {
    let best = 0; let bestVal = -Infinity;
    for (let i = 0; i < options.length; i++) {
      const p = profitOf(content, shop, { ...ctx, boss: options[i], target: futureTarget });
      if (p > bestVal) { bestVal = p; best = i; }
    }
    return best;
  },
  night(nc) {
    const { content, shop, ctx } = nc;
    let best = null;
    for (const fx of nc.offers) {
      const r = bestPlacement(content, shop, ctx, fx, 4);
      if (!best || r.profit > best.profit) best = { ...r, fx };
    }
    nc.take(best.fx, best.placement);

    // Buy whatever raises today's profit most, while it pays for itself today.
    for (let i = 0; i < 3; i++) {
      const base = profitOf(content, shop, ctx);
      let pick = null;
      for (const opt of nc.affordable()) {
        const s = cloneShop(shop);
        if (!nc.buy(opt, s)) continue;
        const gain = profitOf(content, s, ctx) - base;
        if (gain > 0 && (!pick || gain > pick.gain)) pick = { opt, gain };
      }
      if (!pick) break;
      nc.buy(pick.opt);
    }
    // Greedy signs the shop the obvious way and never thinks about it again.
    autoSign(content, shop);
  },
};

// ---------------------------------------------------------------------------

/**
 * How exposed is this build to a term collapsing? The four terms multiply, so
 * the run is worth roughly its weakest link; this returns a 0..1 balance score.
 */
function termBalance(content, shop, ctx) {
  const d = resolveDay(content, shop, { ...ctx, boss: null });
  const p = d.panel;
  const norm = [
    Math.min(1, p.footfall / 400),
    Math.min(1, p.conversion / 0.85),
    Math.min(1, p.basket / 60),
    Math.min(1, p.margin / 0.7),
  ];
  const weakest = Math.min(...norm);
  const mean = norm.reduce((a, b) => a + b, 0) / 4;
  return { weakest, mean, panel: p, walkoutRate: d.walkoutRate };
}

const STRESS = [
  { id: 'competitor_opens', effect: 'footfall_multiply', value: 0.5 },
  { id: 'card_terminal_down', effect: 'only_types_convert', value: ['trade', 'pensioner'] },
  { id: 'black_friday', effect: 'footfall_multiply_margin_flat', value: [4.0, -0.25] },
];

export const plannerPolicy = {
  name: 'planner',
  /**
   * Two bosses are offered; take the one this board can absorb. Every boss
   * attacks a specific term, so this is a direct read of your own funnel —
   * and because the boss lands a couple of encounters out, the planner also
   * weighs it against the board it expects to have by then.
   */
  chooseBoss(content, shop, ctx, options, futureTarget) {
    const ahead = cloneShop(shop);
    projectRatchets(ahead, content.economy.bossChoice.revealLead || 0);
    let best = 0; let bestVal = -Infinity;
    for (let i = 0; i < options.length; i++) {
      const p = profitOf(content, ahead, { ...ctx, boss: options[i], target: futureTarget });
      if (p > bestVal) { bestVal = p; best = i; }
    }
    return best;
  },
  night(nc) {
    const { content, shop, ctx } = nc;
    const target = nc.target;

    const score = (s) => {
      const today = profitOf(content, s, ctx);
      // Robustness: the worst a representative boss could do to this board.
      let worst = Infinity;
      for (const b of STRESS) {
        worst = Math.min(worst, profitOf(content, s, { ...ctx, boss: b }));
      }
      const bal = termBalance(content, s, ctx);
      // What this board is worth once its ratchets have run. Weighted by how
      // much run is left: a ratchet taken on encounter 3 is a different card
      // from the same ratchet taken on encounter 22.
      const left = Math.max(0, content.run.encounters - nc.encounter);
      const horizon = Math.min(10, left);
      const future = horizon > 0 ? profitAhead(content, s, ctx, horizon) : today;
      // Weighted toward today when the gap is tight, toward the future when not.
      const urgency = today < target ? 1 : Math.min(1, target / Math.max(1, today));
      return today * (0.55 + 0.35 * urgency)
        + worst * 0.35
        + future * 0.30 * (left / content.run.encounters)
        + bal.weakest * target * 0.25;
    };

    let attempts = 0;
    let picked = false;
    while (!picked && attempts <= 2) {
      let best = null;
      for (const fx of nc.offers) {
        const owned = findInstance(shop, fx.id);
        if (owned && owned.inst.level >= 3) continue; // a fourth copy is dead weight
        const place = bestPlacement(content, shop, ctx, fx, 5);
        const s = cloneShop(shop);
        addFixture(content, s, fx.id, place.placement);
        const sc = score(s);
        if (!best || sc > best.sc) best = { sc, fx, placement: place.placement };
      }
      const baseScore = score(shop);
      const rc = nc.rerollCost();
      const worthRerolling = best
        && best.sc - baseScore < target * 0.06
        && shop.cash > rc * 4
        && attempts < 2;
      if (worthRerolling && nc.reroll()) { attempts++; continue; }
      if (best) nc.take(best.fx, best.placement);
      else nc.take(nc.offers[0], emptySlots(shop)[0] || null);
      picked = true;
    }

    // --- Operation, which is the second currency and the second skill axis ---
    plannerSpend(nc);
    plannerSign(nc);
    plannerReorder(nc);
  },
};

function plannerSpend(nc) {
  const { content, shop, ctx } = nc;
  const target = nc.target;

  for (let i = 0; i < 4; i++) {
    const base = profitOf(content, shop, ctx);
    const bal = termBalance(content, shop, ctx);
    let pick = null;

    for (const opt of nc.affordable()) {
      const s = cloneShop(shop);
      if (!nc.buy(opt, s)) continue;
      const cost = nc.costOf(opt);
      let gain = profitOf(content, s, ctx) - base;

      if (opt === 'tier') {
        // Supplier Tier buys nothing today. It buys a better catalogue for the
        // rest of the run, so value it against remaining encounters.
        const left = content.run.encounters - nc.encounter;
        gain = left >= 6 ? cost * 0.5 * (left / 18) : -1;
      }
      if (opt === 'till' && bal.walkoutRate > 0.06) gain += target * 0.1;

      // Three trading days of payback, versus 5% interest for doing nothing.
      const value = gain * 3 - cost * 0.15;
      if (value > 0 && (!pick || value > pick.value)) pick = { opt, value };
    }
    if (!pick) break;
    // Never spend into a loss: keep enough to clear today's target.
    if (nc.costOf(pick.opt) > shop.cash) break;
    nc.buy(pick.opt);
  }
}

function plannerSign(nc) {
  const { content, shop, ctx } = nc;
  const open = shop.aisles.map((a, i) => i).filter((i) => !shop.aisles[i].closed);
  if (open.length < 2) return;
  // A customer walks exactly one aisle, so on a 3x3 board six of your nine
  // slots do nothing for them. The only way the whole board earns is if
  // different types take different routes — which means routing every type
  // that carries money, not just the biggest few, and doing it twice because
  // the choices interact through the aisle-scoped conditions.
  const ranked = content.types
    .filter((t) => t.sign === 'positive')
    .map((t) => ({ t, w: (shop.pool[t.id] || 0) * t.basket }))
    .sort((a, b) => b.w - a.w);
  // Signage is the only thing changing, so mutate and restore rather than
  // cloning the shop for every probe — this loop runs a few hundred times a
  // night and the clone dominated the whole simulator's runtime.
  for (let pass = 0; pass < 2; pass++) {
    for (const { t } of ranked) {
      const original = shop.signage[t.id];
      let bestAisle = original;
      let bestProfit = -Infinity;
      for (const a of open) {
        if (shop.aisles[a].restrictTypes && !shop.aisles[a].restrictTypes.includes(t.id)) continue;
        shop.signage[t.id] = a;
        const p = profitOf(content, shop, ctx);
        if (p > bestProfit) { bestProfit = p; bestAisle = a; }
      }
      shop.signage[t.id] = bestAisle;
    }
  }
}

/**
 * Order of operations is the primary skill expression: an additive bump placed
 * before a multiplier gets multiplied. Try a handful of adjacent swaps.
 */
function plannerReorder(nc) {
  const { content, shop, ctx } = nc;
  if (shop.flags.fixturesPermanent) return;
  let base = profitOf(content, shop, ctx);
  for (let a = 0; a < shop.aisles.length; a++) {
    const slots = shop.aisles[a].slots;
    for (let i = 0; i < slots.length - 1; i++) {
      if (!slots[i] && !slots[i + 1]) continue;
      // Swap in place and swap back if it did not help: no clone needed.
      [slots[i], slots[i + 1]] = [slots[i + 1], slots[i]];
      const p = profitOf(content, shop, ctx);
      if (p > base + 1e-9) base = p;
      else [slots[i], slots[i + 1]] = [slots[i + 1], slots[i]];
    }
  }
}

export const policies = {
  random: randomPolicy,
  greedy: greedyPolicy,
  planner: plannerPolicy,
};
