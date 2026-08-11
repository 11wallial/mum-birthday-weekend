// Seeded PRNG. Every run is reproducible from a single integer, which is what
// the seeded-daily feature in section 18 needs and what makes a failing balance
// result something you can re-open rather than re-hunt.

export function makeRng(seed) {
  let s = seed >>> 0;
  if (s === 0) s = 0x9e3779b9;
  const rng = () => {
    // mulberry32
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  rng.int = (n) => Math.floor(rng() * n);
  rng.pick = (arr) => arr[rng.int(arr.length)];
  rng.shuffle = (arr) => {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = rng.int(i + 1);
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  };
  // Box-Muller, one value per call. Used for the day's sampling noise.
  rng.normal = () => {
    let u = 0; let v = 0;
    while (u === 0) u = rng();
    while (v === 0) v = rng();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  };

  /**
   * Number of successes in n trials at probability p. n may be fractional,
   * because the resolver works in expected customer counts. Exact for small
   * n, normal approximation above it — the crossover is where the
   * approximation is already good to well under a customer.
   */
  rng.binomial = (n, p) => {
    if (n <= 0 || p <= 0) return 0;
    if (p >= 1) return n;
    if (n < 30) {
      const whole = Math.floor(n);
      let k = 0;
      for (let i = 0; i < whole; i++) if (rng() < p) k++;
      if (rng() < n - whole && rng() < p) k++; // the fractional customer
      return k;
    }
    const mean = n * p;
    const sd = Math.sqrt(n * p * (1 - p));
    const x = mean + sd * rng.normal();
    return x < 0 ? 0 : x > n ? n : x;
  };

  rng.weighted = (entries) => {
    // entries: [[key, weight], ...]
    let total = 0;
    for (const [, w] of entries) total += w;
    let r = rng() * total;
    for (const [k, w] of entries) {
      r -= w;
      if (r <= 0) return k;
    }
    return entries[entries.length - 1][0];
  };
  return rng;
}
