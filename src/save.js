// What survives closing the tab.
//
// A roguelike without a ladder is one run repeated. The Audit ladder is
// section 16's meta-progression and it existed only in the data and the
// simulator's `--audit` flag: the browser build always played Audit I and
// forgot everything the moment you closed it.
//
// Deliberately small. One key, one object, no migrations beyond a version
// number and a hard reset — a save file for a browser game should never be the
// reason a build cannot ship.

const KEY = 'footfall.save.v1';

const EMPTY = {
  version: 1,
  // characterId -> highest Audit cleared (0 = none). Audit n+1 unlocks at n.
  cleared: {},
  runs: 0,
  wins: 0,
  // The one number the game is about.
  bestDay: 0,
  bestDayCharacter: null,
  bestClimb: 0,
  // Most recent first, capped — a shelf of receipts, not an archive.
  history: [],
  muted: false,
};

const HISTORY_MAX = 12;

let cache = null;

function read() {
  if (cache) return cache;
  let stored = null;
  try {
    stored = JSON.parse(localStorage.getItem(KEY) || 'null');
  } catch (e) {
    stored = null; // corrupt or unavailable; a fresh save beats a broken game
  }
  cache = stored && stored.version === EMPTY.version
    ? { ...EMPTY, ...stored, cleared: { ...stored.cleared } }
    : { ...EMPTY, cleared: {} };
  return cache;
}

function write() {
  try {
    localStorage.setItem(KEY, JSON.stringify(cache));
  } catch (e) {
    // Private browsing, quota, a file:// origin. The run still plays; it just
    // will not be remembered, and that is not worth interrupting anyone over.
  }
}

export const save = {
  get: () => ({ ...read() }),

  /** Highest Audit this character has cleared. 0 means none. */
  clearedFor(characterId) {
    return read().cleared[characterId] || 0;
  },

  /** The highest Audit this character may attempt: one above what it cleared. */
  unlockedFor(characterId, maxAudit) {
    return Math.min(maxAudit, this.clearedFor(characterId) + 1);
  },

  /**
   * Record a finished run. Returns what changed, so the end screen can say
   * "Audit III unlocked" rather than making the player go and look.
   */
  record({ characterId, audit, won, days, bestDay, climb, seed }) {
    const s = read();
    s.runs += 1;
    const unlocked = won && audit > (s.cleared[characterId] || 0);
    if (won) {
      s.wins += 1;
      if (unlocked) s.cleared[characterId] = audit;
    }
    const record = bestDay > s.bestDay;
    if (record) {
      s.bestDay = bestDay;
      s.bestDayCharacter = characterId;
    }
    if (climb > s.bestClimb) s.bestClimb = climb;
    s.history.unshift({ characterId, audit, won, days, bestDay, seed, at: Date.now() });
    s.history.length = Math.min(s.history.length, HISTORY_MAX);
    write();
    return { unlocked: unlocked ? audit + 1 : null, record };
  },

  /** Returns what was stored, so a caller can drive its own button off it. */
  setMuted(muted) {
    read().muted = !!muted;
    write();
    return !!muted;
  },

  clear() {
    cache = { ...EMPTY, cleared: {} };
    write();
  },
};
