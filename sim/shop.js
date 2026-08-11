// Shop state: topology, placed fixtures, staff, tills, marketing, cash.
// Topology is fixed per shop type and never procedurally generated (section 4),
// so everything here is either bought or drafted, never rolled.

export function createShop(content, characterId) {
  const ch = content.characterById.get(characterId);
  if (!ch) throw new Error(`unknown character: ${characterId}`);

  const aisles = [];
  for (let i = 0; i < ch.aisles; i++) {
    aisles.push({
      slots: new Array(ch.slotsPerAisle).fill(null),
      closed: false,
      patienceBonus: 0,
      restrictTypes: null,
    });
  }

  const shop = {
    characterId,
    character: ch,
    flags: { ...(ch.flags || {}) },
    aisles,
    tills: ch.tills,
    staff: [], // { id, def, aisle, slot }  (aisle/slot null when shop-wide)
    bench: [], // owned but unplaced fixture instances (Market Stall, overflow)
    supplierTier: 1,
    cash: content.economy.start.cash,
    marketing: [],
    pool: { ...content.defaultPool },
    structural: new Set(),
    signage: {}, // typeId -> aisle index
    baseFootfall: content.economy.start.footfall,
    carryFootfall: 0, // Clearance / walkout penalties land here
    lastAvgSaleProfit: 0,
    quarter: 1,
    encounter: 0,
    banked: 0,
    history: [],
  };

  for (const id of ch.startingFixtures || []) {
    addFixture(content, shop, id);
  }
  autoSign(content, shop);
  return shop;
}

export function fixtureInstances(shop) {
  const out = [];
  for (let a = 0; a < shop.aisles.length; a++) {
    const aisle = shop.aisles[a];
    for (let s = 0; s < aisle.slots.length; s++) {
      const inst = aisle.slots[s];
      if (inst) out.push({ inst, aisle: a, slot: s });
    }
  }
  return out;
}

export function ownedIds(shop) {
  const ids = new Set(shop.bench.map((i) => i.def.id));
  for (const { inst } of fixtureInstances(shop)) ids.add(inst.def.id);
  return ids;
}

export function findInstance(shop, fixtureId) {
  for (const entry of fixtureInstances(shop)) {
    if (entry.inst.def.id === fixtureId) return entry;
  }
  const b = shop.bench.find((i) => i.def.id === fixtureId);
  return b ? { inst: b, aisle: null, slot: null } : null;
}

export function emptySlots(shop) {
  const out = [];
  for (let a = 0; a < shop.aisles.length; a++) {
    for (let s = 0; s < shop.aisles[a].slots.length; s++) {
      if (!shop.aisles[a].slots[s]) out.push({ aisle: a, slot: s });
    }
  }
  return out;
}

/**
 * Acquire a fixture. Duplicates combine: two copies reach L2, a third L3
 * (section 9). A duplicate beyond L3 is dead weight, which is itself a real
 * drafting consideration.
 */
export function addFixture(content, shop, fixtureId, placement = null) {
  const def = content.fixtureById.get(fixtureId);
  if (!def) throw new Error(`unknown fixture: ${fixtureId}`);

  const existing = findInstance(shop, fixtureId);
  if (existing) {
    existing.inst.level = Math.min(3, existing.inst.level + 1);
    existing.inst.copies += 1;
    return existing.inst;
  }

  // Discounter may hold only five fixture types.
  if (shop.flags.maxFixtureTypes && ownedIds(shop).size >= shop.flags.maxFixtureTypes) {
    return null;
  }

  const inst = { def, level: 1, copies: 1, staff: null, ratchet: 0, age: 0 };
  const target = placement || emptySlots(shop)[0] || null;
  if (target && !shop.aisles[target.aisle].slots[target.slot]) {
    shop.aisles[target.aisle].slots[target.slot] = inst;
  } else {
    shop.bench.push(inst);
  }
  return inst;
}

export function moveFixture(shop, from, to) {
  if (shop.flags.fixturesPermanent && from.aisle !== null) return false;
  const inst = from.aisle === null
    ? shop.bench.splice(shop.bench.indexOf(from.inst), 1)[0]
    : shop.aisles[from.aisle].slots[from.slot];
  if (from.aisle !== null) shop.aisles[from.aisle].slots[from.slot] = null;
  const occupant = shop.aisles[to.aisle].slots[to.slot];
  shop.aisles[to.aisle].slots[to.slot] = inst;
  if (occupant) {
    if (from.aisle !== null) shop.aisles[from.aisle].slots[from.slot] = occupant;
    else shop.bench.push(occupant);
  }
  return true;
}

export function shopHoldsTag(shop, tag) {
  for (const { inst } of fixtureInstances(shop)) {
    if (inst.def.tagSet.has(tag)) return true;
  }
  return false;
}

export function aisleHoldsRarity(shop, aisleIdx, rarity) {
  for (const inst of shop.aisles[aisleIdx].slots) {
    if (inst && inst.def.rarity === rarity) return true;
  }
  return false;
}

export function totalSlots(shop) {
  return shop.aisles.reduce((n, a) => n + a.slots.length, 0);
}

/**
 * Signage routes types to aisles. Free to reassign each night (section 5).
 *
 * The sane default is to point everyone at the busiest aisle, because nothing
 * in the ruleset punishes funnelling: the till queue is shop-wide, so an aisle
 * carries no congestion cost. See sim/README.md — this is a live design hole.
 */
export function autoSign(content, shop) {
  const open = shop.aisles.map((a, i) => i).filter((i) => !shop.aisles[i].closed);
  if (open.length === 0) return;
  const stocked = open
    .map((i) => ({ i, n: shop.aisles[i].slots.filter(Boolean).length }))
    .sort((a, b) => b.n - a.n);
  for (const t of content.types) {
    const allowed = stocked.filter(({ i }) => {
      const r = shop.aisles[i].restrictTypes;
      return !r || r.includes(t.id);
    });
    shop.signage[t.id] = (allowed.length ? allowed : stocked)[0].i;
  }
}

/**
 * Rent is pegged to the target as a declining fraction, so "brutal in act 1,
 * noise by act 5" holds by construction rather than by coincidence. Footprint
 * still costs: the fraction is quoted for a baseline shop and scales with the
 * slots and tills you have actually bought.
 */
export function rentFor(content, shop, auditMods = {}, target = null) {
  const e = content.economy.rent;
  const slots = totalSlots(shop);
  let raw;
  if (e.mode === 'fraction_of_target' && target != null) {
    const frac = e.fractionByQuarter[Math.min(e.fractionByQuarter.length - 1, shop.quarter - 1)];
    const footprint = (slots + e.tillWeight * shop.tills)
      / (e.baselineSlots + e.tillWeight * e.baselineTills);
    raw = target * frac * footprint;
  } else {
    const g = e.legacy || e;
    raw = (slots * g.perSlot + shop.tills * g.perTill)
      * Math.pow(g.quarterMultiplier, shop.quarter - 1);
  }
  return raw * (auditMods.rentMultiplier || 1);
}

export function marginPenaltyFromStaff(shop) {
  return shop.staff.reduce((m, s) => m + s.def.marginCost, 0);
}

/**
 * Advance every ratchet by `days`, on a throwaway clone, so a policy can look
 * ahead. Ratchets are the only unbounded scalers in the pool, so seeing what
 * one is worth in ten days' time is the difference between a plan and a guess.
 */
export function projectRatchets(shop, days) {
  for (const { inst } of fixtureInstances(shop)) {
    if (inst.def.effect.op !== 'ratchet') continue;
    inst.ratchet = (inst.ratchet || 0) + inst.def.effect.value[inst.level - 1] * days;
    // Age too, so a lookahead sees the upkeep falling away as well as the
    // value climbing. Seeing only one half of that is not a plan.
    inst.age = (inst.age || 0) + days;
  }
}
