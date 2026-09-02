# Open decisions

The roadmap marks these DECIDE: calls that change downstream work and need an
owner, not a default. Each one below says what is open, what the options cost,
what it blocks, and what this repo would recommend. A decision is made by
editing this file — write the choice and the date under **Decided** — so the
reasoning travels with the code.

---

## 1. The name

**Open.** "Break the Bank" is descriptive, generic, near-unsearchable, and
already the name of a television game show, several slots apps, and a board
game. Store pages, the wordmark, the Steam URL slug and any trademark screen
all hang off it.

**Options**

- Keep it, add a subtitle that carries the identity: *Break the Bank: The
  House Keeps You*. Cheapest; the search problem stays.
- Retitle around the fiction. Candidates that are short, sayable, and read as
  a slot roguelike rather than a bank heist: *The Count* (the floor-7 system,
  and what the House does), *After Hours* (the endless offer), *Vig*, *House
  Rules*, *Ledger of Account* (the CRT's own heading), *Cold Deck*.
- Retitle around the machine: *Tesla Slots* is taken in spirit by a dozen
  apps; *The Works*, *Drums* are too plain.

**Recommendation.** Retitle now, while it costs nothing. *The Count* is the
strongest: two syllables, already in the game's vocabulary, faintly
sinister, and it names the thing the player is actually playing against.
Screen it before committing — a Steam search, a USPTO/EUIPO word-mark search
for class 9/41 (software, entertainment), and the app stores — and keep
*Break the Bank* as the working title in code, where renaming is churn.

**Blocks.** Wordmark and capsule art (§5), the store page, the demo build's
title, the web build's `index.html`. Not the code.

**Decided.** —

---

## 2. Gambling adjacency and ratings

**Open.** A slot machine with no real-money loop still meets the ratings
boards' *simulated gambling* rules and the platforms' questionnaires, and the
answer shapes who can buy it and how it can be marketed.

**What is known** (verify at submission; boards revise):

- **PEGI.** Since the 2020 revision, games that teach or glamorise real
  casino gambling are rated 18. *Balatro* received PEGI 18 in 2024 for
  "prominent gambling imagery", appealed, and was re-rated 12 on the argument
  that it teaches nothing that transfers to a casino. A three-reel fruit
  machine with holds and nudges is closer to a real machine than poker hands
  are, so expect 18 first and argue for 12 on the same ground: no real-money
  loop, no odds a casino uses, the "machine" is a build you assemble.
- **ESRB.** *Simulated Gambling* is a content descriptor, not a rating; a
  T rating is the likely outcome. The descriptor itself is what some retail
  and streaming partners filter on.
- **Apple / Google.** "Simulated gambling — frequent" pushes iOS to 17+ and
  Play to a higher age band, and both stores' review guidelines require that
  simulated gambling is clearly not real-money. This matters for the mobile
  SKU later, not for Steam.
- **Steam.** The content survey asks about gambling directly; answering
  honestly does not restrict the listing, but the "gambling" tag is one to
  avoid applying yourself.
- **Marketing.** No "spin to win", no jackpots-as-money language, no odds
  quoted as if they were a casino's, nowhere. The game's own voice — the
  House, the debt, the count — already avoids this; keep the store copy in
  it.

**Recommendation.** Fill in the PEGI questionnaire early, as if for the demo,
and get the rating back before the store page is public: a PEGI 18 discovered
at launch week is a marketing problem, and the same rating discovered six
months earlier is a design conversation about what the machine shows. Keep a
one-page "why this is not gambling" statement ready for the appeal: the reel
odds are content the player edits, the payout is a function of a build, there
is no currency and nothing to buy.

**Blocks.** Store page timing, the mobile SKU's age gate, capsule and trailer
imagery (no casino chrome, which the north star already forbids).

**Decided.** —

---

## 3. Backend scope: dailies and leaderboards

**Open.** The daily challenge and the leaderboard both work locally and both
stop at `Leaderboard.submit()`, the single seam a backend would replace.
Global rankings are a top retention driver in the genre; the question is what
serves them.

**Options**

- **Steam leaderboards only.** Free, built into Steamworks via GodotSteam,
  no accounts, no moderation. Steam-only: the web demo and any mobile SKU are
  excluded, and the daily cannot be shared across platforms.
- **A small service.** A single endpoint that accepts a run and returns
  rankings, on a serverless host (a Cloudflare Worker with D1, or the
  equivalent). Ongoing cost is small; the real costs are accounts (or
  anonymous device keys), abuse handling, and being on call for it.
- **Both.** Steam for the Steam build, the service as the source of truth,
  Steam mirrored into it. More surface for little gain at v1.0.

**What this codebase changes about the decision.** A run is its seed and its
journal, and replaying the journal headlessly is exact. A service can
therefore *verify* a submitted score by replaying it — a few hundred moves in
milliseconds — rather than trusting a number. That is an anti-cheat most
leaderboard services cannot have, it costs nothing to build because the
replayer already exists, and it makes the anonymous, account-free option
viable: a forged score has to be a forged run, and a forged run is a real run.

**Recommendation.** Ship v1.0 on Steam leaderboards, because it is free and
the launch SKU is Steam. Design the daily as if the service exists — the
submission payload is `RunJournal.to_dict()` plus the profile's ruleset key,
not a score — so the service can be added for the web demo and the mobile SKU
without changing the client's idea of what a submission is. Decide by M2 as
the roadmap says; the seam is already the right shape.

**Blocks.** The daily's design (§8), the demo's leaderboard (§12), the mobile
SKU's parity.

**Decided.** —

---

## 4. Art pipeline: authored hero pieces or constructed language

**Open.** The machine and the room are generated from primitives at
`_ready`. The roadmap's two routes: replace the hero pieces with authored
meshes and keep generation for density, or commit to the constructed look and
push its language.

**Recommendation.** Prototype both against the north star in M0 as the
roadmap says, and judge them on one frame: the machine view at 1080p,
compressed as a Twitch thumbnail. The constructed route wins only if that
frame reads as *designed*, not *assembled*. Either way the generation stays
the rigging skeleton: the simulation drives named nodes, and that contract is
what lets `announce()` refit a resumed run's hardware. An authored mesh has
to land under the same names.

**Blocks.** Every hero-art commission (§5), the modular hardware kit, the
capsule art.

**Decided.** —

---

## 5. Target run length

**Open.** Nobody has measured a human run. The playtest recorder logs dwell
per move; the first three cohorts will produce the number.

**Recommendation.** Do not pick one before the cohorts. Instrument first: the
recorder already carries `duration_ms` and per-move `dwell_ms`, and
`tools/playtest/compare.gd` reads them. Set the pacing constants (spin
duration, ceremony length, shop dwell) as a profile the moment the number
exists, so the 1×/2×/4× speed option (§7) is the same knob.

**Blocks.** Every pacing decision; nothing that can be built now.

**Decided.** —

---

## 6. SKU map, positioning, price

**Open.** v1.0 on Steam; web as the demo; mobile and consoles later.

**Recommendation.** As the roadmap has it. Premium, no purchases of any kind
inside a game about a slot machine — the ratings argument (2) depends on it.
Price in the Balatro band. The positioning line to beat remains "the slot
machine that fights back"; the floor-7 mechanic is the proof of it, and the
endless offer is the second sentence.

**Decided.** —

---

## 7. The frame: what the simulation is for

**Decided, 2 September 2026.** The premise pivot — the machine is a game
inside the casino's own simulation, the player has staked their life on
beating the House — was accepted, on the art handover's condition that the
frame have a mechanical job or be cut. The job it has: **the render degrades
with the surety.** `FilmOverlay.set_strain` drives tearing, colour fringing,
grain and brightness stutter from `RunState.surety()`, the same number the
machine's own column reads. Nothing about the frame lives only in an
opening; it is on screen every spin. The other candidates — the outer
casino intruding at floor transitions, the machine acknowledging the
simulation when pushed — stay open as additions, not alternatives.

---

## 8. The life stake: a new instrument

**Decided, 2 September 2026.** The handover proposed repurposing the heat
gauge. Rejected: HEAT is floor seven's own system, the House's count of how
loudly you are winning, and reads the other way from the stake. The stake
gets its own instrument — the **surety column** on the machine's right
flank, plumbed into `RunState.surety()`: zero while the floor's close is
covered, one when the spins left cannot reach it, and between the two what
each remaining spin would have to pay against three pars. It moves on every
spin, held through the spin and released on the beat the total lands. Named
*surety* rather than *stake* because the wager level already owns that
word on the machine (`Gauge_stake`, `RunState.stake`).

---

## 9. Machines: three, not seven

**Decided, 2 September 2026.** The balance guide asks for three deep
starting configurations rather than eight shallow ones, and it is right:
each machine multiplies the balance surface and the reviewer is one person.
The Standard, the Overdraft and the Strongbox stay. The Lean, the High
Roller, the Bone Press and the Orchard are cut from the catalogue and their
unlocks with them; their definitions are in git at `58b5fc5` and come back
one at a time, each with its own lab measurement, once the base game is
stable.

---

## 10. The bot's win rate and the human target

**Decided, 2 September 2026 — as a working relationship, to be replaced by
data.** The balance guide targets 40–60% for experienced human play at
base difficulty and effectively zero first-clears in a player's first five
runs. The lab's gate holds the automated player at 12–28% (`balance_bands`),
and the bot is neither an experienced human nor a first-timer: it plays a
competent, unimaginative game with no foresight, which is roughly a
player's tenth run. The relationship the repo works to until the cohort
says otherwise: **the bot's rate is the floor of the experienced band's
floor** — a build a person can improve on by a factor of three with
foresight the bot lacks (which decisions were load-bearing, when to settle,
what to hold) — and the first-run rate is measured by the recorder, never
by the bot. Nothing in the gate moves for the guide's numbers until the
recorder has thirty human runs. `docs/PLAYTEST.md` carries the questions.
