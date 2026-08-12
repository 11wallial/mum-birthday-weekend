// The night economy: offers, rerolls, locks, supplier tier.
// One free pick per encounter (section 11). Picks are your build, money is your
// operation, and the two currencies never substitute for each other.

export function rarityWeights(content, tier) {
  return content.economy.supplierTier.weights[String(tier)];
}

export function rollFixture(content, shop, rng) {
  const w = rarityWeights(content, shop.supplierTier);
  const entries = Object.entries(w).filter(([r, p]) => p > 0 && content.byRarity[r].length);
  const rarity = rng.weighted(entries);
  const pool = content.byRarity[rarity];
  return rng.pick(pool);
}

export function makeOffer(content, shop, rng, count = 3, locked = []) {
  const out = locked.slice(0, count);
  const seen = new Set(out.map((f) => f.id));
  let guard = 0;
  while (out.length < count && guard++ < 200) {
    const f = rollFixture(content, shop, rng);
    if (seen.has(f.id)) continue; // no duplicates within one spread
    seen.add(f.id);
    out.push(f);
  }
  return out;
}

export function rerollCost(content, shop, rerollsThisEncounter, auditMods = {}) {
  const o = content.economy.offers;
  const base = o.rerollBaseCost * (auditMods.rerollCostMultiplier || 1);
  if (shop.flags.freeRerolls) return 0;
  return base * Math.pow(o.rerollGrowth, rerollsThisEncounter);
}

export function supplierUpgradeCost(content, shop, auditMods = {}) {
  if (shop.supplierTier >= 5) return Infinity;
  const key = `${shop.supplierTier}->${shop.supplierTier + 1}`;
  const table = content.economy.supplierTier.costs[key];
  if (!table) return Infinity;
  // Audit VII: Supplier Tier costs do not fall by quarter.
  const q = auditMods.supplierCostsFlat ? 1 : shop.quarter;
  return table[Math.min(table.length - 1, q - 1)];
}

export function tillCost(content, shop) {
  const def = content.economy.structural.find((s) => s.id === 'extra_till');
  const bought = Math.max(0, shop.tills - shop.character.tills);
  return def.cost * Math.pow(def.costGrowth, bought);
}
