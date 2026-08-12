// The game's view of the simulator.
//
// Nothing is reimplemented here. The browser build runs the same resolver the
// balance work was done against, so what you play is what was measured.
//
//   day.js        the aggregate resolver — used for the projection panel, which
//                 is a *prediction*, so expectation is exactly the right thing
//   walk-one.js   the individual walk — used for the trading day itself, which
//                 is the roll around that prediction
//   shop.js       topology, placement, levelling, rent, signage
//   offers.js     supplier tier weights, offers, reroll costs

export { buildContent, auditModifiers } from '../sim/content-core.js';
export {
  resolveDay, collectFlags, ratchetUpkeep, ratchetUpkeepOf, ratchetCount, baseMarginFor,
  isRatchet, isMultiplicative,
} from '../sim/day.js';
export { walkIndividual } from '../sim/walk-one.js';
export {
  createShop, addFixture, autoSign, emptySlots, fixtureInstances, findInstance,
  moveFixture, ownedIds, projectRatchets, rentFor, totalSlots, marginPenaltyFromStaff,
} from '../sim/shop.js';
export { makeOffer, rerollCost, supplierUpgradeCost, tillCost, rollFixture } from '../sim/offers.js';
export { makeRng } from '../sim/rng.js';

/** The raw /data, either baked in by tools/bundle-data.mjs or fetched. */
export async function loadRawData() {
  if (typeof window !== 'undefined' && window.FOOTFALL_DATA) return window.FOOTFALL_DATA;
  const names = { customers: 'customers', fixtures: 'fixtures', economy: 'economy', run: 'run' };
  const out = {};
  await Promise.all(Object.entries(names).map(async ([key, file]) => {
    const res = await fetch(`./data/${file}.json`);
    if (!res.ok) throw new Error(`could not load data/${file}.json`);
    out[key] = await res.json();
  }));
  return out;
}
