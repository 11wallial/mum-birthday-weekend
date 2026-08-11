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

Press `m` to mute.
