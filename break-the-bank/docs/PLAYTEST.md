# Playtesting

Nobody has played this. Every number in the balance report is calibrated
against a deliberately mediocre bot, and the roadmap's §11 says the first
human cohort is the most important thing left to do. This is the protocol for
it: who, what they play, what to watch, what to ask, and how the data gets
back into the lab.

## The builds

CI packages every push. The artifacts on the latest green run of
`claude/3d-roguelike-build-spec-g8x71r` are:

| Artifact | What | For |
| --- | --- | --- |
| `breakthebank-desktop` | one-file Windows, Linux and macOS builds | the desktop cohort |
| `breakthebank-android` | a signed arm64 APK | one or two phones, to check the touch layer |
| `breakthebank-web` | the web export | the no-install fallback; the demo later |

```bash
gh run list --branch claude/3d-roguelike-build-spec-g8x71r --limit 1
gh run download <run-id> -n breakthebank-desktop -D dist/playtest
```

macOS will refuse an unsigned app the first time; right-click → Open. The
builds are self-contained and fetch nothing.

## Before the first cohort

Known gaps a tester will hit, so nobody logs them twice:

- The door (Esc) is the pause: resume, settings (volume per bus, the reels'
  pace), skip the Clerk's lesson, abandon the run. A profile's first run is
  walked through the basement by the Clerk; watch whether the tester reads
  it or skips it, and whether they hold a pair unprompted on run two.
- Hardware on the machine carries a paper tag: its name and what it does,
  shown as it is fitted and whenever the pointer rests on it (a tap, on a
  phone). Watch whether testers find the hover on their own.
- The run ends on the statement of account, on the clipboard: the outcome
  in the House's terms, the numbers, the moves, and up to four findings —
  facts about the run in the places runs are lost. Ask the "what would you
  do differently" question *before* they read the findings, then again
  after; the difference is what the statement is worth.
- Every sound is a placeholder. Ask about the *timing* of the spin ritual,
  not the sounds.
- Two currencies: credits for the ante, chips for the draft. Ask whether the
  tester understood that the draft could not be paid from the purse, and
  whether they ever settled a floor early on purpose.
- The scoring performance is new and untuned against people. Watch for
  three things the art handover asks for: do they lean in during an
  extended last-drum stop, before the number; can they rank three replayed
  spins by payout size without reading a number; do they find hold-to-hurry
  on their own, and does a hurried payout still feel like a payout. The
  pause before the total is deliberate — note anyone who says it is too
  long, and how many spins in they say it.
- The surety column (right flank) and the picture degrading with it are the
  premise made mechanical. Ask, after a loss, what the column was doing —
  and whether they can name the decision that killed the run. The guide's
  bar is four in five.
- Three machines at the door, not seven. The Lean, the High Roller, the
  Bone Press and the Orchard are in git and return one at a time.

## The cohort

Five to eight people a week, fresh eyes each time for the first-run test, a
returning pair for the second-run test. Spread across:

- two who have never played a roguelike;
- two who have finished Balatro or CloverPit;
- one who plays slots or has, and one who dislikes them;
- one on a phone (the APK), if there is one.

Nobody who has read the design docs or watched a run.

## The session (45–60 minutes)

1. **Set-up (5 min).** The build is open at the run setup panel. Say only:
   *"You owe the House. Clear seven floors and pay it back. Everything else
   the machine will tell you."* Start the screen recording, note the seed
   shown on the setup panel, and leave the room, or sit behind them and say
   nothing.
2. **First run (until it ends, or 25 min).** Watch for the moments in the
   next section. Do not answer questions; write them down.
3. **Second run, immediately (until it ends, or 15 min).** Do they start
   one unprompted? That is the retention proxy — note the delay in seconds
   between the death screen and the next spin, or that they did not.
4. **Debrief (10 min).** The questions below, in order, without leading.
5. **Collect the recordings.** Both the screen capture and the run logs,
   next section.

## What to watch for

The bar the roadmap sets: **nine in ten first-time testers use hold and nudge
correctly, unprompted, by their second run.** Everything else is secondary.
Note the time, seed and floor for each:

- The first hold. Was it on a pair? Did they hold cheap fruit? Did they
  notice the lock is charged for?
- The first nudge. Did they read the band above the payline before taking
  it, or spend it blind? Did they decline one they were owed?
- The first draft. How long did they read it? Did they buy the dearest
  thing, the cheapest, or the one whose description they understood? Did the
  build plate beside the name (THE CLAMP, THE TRAIL…) mean anything to them?
- The first boss. Did they read the announcement, or click through? Did
  they change anything about how they played the floor?
- The stake. Did they raise it at all? When? Did they notice it costs a
  share of the ante above the first level?
- The vault, the contracts, the works. Did each get used on the floor it
  arrived, or ignored?
- Where they died, and what they said when they did. Verbatim.
- Every question they asked out loud. Verbatim.
- Run length: floor 1 under four minutes and a full run in 25–40 is the
  target. Note both.

## The debrief

1. What were you trying to do on your last floor?
2. What does holding a reel cost? What does a nudge cost?
3. Name one artifact you bought and what it did. Name one you passed on and why.
4. Who was on the floor you died on, and what did they do?
5. When would you raise the stake?
6. What was the debt doing while you played?
7. What was the best moment? The most annoying?
8. If you could change one rule, what?
9. Would you play again right now? (They already answered this; compare.)
10. Anything you wanted to look up and couldn't?

## Getting the data back

Every run writes a log of what the player did, with deliberation times, to
the user data folder:

| OS | Folder |
| --- | --- |
| macOS | `~/Library/Application Support/Break the Bank/playtests/` |
| Windows | `%APPDATA%\Break the Bank\playtests\` |
| Linux | `~/.local/share/Break the Bank/playtests/` |

Copy the folder, name it for the tester and the date, and diff each run
against what the bot does on the same seed:

```bash
godot --headless --path . --script res://tools/playtest/compare.gd -- \
    --run=user://playtests/<file>.json
```

The diff is the question §11 asks — where a person diverges from the policy,
and whether it costs or pays. Three things to feed back into the lab from a
cohort:

- **Deliberation time per decision** is the complexity signal. A draft that
  takes ninety seconds is a draft that needs tooltips more than it needs
  balance.
- **Pick rate per artifact**, from the recordings, against the lab's
  `pick_rates` — the scatter was built for human batches, and a bot's pick
  rate is mostly a statement about what it could afford.
- **Win rate by hours played.** The target on base difficulty is roughly 5%
  new, 25% competent, 50%+ mastered; the ladder absorbs the top. The first
  cohort only gives the first number.

## After the cohort

Write it up in one page under `docs/playtests/<date>.md`: the cohort, the
hold-and-nudge rate, run lengths, where they died, the five most-asked
questions, and the one change the session argues for. Then change that one
thing, measure it in the lab, and run the next cohort.
