// How a ratchet grows.
//
// There are three growth classes in the pool, and they are three different
// shapes, not three sizes of the same thing.
//
//   ratchet       an addend that accumulates.        LINEAR in time.
//   ratchet_mult  a multiplier whose excess
//                 accumulates the same way.          LINEAR in time.
//   compound      a multiplier that is multiplied
//                 every day.                         EXPONENTIAL in time.
//
// That distinction is the whole late game. Twenty-four days of "+5 a day" is
// +120 however many copies you own, and twenty-four days of a multiplier that
// climbs by 0.05 a day is x2.2 — both of them linear, and neither of them can
// carry a target curve that multiplies by 1.47 every encounter. Only a rate
// proportional to what you already have compounds, and `compound` is the one
// op in the pool that has it.
//
// The consequence is a real decision rather than a bigger number: a compounder
// is worth what is left of the run. At encounter 2 a +9%/day card is x8.9 by
// the end; at encounter 20 the same card is x1.5 and you should have bought
// the flat one. Nothing else in the pool changes value with the clock.
//
// Orthogonally, a ratchet may be FED four ways:
//
//   per: 'day'        a fixed amount every trading day — the reliable floor
//   per: 'sale'       an amount per sale, so it scales with how well you trade
//   per: 'type_sale'  per sale to one customer type — specialist, marketing-led
//   per: 'walkout'    per customer who gave up — perverse, and see the cap
//   per: 'boss'       only on boss days — rare, patient, enormous
//
// and any of them may carry `accel`, which grows the per-day amount itself.
//
// Shared by the simulator and the browser build so growth cannot diverge.

const RATCHET_OPS = new Set(['ratchet', 'ratchet_mult', 'compound']);

/** All three accumulating classes count as ratchets everywhere. */
export const isRatchet = (def) => RATCHET_OPS.has(def.effect.op);

/** compound and ratchet_mult both apply as `x (1 + ratchet)`. */
export const isMultiplicative = (def) => def.effect.op === 'ratchet_mult' || def.effect.op === 'compound';

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
  const raw = inst.rate == null ? eff.value[L] : inst.rate;

  // A compounder's rate is a factor, not an amount, so a rate multiplier has
  // to act on the excess. Manager's Office at x1.9 against a x1.09 card means
  // x1.171 a day, not x2.07 a day — which over twenty-four days is the
  // difference between x54 and x2,000,000.
  const rateMul = day.rateMul || 1;
  const compounding = eff.op === 'compound';
  const base = compounding ? 1 + (raw - 1) * rateMul : raw * rateMul;

  // How many times the card is fed today. A compounder reads this as an
  // exponent rather than a count: two feeds is the factor applied twice.
  let feeds = 1;
  switch (eff.per || 'day') {
    case 'sale':
      feeds = day.sales || 0;
      break;
    case 'type_sale':
      feeds = (day.salesByType && day.salesByType[eff.perType]) || 0;
      break;
    case 'walkout':
      // A queue out the door is an advert; a shop nobody can get into is not.
      // Uncapped this is a positive feedback loop with no brake at all —
      // footfall feeds walkouts feeds footfall — and it found 2.1 million
      // customers at a 0% conversion rate. Capping the feed at the number of
      // people you actually served makes the card ask you to run deliberately
      // over capacity without collapsing, which is the interesting version.
      feeds = Math.min(day.walkouts || 0, day.served || 0);
      break;
    case 'boss':
      feeds = day.isBoss ? 1 : 0;
      break;
    // Only grows on a day you beat the target. Rich get richer, and the card
    // is dead weight in exactly the run that needs help — which is the point.
    case 'win':
      feeds = day.missedTarget ? 0 : 1;
      break;
    default:
      feeds = 1;
  }

  let gain = compounding ? 0 : base * feeds;
  if (compounding) {
    // ratchet is the excess over x1, so it starts at 0 like every other one.
    const next = (1 + (inst.ratchet || 0)) * Math.pow(base, feeds);
    gain = next - 1 - (inst.ratchet || 0);
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
