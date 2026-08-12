# FOOTFALL — playable build

A browser build of the game the simulator was measuring. Open `index.html`
over http, or play it on GitHub Pages.

```
python3 -m http.server 8099      # then visit /
node tools/bundle-data.mjs        # after editing anything in /data
node tools/smoke-game.mjs 30      # plays full runs headlessly, no browser
node tools/screenshot.mjs shots   # drives it in Chromium and captures each phase
```

## It shares the engine, it does not reimplement it

`src/engine.js` re-exports the simulator. Nothing about the rules lives in
`/src`:

| | |
|---|---|
| `sim/content-core.js` | the one thing that interprets `/data` |
| `sim/walk-one.js` | one customer, one wallet roll, one coin flip per slot — **the trading day** |
| `sim/day.js` | the aggregate resolver — **the projection panel** |
| `sim/shop.js`, `sim/offers.js` | placement, levelling, rent, signage, the catalogue |

That split is the game rather than an implementation detail. The panel shows you
the aggregate *expectation*; the day is the individual roll around it. You plan
against a number and then trade the day. `sim/verify.js` proves the two agree,
so the number you are shown is honest.

## Two registers

Night is a 1980s cash-and-carry catalogue — newsprint cream, CMYK at full
saturation, halftone, condensed caps, stock codes, rarity expressed as page real
estate rather than a coloured border. Day is a Richard Scarry cutaway — flat
colour, clean black line, aisles as stacked lanes, every customer type
silhouette-distinct at a glance.

Both are print, so one paper-and-ink treatment unifies them, and `--frenzy`
drives line weight, grain and the audio filter from a single parameter.

## Micro

Tap a waiting customer to serve them next. The budget is a fraction of Footfall,
so a tap is a burst rather than one person. Measured at +9.6pp — alongside tempo
and signage as a third pillar — with about half of that from using it *well*
rather than merely using it. Watch the patience bars: the Luxury customer is
worth eight Pensioners, but the Pensioner is three ticks from leaving.

## The floor is a sample when it has to be

Footfall is bounded at twelve times what the tills can serve, and a strong late
run reaches 80,000. Above `economy.day.maxWalkers` the walk stops drawing a
sprite per customer and walks a weighted sample instead: each sprite stands for
several people, and every total it touches is counted in those units.

The arithmetic of the day was always settled by the aggregate resolver; the walk
exists so you can read the shop and reach into the queue, and a sample does that
job at any scale. `tools/check-sampling.mjs` proves the sampled day still agrees
with the resolver — it is the only approximation in the project that the
resolver does not carry, so it gets its own test.

## The meta-game

Each shop climbs its own Audit ladder: survive all twenty-four days to unlock
the next rung for that character. Eight rungs, descending from about 66% to
about 8%, with each one changing a rule permanently. Progress, records and the
best day you have ever traded live in one `localStorage` key.

The end-of-run summary leads with your **best day**, not the target. The target
is only the fail condition — a good run overshoots its last one fifty times
over, and that number is what the run is remembered by.

## Keys

| | |
|---|---|
| `space` | whatever the current phase wants — open the doors, lock up, start |
| `?` | how it works |
| `esc` | close the sheet |
| `m` | mute |
