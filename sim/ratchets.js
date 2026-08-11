// How a ratchet grows.
//
// A flat "+N per day" ratchet is linear, and linear cannot carry a
// twenty-four day exponential: twenty days of +5 is +100, however many you own.
// Reaching a seven-figure ending needs growth that is itself capable of
// growing, so a ratchet may be fed four ways:
//
//   per: 'day'        a fixed amount every trading day — the reliable floor
//   per: 'sale'       an amount per sale, so it scales with how well you trade
//   per: 'type_sale'  per sale to one customer type — specialist, marketing-led
//   per: 'boss'       only on boss days — rare, patient, enormous
//
// and any of them may carry `accel`, which grows the per-day amount itself.
// That is the second-order term, and it is where the exponent actually lives.
//
// Shared by the simulator and the browser build so growth cannot diverge.

export const isRatchet = (def) => def.effect.op === 'ratchet' || def.effect.op === 'ratchet_mult';

/**
 * Advance one fixture by a single trading day.
 * @param {object} inst   placed fixture instance
 * @param {object} day    { sales, salesByType, walkouts, footfall, isBoss, rateMul }
 */
export function growRatchet(inst, day) {
  const def = inst.def;
  if (!isRatchet(def)) return 0;
  const L = inst.level - 1;
  const eff = def.effect;
  const base = (inst.rate == null ? eff.value[L] : inst.rate) * (day.rateMul || 1);

  let gain = 0;
  switch (eff.per || 'day') {
    case 'sale':
      gain = base * (day.sales || 0);
      break;
    case 'type_sale':
      gain = base * ((day.salesByType && day.salesByType[eff.perType]) || 0);
      break;
    case 'walkout':
      gain = base * (day.walkouts || 0);
      break;
    case 'boss':
      gain = day.isBoss ? base : 0;
      break;
    default:
      gain = base;
  }

  // A level-3 clause may double the day's growth under a condition.
  const rb = def.ratchetBonus;
  if (rb && inst.level >= rb.minLevel && (rb.when !== 'boss_day' || day.isBoss)) {
    gain *= rb.multiply;
  }

  inst.ratchet = (inst.ratchet || 0) + gain;

  // The rate itself climbs, which is the whole point of an accelerating card.
  const accel = eff.accel ? eff.accel[L] : 0;
  // Store the un-multiplied rate, so the multiplier is not compounded into
  // the card itself every day.
  inst.rate = (inst.rate == null ? eff.value[L] : inst.rate) + accel;
  inst.age = (inst.age || 0) + 1;

  // Some ratchets are fragile: a bad day knocks them back.
  const d = def.drawback;
  if (d && d.id === 'reset_on_walkouts'
      && (day.walkouts || 0) / Math.max(1, day.footfall || 1) > 0.1) {
    inst.ratchet *= 1 - d.value[L];
  }
  if (d && d.id === 'reset_unless_target' && day.missedTarget) {
    inst.ratchet *= 1 - d.value[L];
  }
  return gain;
}

/** Advance every placed ratchet in a shop by one trading day. */
export function growAll(fixtures, day) {
  for (const { inst } of fixtures) growRatchet(inst, day);
}
