// Decision policies.
//
// These used to be two hand-written bots, "greedy" and "planner", and the gap
// between them was the project's health check. That measurement was close to
// circular: greedy had no model of tomorrow *by construction*, which is exactly
// the axis the ratchet fixtures were added to reward, so the gap partly
// measured a strawman.
//
// So there is now one policy with feature switches, and greedy and planner are
// two settings of it. Everything except the switch under test is held constant,
// which lets `node sim/cli.js ablate` attribute the gap to each capability
// separately and plot it against lookahead depth. If one step of lookahead
// recovers most of the gap, the design's central bet is weak and we need to
// know that.

import { resolveDay } from './day.js';
import { isRatchet } from './ratchets.js';
import {
  addFixture, autoSign, emptySlots, findInstance, fixtureInstances, ownedIds,
  projectRatchets, totalSlots,
} from './shop.js';
import { rerollCost, rollFixture, supplierUpgradeCost, tillCost } from './offers.js';

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

/** What this shop earns `days` from now if nothing else changes. */
function profitAhead(content, shop, ctx, days) {
  if (days <= 0) return profitOf(content, shop, ctx);
  // Today's trading tells the projection how often the trigger-fed ratchets
  // actually fire, which is the difference between valuing them and ignoring
  // them entirely.
  const today = resolveDay(content, shop, { ...ctx, boss: null });
  const s = cloneShop(shop);
  projectRatchets(s, days, today);
  return resolveDay(content, s, { ...ctx, boss: null }).profit;
}

function candidateSlots(shop, limit) {
  const empty = emptySlots(shop);
  // Once the board is full, the only placement left is on top of something.
  // Offering those slots as candidates is what lets a build pivot in act 3
  // instead of being frozen at whatever it happened to draft in act 1.
  if (empty.length === 0) {
    const held = fixtureInstances(shop)
      .map(({ aisle, slot, inst }) => ({ aisle, slot, inst }))
      // Never scrap something that has been accumulating: a ratchet's value is
      // in its history, and throwing one away is almost always a mistake the
      // policy should not spend its search budget rediscovering.
      .sort((a, b) => (a.inst.ratchet || 0) - (b.inst.ratchet || 0))
      .slice(0, limit);
    return held.map(({ aisle, slot }) => ({ aisle, slot }));
  }
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

/** Best slot for one offered fixture, judged on today alone. */
function bestPlacement(content, shop, ctx, fx, limit) {
  if (findInstance(shop, fx.id)) {
    return placeAndScore(content, shop, ctx, fx, null); // a duplicate combines
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

/**
 * How exposed is this build to one term collapsing? The four terms multiply,
 * so a run is worth roughly its weakest link.
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
  return { weakest: Math.min(...norm), panel: p, walkoutRate: d.walkoutRate };
}

const STRESS = [
  { id: 'competitor_opens', effect: 'footfall_multiply', value: 0.5 },
  { id: 'card_terminal_down', effect: 'only_types_convert', value: ['trade', 'pensioner'] },
  { id: 'black_friday', effect: 'footfall_multiply_margin_flat', value: [4.0, -0.25] },
];

// ---------------------------------------------------------------------------
// Purchasing
// ---------------------------------------------------------------------------

/** Buy whatever raises today's profit most, while it pays for itself today. */
function spendGreedy(nc, rounds = 3) {
  const { content, shop, ctx } = nc;
  for (let i = 0; i < rounds; i++) {
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
}

/**
 * What a supplier tier is worth.
 *
 * It buys nothing today — it buys a better catalogue for the rest of the run —
 * so it needs a valuation rather than a resolve. The old one was
 * `cost * 0.5 * (left / 18)`, which is proportional to the PRICE: the dearer
 * the upgrade, the more the planner wanted it. It bought tier at every
 * opportunity, tier rush sat at 74% of winners against a target of 30%, and
 * making tiers permanently more expensive measured as a 3.7pp IMPROVEMENT in
 * the win rate. A dial that makes the game easier by making a purchase dearer
 * is not a hard mode; it is a purchase the policy is wrong about.
 *
 * So: sample what the next tier actually offers, price the best of a hand
 * against the board you have, and compare it with the same hand at the tier
 * you are on. The difference is what you are buying.
 */
function tierValue(nc, base) {
  const { content, shop, ctx, rng } = nc;
  const left = content.run.encounters - nc.encounter;
  // A catalogue you will only see three more times cannot repay itself.
  if (left < 4) return -1;

  const picks = content.economy.offers.picks || 3;
  const samples = 3;
  // Judged on what the card is worth by the END of the run, not today. What a
  // higher tier actually sells you is rarity, and the whole point of the rare
  // and flagship bands is cards that pay later — a compounder adds nothing at
  // all on the day you install it. Priced on today's profit, the better
  // catalogue looked worthless and tier rush fell from 74% of winners to 2.7%,
  // straight past the 30% it wants. This is the same error, in a third place.
  const horizon = Math.min(left, 12);
  const aheadBase = profitAhead(content, shop, ctx, horizon);
  const bestAt = (tier) => {
    const probe = cloneShop(shop);
    probe.supplierTier = tier;
    let total = 0;
    for (let s = 0; s < samples; s++) {
      let best = 0;
      for (let i = 0; i < picks; i++) {
        const fx = rollFixture(content, probe, rng);
        const trial = cloneShop(shop);
        addFixture(content, trial, fx.id, emptySlots(trial)[0] || null);
        best = Math.max(best, profitAhead(content, trial, ctx, horizon) - aheadBase);
      }
      total += best;
    }
    return total / samples;
  };

  const step = bestAt(shop.supplierTier + 1) - bestAt(shop.supplierTier);
  if (step <= 0) return -1;
  // Every remaining pick is better by `step`, and those gains land one at a
  // time, so the uplift averaged over the rest of the run is about half of the
  // final one. Returned as a per-day figure, because that is what the caller
  // compares every other purchase in.
  return step / 2;
}

/** Buy against a payback horizon, and value Supplier Tier over the run. */

function spendPlanned(nc, rounds = 4, paybackDays = 3) {
  const { content, shop, ctx } = nc;
  const target = nc.target;
  for (let i = 0; i < rounds; i++) {
    const base = profitOf(content, shop, ctx);
    const bal = termBalance(content, shop, ctx);
    let pick = null;
    for (const opt of nc.affordable()) {
      const s = cloneShop(shop);
      if (!nc.buy(opt, s)) continue;
      const cost = nc.costOf(opt);
      let gain = profitOf(content, s, ctx) - base;
      if (opt === 'tier') {
        gain = tierValue(nc, base);
      }
      if (opt === 'till' && bal.walkoutRate > 0.06) gain += target * 0.1;
      const value = gain * paybackDays - cost * 0.15;
      if (value > 0 && (!pick || value > pick.value)) pick = { opt, value };
    }
    if (!pick || nc.costOf(pick.opt) > shop.cash) break;
    nc.buy(pick.opt);
  }
}

/**
 * A customer walks exactly one aisle, so most of the board is invisible to
 * them unless different types take different routes. Mutate and restore rather
 * than cloning: this loop runs a few hundred times a night.
 */
function signOptimised(nc) {
  const { content, shop, ctx } = nc;
  const open = shop.aisles.map((a, i) => i).filter((i) => !shop.aisles[i].closed);
  if (open.length < 2) return;
  const ranked = content.types
    .filter((t) => t.sign === 'positive')
    .map((t) => ({ t, w: (shop.pool[t.id] || 0) * t.basket }))
    .sort((a, b) => b.w - a.w);
  for (let pass = 0; pass < 2; pass++) {
    for (const { t } of ranked) {
      let bestAisle = shop.signage[t.id];
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
 * before a multiplier gets multiplied. Try adjacent swaps in place.
 */
function reorderSlots(nc) {
  const { content, shop, ctx } = nc;
  if (shop.flags.fixturesPermanent) return;
  let base = profitOf(content, shop, ctx);
  for (let a = 0; a < shop.aisles.length; a++) {
    const slots = shop.aisles[a].slots;
    for (let i = 0; i < slots.length - 1; i++) {
      if (!slots[i] && !slots[i + 1]) continue;
      [slots[i], slots[i + 1]] = [slots[i + 1], slots[i]];
      const p = profitOf(content, shop, ctx);
      if (p > base + 1e-9) base = p;
      else [slots[i], slots[i + 1]] = [slots[i + 1], slots[i]];
    }
  }
}

// ---------------------------------------------------------------------------
// The parameterised policy
// ---------------------------------------------------------------------------

export const GREEDY_CFG = {
  lookahead: 0, stress: false, balance: false, tempo: false,
  sign: false, reorder: false, reroll: false, placements: 5,
  // Micro: what the player does DURING the trading day. Off by default so
  // every earlier measurement stays comparable.
  triage: false, // false | 'naive' | 'smart'
  sale: false,
};

export const PLANNER_CFG = {
  lookahead: 10, stress: true, balance: true, tempo: true,
  sign: true, reorder: true, reroll: true, placements: 5,
};

export function makePolicy(name, overrides = {}) {
  const cfg = { ...GREEDY_CFG, ...overrides };
  return {
    name,
    cfg,

    /**
     * Two bosses are offered; take the one this board can absorb. With
     * lookahead, judge it against the board you expect to have when it lands.
     */
    chooseBoss(content, shop, ctx, options, futureTarget) {
      const board = cfg.lookahead > 0
        ? (() => {
          const s = cloneShop(shop);
          projectRatchets(s, content.economy.bossChoice.revealLead || 0);
          return s;
        })()
        : shop;
      let best = 0; let bestVal = -Infinity;
      for (let i = 0; i < options.length; i++) {
        const p = profitOf(content, board, { ...ctx, boss: options[i], target: futureTarget });
        if (p > bestVal) { bestVal = p; best = i; }
      }
      return best;
    },

    night(nc) {
      const { content, shop, ctx } = nc;
      const target = nc.target;
      const left = Math.max(0, content.run.encounters - nc.encounter);
      // Set before anything is evaluated, so the board is judged as it will
      // actually be played rather than as it would be played passively.
      shop.triageMode = cfg.triage || null;

      // How hard is this policy committing to scaling over surviving today?
      // null means "use the configured weights"; 0 is pure tempo, 1 is pure
      // investment, and pivotAt flips from one to the other mid-run.
      const bias = cfg.pivotAt != null
        ? (nc.encounter <= cfg.pivotAt ? 1 : 0)
        : (cfg.scalingBias ?? null);

      const score = (s) => {
        const today = profitOf(content, s, ctx);
        if (bias != null) {
          const horizon = Math.min(cfg.lookahead || 10, left);
          const future = profitAhead(content, s, ctx, horizon);
          let v = today * (1 - bias) + future * bias;
          if (cfg.balance) v += termBalance(content, s, ctx).weakest * target * 0.25;
          return v;
        }
        let v = today;
        if (cfg.stress) {
          let worst = Infinity;
          for (const b of STRESS) worst = Math.min(worst, profitOf(content, s, { ...ctx, boss: b }));
          const urgency = today < target ? 1 : Math.min(1, target / Math.max(1, today));
          v = today * (0.55 + 0.35 * urgency) + worst * 0.35;
        }
        if (cfg.lookahead > 0) {
          const horizon = Math.min(cfg.lookahead, left);
          v += profitAhead(content, s, ctx, horizon)
            * (cfg.futureWeight ?? 0.30) * (left / content.run.encounters);
        }
        if (cfg.balance) v += termBalance(content, s, ctx).weakest * target * 0.25;
        return v;
      };

      let attempts = 0;
      for (;;) {
        let best = null;
        // A hard quota on how many ratchet fixtures this build will hold.
        // This is the axis the commitment mechanics actually act on, so it is
        // the axis the commitment measurement has to move.
        const held = cfg.ratchetQuota != null
          ? fixtureInstances(shop).filter((e) => isRatchet(e.inst.def)).length
          : 0;
        for (const fx of nc.offers) {
          const owned = findInstance(shop, fx.id);
          if (owned && owned.inst.level >= 3) continue; // a fourth copy is dead
          // The quota is a target, not a ceiling: below it, ratchets are
          // taken in preference to anything else, so the build really does
          // commit. A cap alone can never test a commitment threshold, because
          // any cap at or above the natural level is a no-op.
          if (cfg.ratchetQuota != null && !owned) {
            const scales = isRatchet(fx);
            if (scales && held >= cfg.ratchetQuota) continue;
            if (!scales && held < cfg.ratchetQuota
                && nc.offers.some((o) => isRatchet(o) && !findInstance(shop, o.id))) {
              continue;
            }
          }
          const place = bestPlacement(content, shop, ctx, fx, cfg.placements);
          const s = cloneShop(shop);
          addFixture(content, s, fx.id, place.placement);
          const sc = score(s);
          if (!best || sc > best.sc) best = { sc, fx, placement: place.placement };
        }
        const worthRerolling = cfg.reroll && best
          && best.sc - score(shop) < target * 0.06
          && shop.cash > nc.rerollCost() * 4
          && attempts < 2;
        if (worthRerolling && nc.reroll()) { attempts++; continue; }
        // Taking is no longer free once the board is full: the pick lands on
        // top of something. If nothing on offer beats what is already
        // standing, decline and bank the money instead.
        if (best && best.sc <= score(shop) && emptySlots(shop).length === 0) {
          nc.skip();
        } else if (best) nc.take(best.fx, best.placement);
        else nc.take(nc.offers[0], emptySlots(shop)[0] || null);
        break;
      }

      const payback = bias == null ? 3 : 1 + bias * 8;
      if (cfg.tempo) spendPlanned(nc, 4, payback); else spendGreedy(nc);
      if (cfg.sign) signOptimised(nc); else autoSign(content, shop);
      if (cfg.reorder) reorderSlots(nc);

      // The SALE sign, decided once the board is final. Modelled as a plan
      // rather than a mid-day reaction, so this is the LOWER bound on what the
      // lever is worth: a player reading the day would do better.
      if (cfg.sale) {
        shop.saleOn = false;
        const without = profitOf(content, shop, ctx);
        shop.saleOn = true;
        const with_ = profitOf(content, shop, ctx);
        shop.saleOn = with_ > without;
      } else {
        shop.saleOn = false;
      }
    },
  };
}

// ---------------------------------------------------------------------------

export const randomPolicy = {
  name: 'random',
  cfg: { lookahead: 0 },
  chooseBoss(content, shop, ctx, options) { return ctx.rng ? ctx.rng.int(options.length) : 0; },
  night(nc) {
    const { content, shop, rng } = nc;
    const fx = rng.pick(nc.offers);
    const empty = emptySlots(shop);
    nc.take(fx, empty.length ? rng.pick(empty) : null);

    if (rng() < 0.25) {
      const options = [];
      if (shop.cash >= tillCost(content, shop)) options.push('till');
      if (shop.cash >= supplierUpgradeCost(content, shop, nc.ctx.auditMods)) options.push('tier');
      for (const st of content.economy.staff) if (shop.cash >= 200) options.push(`staff:${st.id}`);
      for (const s of content.economy.structural) {
        if (s.id !== 'extra_till' && shop.cash >= s.cost && !shop.structural.has(s.id)) {
          options.push(`struct:${s.id}`);
        }
      }
      if (options.length) nc.buy(rng.pick(options));
    }
    for (const t of content.types) shop.signage[t.id] = rng.int(shop.aisles.length);
  },
};

export const greedyPolicy = makePolicy('greedy', GREEDY_CFG);
export const plannerPolicy = makePolicy('planner', PLANNER_CFG);

export const policies = {
  random: randomPolicy,
  greedy: greedyPolicy,
  planner: plannerPolicy,
};

/** Register an ad-hoc policy so the harness can run it by name. */
export function registerPolicy(name, overrides) {
  policies[name] = makePolicy(name, overrides);
  return policies[name];
}
