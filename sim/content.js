// Loads /data and turns it into indexed structures the sim can hit hard.
// The JSON is the contract between sim and game (section 21), so nothing here
// invents content: it only indexes, validates and applies tuning overrides.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const DATA = join(HERE, '..', 'data');

const read = (f) => JSON.parse(readFileSync(join(DATA, f), 'utf8'));

/**
 * @param {object} [overrides] tuning overrides, applied on top of the JSON.
 *   Recognised keys: targetGrowth, rarityEv, dayTicks, slotPassChance,
 *   levelAdditive (array), levelBreadth (array), supplierCostScale,
 *   walkoutPenalty, staffMarginScale, rentScale.
 */
export function loadContent(overrides = {}) {
  const customers = read('customers.json');
  const fixturesFile = read('fixtures.json');
  const economy = read('economy.json');
  const runFile = read('run.json');

  const patienceOf = (band) => customers.patienceBands[band];

  const types = customers.types.map((t, i) => ({
    ...t,
    index: i,
    patienceTicks: patienceOf(t.patience),
  }));
  const typeById = new Map(types.map((t) => [t.id, t]));
  const typeIndex = new Map(types.map((t) => [t.id, t.index]));

  const wallet = customers.wallet;
  // Basket is linear in wallet, so the mean rank is exact for expected profit.
  const walletMean = (wallet.min + wallet.max) / 2;

  // --- rarity EV scaling (tuning step 4) -----------------------------------
  const baselineEv = economy.rarityEv;
  const targetEv = { ...baselineEv, ...(overrides.rarityEv || {}) };

  const scaleEffect = (fx, k) => {
    if (k === 1) return fx;
    const out = structuredClone(fx);
    if (out.effect.op === 'add') {
      out.effect.value = out.effect.value.map((v) => v * k);
    } else if (out.effect.op === 'multiply') {
      out.effect.value = out.effect.value.map((v) => 1 + (v - 1) * k);
    }
    return out;
  };

  const levelAdditive = overrides.levelAdditive || economy.levels.additiveScalar;
  const levelBreadth = overrides.levelBreadth || economy.levels.multiplicativeBreadth;

  const fixtures = fixturesFile.fixtures.map((raw) => {
    const k = (targetEv[raw.rarity] || 100) / (baselineEv[raw.rarity] || 100);
    const fx = scaleEffect(raw, k);
    // Additive levelling scales the number hard; the JSON authors level 1 and
    // the scalars in economy.json define 2 and 3, so a sweep of the scalars
    // moves every additive fixture at once.
    if (fx.class === 'additive' && fx.effect.op === 'add') {
      const base = fx.effect.value[0];
      fx.effect.value = levelAdditive.map((s) => base * s);
    }
    if (fx.trigger.scope === 'next_slots') {
      fx.trigger.count = levelBreadth.slice(0, 3);
    }
    // Flagship drawbacks are authored per level in fixtures.json rather than
    // scaled here: their polarity differs (a higher throughput cap helps the
    // player, a higher rent multiplier hurts), so one scalar cannot serve them.
    fx.tagSet = new Set(fx.tags || []);
    return fx;
  });

  const fixtureById = new Map(fixtures.map((f) => [f.id, f]));
  const byRarity = { common: [], uncommon: [], rare: [], flagship: [] };
  for (const f of fixtures) byRarity[f.rarity].push(f);

  // --- targets (tuning step 2) ---------------------------------------------
  const growth = overrides.targetGrowth ?? runFile.targets.growth;
  const targetBase = overrides.targetBase ?? runFile.targets.base;
  const targets = [];
  if (overrides.targetCurve) {
    targets.push(...overrides.targetCurve);
  } else if (runFile.targets.curve) {
    targets.push(...runFile.targets.curve);
  } else {
    for (let i = 0; i < runFile.structure.encounters; i++) {
      targets.push(targetBase * Math.pow(growth, i));
    }
  }

  const econ = structuredClone(economy);
  if (overrides.dayTicks) econ.day.ticks = overrides.dayTicks;
  if (overrides.slotPassChance != null) econ.slots.basePassChance = overrides.slotPassChance;
  if (overrides.walkoutPenalty != null) {
    econ.walkouts.footfallPenaltyPerWalkout = overrides.walkoutPenalty;
  }
  if (overrides.supplierCostScale != null) {
    for (const [key, row] of Object.entries(econ.supplierTier.costs)) {
      if (!Array.isArray(row)) continue; // the table carries a $comment key
      econ.supplierTier.costs[key] = row.map((c) => c * overrides.supplierCostScale);
    }
  }
  if (overrides.staffMarginScale != null) {
    for (const s of econ.staff) s.marginCost *= overrides.staffMarginScale;
  }
  if (overrides.rentScale != null) {
    econ.rent.perSlot *= overrides.rentScale;
    econ.rent.perTill *= overrides.rentScale;
  }
  if (overrides.payoutMode) econ.payout.mode = overrides.payoutMode;
  if (overrides.congestion != null) econ.congestion.strength = overrides.congestion;
  if (overrides.congestionMode) econ.congestion.mode = overrides.congestionMode;
  if (overrides.variance != null) econ.variance.enabled = !!overrides.variance;

  return {
    types,
    typeById,
    typeIndex,
    wallet,
    walletMean,
    defaultPool: customers.defaultPool,
    campaigns: customers.marketing.campaigns,
    marketingMaxHeld: customers.marketing.maxHeld ?? 99,
    fixtures,
    fixtureById,
    byRarity,
    economy: econ,
    run: runFile.structure,
    targets,
    targetGrowth: growth,
    targetBase,
    bosses: runFile.bosses,
    audits: runFile.audits,
    characters: runFile.characters,
    characterById: new Map(runFile.characters.map((c) => [c.id, c])),
  };
}

export function auditModifiers(content, auditId) {
  const a = content.audits.find((x) => x.id === auditId);
  return a ? a.modifiers : {};
}
