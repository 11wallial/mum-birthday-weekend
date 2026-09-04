# Sourcing the remaining cues

Sixty-six of the ninety-six cues have no file behind them; the director
synthesises a placeholder at runtime instead. This is the worksheet for
closing that, written against each cue's own `frequency_notes`, which are
already a brief.

Three routes, and the split is not arbitrary — it follows what each brief
actually asks for.

- **KENNEY** — a percussive one-shot. Kenney's CC0 packs already supply every
  sourced file in this repository, the licence is cleared, and `audit.gd
  --strict` already accepts the pattern. Pick, decode to 44.1 kHz mono PCM,
  add a CREDITS row. The file named is a starting point, not a verdict:
  nobody has heard these against the game yet.
- **SYNTH** — the brief names frequencies and says *seamless*. That is a
  synthesis spec, not a search query. `tools/audio/compose.py` already renders
  the score's loops offline with integer-cycle partials and a circular reverb
  so the join is silent; a library recording of room tone would have to be
  loop-matched by hand and still would not hit "60–120 Hz rumble, gentle 2 kHz
  air". These are cheaper and better made than found.
- **FIELD** — a real recording of a real thing: a sprung lever, a dot-matrix
  head, a voice on a tannoy. Freesound's CC0 filter is the place to start
  (`freesound.org/search/?q=…&f=license%3A%22Creative+Commons+0%22`), but it is
  thin per term — a search for a neon transformer returns one result — so
  expect to record or commission some of these.

| Cue | Destination | Route | Proposed source | The brief |
| --- | --- | --- | --- | --- |
| `alarm_pulse` | `logic/alarm_pulse.wav` | SYNTH | tools/audio/compose.py | The House's person acting, or a payment missed: an analogue alarm gated four times a second. |
| `amb_casino_crowd_loop` | `ambience/amb_casino_crowd_loop.wav` | FIELD | needs a recording — see notes | Distant floor: unintelligible murmur band-limited under 3 kHz, no discrete voices. Fades in from floor 2. |
| `amb_felt_friction` | `ambience/amb_felt_friction.wav` | FIELD | needs a recording — see notes | Hand or card dragging across felt. Soft broadband hiss, rolled off above 6 kHz. |
| `amb_mech_clatter_loop` | `ambience/amb_mech_clatter_loop.wav` | SYNTH | tools/audio/compose.py | Sparse machinery elsewhere in the building: occasional distant clunks over a low bed. |
| `amb_neon_buzz_loop` | `ambience/amb_neon_buzz_loop.wav` | SYNTH | tools/audio/compose.py | Failing neon transformer: 120 Hz buzz with intermittent crackle. Positional, near the sign. |
| `amb_room_hum_loop` | `ambience/amb_room_hum_loop.wav` | SYNTH | tools/audio/compose.py | Basement air: 60-120 Hz rumble, gentle 2 kHz air. Seamless, no identifiable events. |
| `amb_vault_drone_loop` | `ambience/amb_vault_drone_loop.wav` | SYNTH | tools/audio/compose.py | The building: distant plant, a sub-bass cavern under everything, seamless. |
| `amb_wind_loop` | `ambience/amb_wind_loop.wav` | SYNTH | tools/audio/compose.py | Wind through the iron vents: filtered noise breathing in and out, seamless. |
| `ante_settled` | `logic/ante_settled.wav` | KENNEY | Impact Sounds · impactPlank_medium_001 | Rubber stamp onto paper then a till clunk. Dry, administrative, final. |
| `ante_warning_siren` | `logic/ante_warning_siren.wav` | SYNTH | tools/audio/compose.py | Slow low siren, 180-320 Hz sweep, 0.7 Hz modulation. Plays when cash is short of the ante. |
| `arc_charge` | `mechanical/arc_charge.wav` | FIELD | needs a recording — see notes | The charge cable arcing as the machine powers: gated spark-gap buzz around 1.5-2.5 kHz with hard snap transients, dying out as the charge lands. |
| `artifact_acquire` | `logic/artifact_acquire.wav` | KENNEY | Impact Sounds · impactMetal_medium_002 | A part bolting onto the frame: ratchet then a settling metal clunk. |
| `artifact_t1_trigger` | `logic/artifact_t1_trigger.wav` | KENNEY | Impact Sounds · impactTin_medium_000 | Tier 1: light mechanical tick with a short 900 Hz ring. Cheap, frequent, must not fatigue. |
| `artifact_t2_trigger` | `logic/artifact_t2_trigger.wav` | KENNEY | Impact Sounds · impactMetal_light_001 | Tier 2: brass gear engaging, 400 Hz-2 kHz, slight detune for machinery. |
| `artifact_t3_trigger` | `logic/artifact_t3_trigger.wav` | KENNEY | Impact Sounds · impactMetal_medium_003 | Tier 3: resonant hit with 80 Hz sub and a 1.5 kHz metallic bloom. Noticeably heavier than T2. |
| `artifact_t4_trigger` | `logic/artifact_t4_trigger.wav` | KENNEY | Impact Sounds · impactPlate_heavy_002 | Tier 4: short riser into a sub-heavy impact, 40-70 Hz fundamental, tail to 2 s. Run-defining. |
| `axle_whir_loop` | `mechanical/axle_whir_loop.wav` | SYNTH | tools/audio/compose.py | The drive under load while the drums turn: a 70-110 Hz motor with the armature's whir over it, seamless. |
| `coil_buzz_loop` | `mechanical/coil_buzz_loop.wav` | SYNTH | tools/audio/compose.py | The charge coil idling on the left of the crown: a thin, high electric buzz with the odd pop, seamless. |
| `crt_hum_loop` | `retro/crt_hum_loop.wav` | SYNTH | tools/audio/compose.py | The ledger's tube, live: 50 Hz mains hum and its harmonics, a faint static crackle, the flyback whine up at 7.8 kHz, seamless. |
| `curse_land` | `logic/curse_land.wav` | KENNEY | Impact Sounds · impactWood_heavy_000 | Skull on the line: dull bone knock, 200-800 Hz, no bright partials. |
| `debt_default_alarm` | `logic/debt_default_alarm.wav` | SYNTH | tools/audio/compose.py | Harsh two-tone alarm, 300/450 Hz, deliberately unpleasant. A missed vig payment. |
| `debt_sting` | `logic/debt_sting.wav` | SYNTH | tools/audio/compose.py | The vig, the slate, the shortfall: a sub-bass drop. The number the House keeps. |
| `debt_vig_deduct` | `logic/debt_vig_deduct.wav` | SYNTH | tools/audio/compose.py | Coins sliding away from you: descending, thinner than a payout, ends unresolved. |
| `floor_clear_fanfare` | `logic/floor_clear_fanfare.wav` | SYNTH | tools/audio/compose.py | Four-note climb, brass-led, resolving up. The only routinely triumphant cue. |
| `foley_drip` | `ambience/foley_drip.wav` | KENNEY | Impact Sounds · impactGlass_light_002 (softened) | One drop into a floor puddle: a falling blip and its splash. Fires on its own clock. |
| `foley_groan` | `ambience/foley_groan.wav` | FIELD | needs a recording — see notes | The vault door's frame shifting: a low resonant metallic groan. Rare. |
| `gear_grind` | `mechanical/gear_grind.wav` | FIELD | needs a recording — see notes | The train taking up the load on a pull: a grind of teeth over a slipping buzz, gone by the time the drums are at speed. |
| `handle_pull` | `mechanical/handle_pull.wav` | FIELD | needs a recording — see notes | Sprung lever travel: rasping 200 Hz-2 kHz ratchet, ending on a hard stop. |
| `handle_return` | `mechanical/handle_return.wav` | FIELD | needs a recording — see notes | Spring return, softer than the pull, tail into a light metal rest. |
| `heat_measure` | `logic/heat_measure.wav` | FIELD | needs a recording — see notes | A hard relay throw, then a siren figure that gives up halfway. Somebody has done something about you. |
| `heat_rising` | `logic/heat_rising.wav` | SYNTH | tools/audio/compose.py | A low room tone bending upward a semitone and staying there. The sound of being noticed. |
| `intercom_crackle` | `retro/intercom_crackle.wav` | FIELD | needs a recording — see notes | The tannoy keying on for the Clerk: static, the line's hum, and the mumble of a voice — pitch and rhythm and no words. |
| `jackpot_bells` | `mechanical/jackpot_bells.wav` | KENNEY | Impact Sounds · impactBell_heavy_000 repeated | Old mechanical bell struck repeatedly, 1.5-4 kHz, long metallic decay. |
| `leather_squeak` | `mechanical/leather_squeak.wav` | FIELD | needs a recording — see notes | The tape-wrapped grip under a hand: a short wobbling squeak at the top of the pull. |
| `lever_steam_release` | `mechanical/lever_steam_release.wav` | FIELD | needs a recording — see notes | Pneumatic vent after the lever lands: broadband hiss opening fast, easing shut, low 9 Hz sputter underneath. The machine exhaling. |
| `machine_hum_loop` | `mechanical/machine_hum_loop.wav` | SYNTH | tools/audio/compose.py | Cabinet idle: 50/60 Hz transformer hum plus faint 400 Hz fan. Sits under everything. |
| `mult_swell` | `logic/mult_swell.wav` | SYNTH | tools/audio/compose.py | The multiplier climbing: detuned analogue saws rising an octave with vibrato, pitched by the chain's height. |
| `nixie_hum_loop` | `retro/nixie_hum_loop.wav` | SYNTH | tools/audio/compose.py | The counters' high-voltage supply: a faint gas-ionisation buzz under the tubes, seamless. |
| `payout_chime_big` | `mechanical/payout_chime_big.wav` | KENNEY | Impact Sounds · impactBell_heavy_003 | Three-note rise to a held fifth, brighter partials to 5 kHz. Big win. |
| `payout_chime_small` | `mechanical/payout_chime_small.wav` | KENNEY | Impact Sounds · impactBell_heavy_001 | Two-note rise, warm bell timbre around 660-880 Hz. Routine win. |
| `receipt_print` | `mechanical/receipt_print.wav` | FIELD | needs a recording — see notes | The printer setting a receipt: dot-matrix pins in bursts, a line every tenth of a second, paper feeding between. |
| `receipt_tear` | `mechanical/receipt_tear.wav` | FIELD | needs a recording — see notes | Tape torn off the spool at the floor's close: a fraying noise burst that rises with the tear. |
| `reel_nudge` | `mechanical/reel_nudge.wav` | KENNEY | Impact Sounds · impactMetal_light_003 | A single ratchet step: pawl lifting, drum dropping one stop, pawl seating. Shorter and drier than a reel stop. |
| `reel_spin_loop` | `mechanical/reel_spin_loop.wav` | SYNTH | tools/audio/compose.py | Seamless drum whirr. Fundamental 90-140 Hz plus rotational flutter near 12 Hz. Must loop with no seam click. |
| `reel_start` | `mechanical/reel_start.wav` | KENNEY | Impact Sounds · impactMetal_medium_001 | Clutch engaging: 80-400 Hz motor bite with a metallic 2 kHz edge. |
| `reel_stop_final` | `mechanical/reel_stop_final.wav` | KENNEY | Impact Sounds · impactMetal_heavy_001 | Last reel: heavier detent, 90-200 Hz weight and a longer mechanical tail. Marks the line as resolved. |
| `reel_stop_tick_a` | `mechanical/reel_stop_tick_a.wav` | KENNEY | Impact Sounds · impactMetal_medium_000 | Detent land, variant A. Punchy 120-250 Hz thock with 3 kHz tip. |
| `reel_stop_tick_b` | `mechanical/reel_stop_tick_b.wav` | KENNEY | Impact Sounds · impactMetal_medium_002 | Variant B: same family, marginally brighter, so three stops never repeat. |
| `reel_stop_tick_c` | `mechanical/reel_stop_tick_c.wav` | KENNEY | Impact Sounds · impactMetal_medium_004 | Variant C: same family, marginally duller and heavier. |
| `reel_tension` | `mechanical/reel_tension.wav` | FIELD | needs a recording — see notes | The last drum running on when the ones before it agree: a slow ratchet climbing, the machine taking its time. |
| `run_win_fanfare` | `logic/run_win_fanfare.wav` | SYNTH | tools/audio/compose.py | Full resolution over the floor_clear motif, with coin cascade underneath. |
| `score_beat` | `mechanical/score_beat.wav` | KENNEY | Impact Sounds · impactBell_heavy_002 (director pitches per rung) | One beat of the scoring chain: a small bright bell on the machine, pitched up a semitone a beat by the director. Struck brass, 1-3 kHz, short decay. |
| `score_break` | `mechanical/score_break.wav` | KENNEY | Impact Sounds · impactMetal_heavy_003 | A device firing in the chain: the rhythm break. A heavier, lower strike than the beat with a damped body — a relay closing, not a bell. |
| `score_cap` | `mechanical/score_cap.wav` | KENNEY | Impact Sounds · impactBell_heavy_004 | The ladder at its cap: the chain has run past the twelfth rung. A high double bell with a long shimmer, the one sound that means an enormous chain. |
| `score_dead` | `mechanical/score_dead.wav` | KENNEY | Impact Sounds · impactWood_medium_002 | A losing spin: one dry mechanical thud with no musical content, deliberately outside the pitch ladder. A solenoid dropping, a drawer shutting. |
| `score_land` | `mechanical/score_land.wav` | KENNEY | Impact Sounds · impactBell_heavy_000 | The total landing after the pause: one deep bell with a long decay, the beat everything stopped for. |
| `sign_buzz_loop` | `retro/sign_buzz_loop.wav` | SYNTH | tools/audio/compose.py | The floor sign's transformer: a 100 Hz buzz with sputter, seamless, from the back wall. |
| `sign_pop` | `retro/sign_pop.wav` | SYNTH | tools/audio/compose.py | The sign flickering: a pop off the transformer, now and then. |
| `synergy_activate` | `logic/synergy_activate.wav` | SYNTH | tools/audio/compose.py | Shimmer upward, 1-8 kHz, harmonically related to payout_chime so they stack cleanly. |
| `tube_overload` | `mechanical/tube_overload.wav` | SYNTH | tools/audio/compose.py | Tier five: the Nixies overbright and buzzing, the transformer past what it was built for. A hard hundred-hertz buzz with pops, clipping at the top. |
| `ui_purchase_denied` | `ui/ui_purchase_denied.wav` | KENNEY | Impact Sounds · impactSoft_medium_003 | Dull muted thud, energy under 500 Hz, deliberately unsatisfying. |
| `ui_seed_type` | `ui/ui_seed_type.wav` | KENNEY | Interface Sounds · tick_003 | Tiny mechanical key tick, 3-7 kHz. Fires per character, so keep it thin. |
| `ui_toggle` | `ui/ui_toggle.wav` | KENNEY | Interface Sounds · switch_004 | Detent flick, 800 Hz-3 kHz, tight. Cycling a starter or difficulty. |
| `vault_break` | `mechanical/vault_break.wav` | KENNEY | Impact Sounds · impactMetal_heavy_004 | The same door, opened the wrong way: a strained bolt, a squeal, and a clatter. |
| `vault_deposit` | `mechanical/vault_deposit.wav` | KENNEY | Impact Sounds · impactPlate_heavy_000 | A drawer running out on rails, notes going in, and a heavy door shutting on them. |
| `works_fitted` | `mechanical/works_fitted.wav` | KENNEY | Impact Sounds · impactPlate_medium_001 | Spanner on a bolt, a housing dropping onto its seat, and a motor picking up the new load. |

## Where that leaves it

| Route | Cues |
| --- | --- |
| KENNEY | 28 |
| SYNTH | 24 |
| FIELD | 14 |
| **Total outstanding** | **66** |

Every sourced file needs a row in `assets/audio/CREDITS.md` before it ships.
CI fails the build otherwise, which is the point of it.
