# Break the Bank — audio design and sourcing plan

The audio system is manifest-driven. Every cue the game can play is declared in
`resources/audio/cues/*.tres`; nothing in code names a file or a volume. A cue
whose asset has not been sourced yet is **synthesised on demand**, so the
manifest can be complete long before the library is, and replacing a placeholder
with a recording is a file drop with no code change.

That inversion is the point of the whole design: **sourcing is unblocked by
implementation, and implementation is unblocked by sourcing.**

```
resources/audio/cues/*.tres   the contract: name, length, tone, variation, routing
        │
        ├── assets/audio/<category>/<id>.wav exists ──→ load it
        └── missing ──────────────────────────────────→ ProceduralCues synthesises it
```

Current state: `godot --headless --path . --script res://tools/audio/audit.gd`

---

## 1. Sound effect asset manifest

87 cues. Every row below is a real `.tres` in `resources/audio/cues/`; the
fields shown here are the ones a sourcing pass needs. `Pitch` is the per-trigger
random range, `Vol` the per-trigger dB jitter added to the authored level.

### UI & interactions — bus `UI`

| Cue | File | Length | Character | Pitch | Vol |
| --- | --- | --- | --- | --- | --- |
| `ui_hover` | `ui/ui_hover.wav` | 40–70 ms | Crisp high-mid tick, 2–6 kHz, nothing below 300 Hz — must vanish under a spin loop | 0.97–1.03 | −2.5/+1.0 |
| `ui_click` | `ui/ui_click.wav` | 60–90 ms | Dry click, 1–4 kHz body with a 6 kHz tip | 0.96–1.04 | −2.0/+1.5 |
| `ui_back` | `ui/ui_back.wav` | 70–110 ms | `ui_click` pitched down, body 700 Hz–2 kHz; reads as reversal | 0.96–1.04 | −2.0/+1.5 |
| `ui_panel_open` | `ui/ui_panel_open.wav` | 180–260 ms | Upward air whoosh 400 Hz–5 kHz, no front transient | 0.98–1.02 | −1.5/+1.0 |
| `ui_panel_close` | `ui/ui_panel_close.wav` | 160–220 ms | Mirror of open: descending, shorter, drier | 0.98–1.02 | −1.5/+1.0 |
| `ui_draft_hover` | `ui/ui_draft_hover.wav` | 60–90 ms | Card edge off felt: papery 1–3 kHz, faint 200 Hz drag | 0.96–1.04 | −2.5/+1.0 |
| `ui_draft_select` | `ui/ui_draft_select.wav` | 120–180 ms | Card snap: 2–5 kHz slap over a 150 Hz thump | 0.95–1.05 | −1.5/+1.5 |
| `ui_purchase_confirm` | `ui/ui_purchase_confirm.wav` | 250–400 ms | Two clay chips then a small 1.2 kHz chime; warm, not digital | 0.97–1.03 | −1.5/+1.5 |
| `ui_purchase_denied` | `ui/ui_purchase_denied.wav` | 140–200 ms | Dull thud under 500 Hz, deliberately unsatisfying | 0.96–1.04 | −1.5/+1.0 |
| `ui_chip_place` | `ui/ui_chip_place.wav` | 80–130 ms | Single clay chip on felt, 300 Hz–1.5 kHz, felt-damped tail | 0.93–1.07 | −3.0/+2.0 |
| `ui_chip_stack` | `ui/ui_chip_stack.wav` | 200–320 ms | Riffled stack, 6–10 overlapping knocks, randomised inner spacing | 0.94–1.06 | −2.0/+1.5 |
| `ui_seed_type` | `ui/ui_seed_type.wav` | 25–40 ms | Thin key tick 3–7 kHz — fires per character, keep it slight | 0.92–1.08 | −3.0/+1.0 |
| `ui_toggle` | `ui/ui_toggle.wav` | 70–100 ms | Detent flick, 800 Hz–3 kHz, tight | 0.95–1.05 | −2.0/+1.5 |

### Mechanical & casino — bus `SFX`, mostly positional

| Cue | File | Length | Character | Pitch | Vol |
| --- | --- | --- | --- | --- | --- |
| `reel_start` | `mechanical/reel_start.wav` | 120–180 ms | Clutch bite: 80–400 Hz motor with a 2 kHz metallic edge | 0.97–1.03 | −1.5/+1.0 |
| `reel_spin_loop` | `mechanical/reel_spin_loop.wav` | 600–900 ms **loop** | Drum whirr, 90–140 Hz fundamental + ~12 Hz flutter, **seamless** | 0.98–1.02 | −1.0/+1.0 |
| `reel_stop_tick_a/b/c` | `mechanical/…` | 60–100 ms each | Detent land: punchy 120–250 Hz thock, 3 kHz tip. Three variants, cycled per reel | 0.94–1.06 | −2.0/+1.5 |
| `reel_stop_final` | `mechanical/reel_stop_final.wav` | 140–200 ms | Heavier land, 90–200 Hz weight, longer tail — marks the line resolved | 0.96–1.04 | −1.5/+1.0 |
| `handle_pull` | `mechanical/handle_pull.wav` | 350–500 ms | Sprung lever: 200 Hz–2 kHz ratchet into a hard stop | 0.96–1.04 | −1.5/+1.5 |
| `handle_return` | `mechanical/handle_return.wav` | 200–300 ms | Spring return, softer, tail into light metal rest | 0.96–1.04 | −2.0/+1.0 |
| `coin_drop_single` | `mechanical/coin_drop_single.wav` | 90–140 ms | One coin in a metal tray: 2–6 kHz ring over 400 Hz body | 0.90–1.10 | −3.0/+2.0 |
| `coin_cascade_small` | `mechanical/coin_cascade_small.wav` | 700–1100 ms | ~12 coins, dense front thinning out; layers under the chime | 0.96–1.04 | −2.0/+1.5 |
| `coin_cascade_large` | `mechanical/coin_cascade_large.wav` | 1.6–2.4 s | Coin flood; keep 200–500 Hz mass controlled or it masks the chime | 0.98–1.02 | −1.5/+1.0 |
| `payout_chime_small` | `mechanical/payout_chime_small.wav` | 400–700 ms | Two-note rise, warm bell ~660→880 Hz | 0.97–1.03 | −1.5/+1.5 |
| `payout_chime_big` | `mechanical/payout_chime_big.wav` | 1.2–1.8 s | Three-note rise to a held fifth, partials to 5 kHz | 0.98–1.02 | −1.0/+1.0 |
| `jackpot_bells` | `mechanical/jackpot_bells.wav` | 2.0–3.0 s | Mechanical bell struck repeatedly, 1.5–4 kHz, long metallic decay | 0.99–1.01 | −1.0/+1.0 |
| `machine_hum_loop` | `mechanical/machine_hum_loop.wav` | 4–8 s **loop** | Cabinet idle: 50/60 Hz transformer hum + faint 400 Hz fan | 0.995–1.005 | ±0.5 |
| `arc_charge` | `mechanical/arc_charge.wav` | 360–520 ms | The charge cable arcing as the machine powers: gated spark-gap buzz around 1.5-2.5 kHz with hard snap transients, dying out as the charge lands. | 0.94–1.06 | −1.5/+1.5 |
| `lever_steam_release` | `mechanical/lever_steam_release.wav` | 620–880 ms | Pneumatic vent after the lever lands: broadband hiss opening fast, easing shut, low 9 Hz sputter underneath. The machine exhaling. | 0.94–1.06 | −1.5/+1.5 |
| `reel_nudge` | `mechanical/reel_nudge.wav` | 120–190 ms | A single ratchet step: pawl lifting, drum dropping one stop, pawl seating. Shorter and drier than a reel stop. | 0.97–1.05 | −1.5/+1.0 |
| `reel_stop_tick_a` | `mechanical/reel_stop_tick_a.wav` | 60–100 ms | Detent land, variant A. Punchy 120-250 Hz thock with 3 kHz tip. | 0.94–1.06 | −2.0/+1.5 |
| `reel_stop_tick_b` | `mechanical/reel_stop_tick_b.wav` | 60–100 ms | Variant B: same family, marginally brighter, so three stops never repeat. | 0.94–1.06 | −2.0/+1.5 |
| `reel_stop_tick_c` | `mechanical/reel_stop_tick_c.wav` | 60–100 ms | Variant C: same family, marginally duller and heavier. | 0.94–1.06 | −2.0/+1.5 |
| `vault_break` | `mechanical/vault_break.wav` | 420–700 ms | The same door, opened the wrong way: a strained bolt, a squeal, and a clatter. | 0.97–1.01 | −1.5/+1.0 |
| `vault_deposit` | `mechanical/vault_deposit.wav` | 380–620 ms | A drawer running out on rails, notes going in, and a heavy door shutting on them. | 0.98–1.02 | −1.5/+1.0 |
| `works_fitted` | `mechanical/works_fitted.wav` | 500–900 ms | Spanner on a bolt, a housing dropping onto its seat, and a motor picking up the new load. | 0.98–1.03 | −1.5/+1.0 |

### Game logic & triggers — bus `SFX`, stingers on `Music`

Artifact tiers are derived from unlock depth (`ArtifactDef.tier()`, floors 1–2 →
T1 … floor 7 → T4), so a late payoff never sounds like an early trinket.

| Cue | Length | Character | Pitch | Duck |
| --- | --- | --- | --- | --- |
| `artifact_t1_trigger` | 180–260 ms | Light mechanical tick, short 900 Hz ring. Frequent — must not fatigue | 0.94–1.06 | — |
| `artifact_t2_trigger` | 250–350 ms | Brass gear engaging, 400 Hz–2 kHz, slight detune | 0.95–1.05 | — |
| `artifact_t3_trigger` | 400–600 ms | Resonant hit, 80 Hz sub + 1.5 kHz bloom | 0.97–1.03 | 3 dB |
| `artifact_t4_trigger` | 700–1100 ms | Riser into sub-heavy impact, 40–70 Hz, 2 s tail | 0.99–1.01 | 6 dB |
| `artifact_acquire` | 300–450 ms | A part bolting on: ratchet then settling clunk | 0.96–1.04 | — |
| `synergy_activate` | 500–800 ms | Shimmer 1–8 kHz, harmonically related to the payout chime | 0.98–1.02 | 3 dB |
| `ante_warning_siren` | 1.2–2.0 s | Low siren 180–320 Hz, 0.7 Hz modulation; cash short of the ante | 0.99–1.01 | 6 dB |
| `ante_settled` | 300–450 ms | Rubber stamp then till clunk. Dry, administrative, final | 0.97–1.03 | — |
| `debt_vig_deduct` | 250–400 ms | Coins sliding *away*: descending, thin, ends unresolved | 0.96–1.04 | — |
| `debt_default_alarm` | 900–1400 ms | Harsh two-tone 300/450 Hz. Deliberately unpleasant | 0.99–1.01 | 8 dB |
| `floor_clear_fanfare` | 1.8–2.6 s | Four-note brass climb resolving up | 0.99–1.01 | — |
| `run_win_fanfare` | 3.0–4.0 s | Full resolution over the floor-clear motif, cascade underneath | 1.0 | — |
| `fail_sting_ante` | 1.2–1.8 s | Descending minor third into a dead stop | 0.99–1.01 | 10 dB |
| `fail_sting_debt` | 1.4–2.0 s | Lower and slower, 55 Hz sub tail — the debt took the run | 0.99–1.01 | 10 dB |
| `curse_land` | 200–300 ms | Skull lands: dull bone knock 200–800 Hz, no bright partials | 0.94–1.06 | — |
| `contract_signed` | 420–700 ms | A rubber stamp on a desk and paper being drawn away. Bureaucratic, final, faintly ominous. | 0.99–1.02 | −2 dB |
| `gamble_lost` | 420–700 ms | The whole ladder dropping out at once. Falling, damped, and over quickly. | 0.96–1.02 | −4 dB |
| `gamble_offered` | 300–500 ms | A ladder of lamps lighting in sequence, ending on a held tone that does not resolve. | 1.00–1.00 | — |
| `gamble_won` | 360–560 ms | One rung up: a bright doubled chime, higher than the last. | 1.00–1.06 | −3 dB |
| `heat_measure` | 700–1200 ms | A hard relay throw, then a siren figure that gives up halfway. Somebody has done something about you. | 0.99–1.01 | −6 dB |
| `heat_rising` | 500–900 ms | A low room tone bending upward a semitone and staying there. The sound of being noticed. | 1.00–1.00 | −2 dB |
| `nudge_offered` | 260–420 ms | Two bright electromechanical clicks and a held relay hum: the trail lamps coming up. An invitation, not an alarm. | 0.99–1.02 | — |
| `system_granted` | 900–1500 ms | A rack of contactors closing in sequence and a new circuit coming alive underneath. The machine has grown a part. | 1.00–1.00 | −6 dB |

### Ambience — bus `Ambience`

| Cue | Length | Character |
| --- | --- | --- |
| `amb_room_hum_loop` | 20–40 s **loop** | Basement air: 60–120 Hz rumble, gentle 2 kHz air, no identifiable events |
| `amb_casino_crowd_loop` | 25–45 s **loop** | Distant floor: murmur band-limited under 3 kHz, **no discrete voices**; fades in from floor 2 |
| `amb_felt_friction` | 300–600 ms | Hand or card dragging felt: soft broadband hiss rolled off above 6 kHz |
| `amb_mech_clatter_loop` | 15–30 s **loop** | Sparse distant machinery over a low bed |
| `amb_neon_buzz_loop` | 10–20 s **loop** | Failing neon: 120 Hz buzz with intermittent crackle, positional near the sign |

### Why the randomisation ranges differ

Jitter is scaled to how often a cue fires and how load-bearing it is:

- **High-frequency, low-stakes** (`ui_seed_type`, `coin_drop_single`,
  `ui_chip_place`): widest ranges, ±7–10% pitch. These fire dozens of times a
  minute and are where repetition fatigue actually appears.
- **Mid-frequency, identifying** (reel ticks, `ui_click`): ±4–6%. Enough to stop
  the machine-gun effect, not enough to blur what the sound *is*.
- **Rare and dramatic** (`jackpot_bells`, fail stings, T4 triggers): ±1–2% or
  none. A run-defining sting must sound the same every time — variation there
  reads as inconsistency, not life.

Loops get near-zero pitch jitter (±0.5%) because pitch-shifting a bed changes
its loop length and reintroduces the seam.

---

## 2. Royalty-free sourcing strategy

**Verify the licence at download time and record it in
`assets/audio/CREDITS.md`.** `tools/audio/audit.gd --strict` fails on any
sourced file with no credit entry, and CI runs it. Licence terms below were
checked in August 2026 but are the vendors' to change; a licence recorded
second-hand is not a licence.

### CC0 / public domain — start here

| Source | What to take | Licence |
| --- | --- | --- |
| **Kenney.nl** — [Casino Audio](https://kenney.nl/assets/casino-audio) (~54 sounds), [UI Audio](https://kenney.nl/assets/ui-audio) (~51), [Digital Audio](https://kenney.nl/assets/digital-audio) (~62), [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Chip handling, card snaps, the whole UI tier, coin drops | CC0 — commercial use, no attribution required |
| **Freesound.org** | Everything mechanical: lever, detents, coin trays, room tone | Filter to CC0; CC-BY is usable but the credit is a shipping obligation |
| **OpenGameArt.org** | Gap-filling stingers and fanfares | Mixed — filter to CC0/public domain, check each entry |

Kenney's Casino + UI packs alone should close most of the **UI & interactions**
tier and a good part of the coin cues. Do that pass first: it is 13 of 62 cues
at zero licensing risk.

### Studio-grade commercial royalty-free

| Source | What to take | Licence |
| --- | --- | --- |
| **[Sonniss #GameAudioGDC](https://sonniss.com/gameaudiogdc/)** — annual 20–30 GB bundles, many years | The mechanical tier: real slot machines, ratchets, servos, coin masses, room tone. This is where production quality comes from | Royalty-free for commercial media production, no attribution; **may not be resold or redistributed standalone**. Terms are per-bundle — note the year. Several bundles also prohibit AI/ML training use |
| **[Pixabay](https://pixabay.com/sound-effects/)** | Quick gap-fills, ambience beds | Pixabay Content Licence: commercial use, no attribution; no standalone redistribution; avoid clips with recognisable trademarks |
| **itch.io CC0 packs** (JDSherbert UI, Kronbits retro SFX, etc.) | Alternate UI palettes | Per-pack — read the page, they are not uniformly CC0 |

Sonniss bundles are huge and unindexed. Practical approach: download two or
three years, then search filenames offline — `rg -i "slot|ratchet|coin|lever"`
over the extracted tree beats browsing.

### Search term index

**Freesound** (append `license:"Creative Commons 0"` to every query):

```
slot machine reel spin license:"Creative Commons 0"
slot machine handle lever pull license:"Creative Commons 0"
casino chips stack riffle license:"Creative Commons 0"
poker chip single place felt license:"Creative Commons 0"
coin drop metal tray license:"Creative Commons 0"
coins many falling pile license:"Creative Commons 0"
playing card deal snap license:"Creative Commons 0"
card slide felt table license:"Creative Commons 0"
mechanical ratchet detent click license:"Creative Commons 0"
casino ambience room tone license:"Creative Commons 0"
crowd murmur distant indoor license:"Creative Commons 0"
neon sign buzz hum license:"Creative Commons 0"
transformer hum 60hz license:"Creative Commons 0"
arcade bell chime win license:"Creative Commons 0"
alarm siren low two tone license:"Creative Commons 0"
cash register till drawer license:"Creative Commons 0"
rubber stamp paper thud license:"Creative Commons 0"
```

**Pixabay** (no filter syntax; use the Sound Effects tab):

```
slot machine    casino win    coin drop    coins falling    poker chips
card shuffle    card deal     lever pull   ratchet          jackpot bell
casino ambience room tone     neon buzz    alarm siren      ui click
```

**Sonniss offline filename search**, once extracted:

```
rg -il "slot|jackpot|ratchet|detent|lever|coin|chip|card|till|register"
rg -il "roomtone|room tone|ambience|crowd|murmur|neon|transformer|hum"
```

### Sourcing order

1. **UI tier from Kenney** — 13 cues, CC0, one afternoon.
2. **Mechanical tier from Sonniss** — the 15 cues that carry the game's texture.
3. **Ambience beds** — Freesound CC0 / Sonniss room tone; these need the most
   editing (seamless loops), so budget accordingly.
4. **Logic stingers last** — most likely to be bespoke, and the tier where a
   placeholder is least embarrassing in the meantime.

### Editing requirements before a file lands

- **Mono** for anything positional; the 3D bus panning does the work.
- **Trim silence** at the head — a 20 ms lead makes every cue feel late.
- **Normalise to the authored level**, then let `base_volume_db` do the mixing.
- **Loops**: match start/end at a zero crossing and confirm no seam click.
- Land the file at exactly the manifest's `file_name`; the loader keys on it.

---

## 3. Godot architecture

### Bus layout — `default_bus_layout.tres`

```
Master   (AudioEffectLimiter: ceiling −0.8 dB, threshold −1.5)
├── Music     −6 dB    ← ducked by loud cues
├── SFX       −3 dB    (Compressor: −14 dB, 3.5:1, 12 µs attack, 120 ms release, +2 makeup)
├── UI        −4 dB    (Compressor: −18 dB, 2.5:1, 8 µs attack, 60 ms release)
└── Ambience  −10 dB   (Reverb: room 0.72, damping 0.55, 45% wet, 28 ms predelay)
```

Why this shape:

- **Limiter on Master only.** Coin cascades plus a jackpot plus a fanfare will
  clip an unprotected master. It is a safety net, not a mix tool.
- **Compressor on SFX** with a fast attack, because the mechanical tier is all
  transients — three reel detents inside 400 ms need gluing or they read as
  three unrelated events.
- **Separate UI bus** with gentler compression, so UI stays audible under a
  spin loop without being pushed into the same dynamic space as the machine.
- **Reverb on Ambience only.** Wetting the whole mix makes a small room feel
  like a car park; the beds carry the space and the dry cues sit in front.

### Node selection and polyphony

| Situation | Node | Why |
| --- | --- | --- |
| UI, stingers, fanfares | `AudioStreamPlayer` | No position; must not attenuate when the camera pulls back to the room view |
| Reels, handle, coins, machine hum, neon | `AudioStreamPlayer3D` parented to the machine | The camera moves between machine and room framing, and the machine should get closer when you do |

Pool sizes: **16 flat voices, 8 positional.** Positional is deliberately smaller
— past a handful, simultaneous 3D sources stop being localisable and become
mud. Both pools are fixed at `_ready`; nothing allocates a player at play time.

Three levels of limiting, in order:

1. **Per-cue cap** (`max_voices`): 1 for loops and stingers, 3–4 for chips and
   coins, 6 for `coin_drop_single`. Exceeding it steals that cue's oldest voice.
2. **Pool exhaustion**: steals from the lowest-`priority` cue currently sounding
   — a hover tick loses to a jackpot, never the reverse.
3. **Refusal**: if nothing lower-priority is sounding, the new cue is dropped
   rather than cutting something more important.

### Dynamic logic

Procedural variation, applied per trigger:

```gdscript
player.pitch_scale = randf_range(def.pitch_jitter.x, def.pitch_jitter.y) * pitch_bias
player.volume_db = (def.base_volume_db + master_volume_db
        + randf_range(def.volume_jitter_db.x, def.volume_jitter_db.y))
```

Ducking — declared per cue as `duck_music_db`, applied automatically:

```gdscript
func duck_music(amount_db: float) -> void:
    var bus_index: int = AudioServer.get_bus_index("Music")
    if bus_index < 0:
        return
    if _duck_tween != null and _duck_tween.is_valid():
        _duck_tween.kill()          # a second big win must not stack ducks
    _duck_tween = create_tween()
    _duck_tween.tween_method(_set_music_db, AudioServer.get_bus_volume_db(bus_index),
            _music_base_db - amount_db, DUCK_ATTACK)          # 60 ms down
    _duck_tween.tween_method(_set_music_db, _music_base_db - amount_db,
            _music_base_db, DUCK_RELEASE).set_delay(0.08)     # 450 ms back
```

Killing the previous tween matters: two payouts in quick succession would
otherwise duck twice and recover to the wrong level.

Dynamic loading, with the fallback in the same path:

```gdscript
func _stream_for(def: SoundDef) -> AudioStream:
    if _streams.has(def.id):
        return _streams[def.id]
    var stream: AudioStream = null
    if def.is_sourced():
        stream = load(def.absolute_path()) as AudioStream
    if stream == null:
        stream = ProceduralCues.make_wav(def)   # placeholder, same interface
    _streams[def.id] = stream
    return stream
```

The filesystem check happens **once per cue per run**, then it is cache lookups.

### Procedural backup

Two paths, because they answer different problems:

- **`ProceduralCues.make_wav(def)`** renders a finite buffer once — used for
  one-shots. Six shapes (`CLICK`, `TONE`, `RISE`, `FALL`, `DRONE`, `SIREN`)
  cover the manifest. Seeded from the cue id, so a placeholder sounds identical
  every launch and is never mistaken for a bug. Envelope fades top and tail so
  it never clicks.
- **`ProceduralCues.make_generator(def)` + `ProceduralLoopFeeder`** uses
  `AudioStreamGenerator` for sustained beds — a drone that runs for minutes
  should not be a minutes-long buffer:

```gdscript
func begin(def: SoundDef) -> void:
    stream = ProceduralCues.make_generator(def)   # mix_rate 22050, 100 ms buffer
    bus = String(def.bus)
    play()
    _playback = get_stream_playback() as AudioStreamGeneratorPlayback
    set_process(_playback != null)

func _process(_delta: float) -> void:
    _phase = ProceduralCues.fill_generator(_playback, _def, _phase)   # tops up each frame
```

Loops render as **one seamless second** rather than their full declared length,
with the frequency snapped to a whole number of cycles per loop so the seam is
silent.

---

## 4. Tooling

```bash
# What is sourced, what is still synthesised, what is missing a licence
godot --headless --path . --script res://tools/audio/audit.gd
godot --headless --path . --script res://tools/audio/audit.gd -- --strict   # CI gate

# Render every placeholder to WAV so a sourcing pass can hear the intent first
godot --headless --path . --script res://tools/audio/bake_placeholders.gd -- \
    --out=res://placeholder_preview
```

Adding a cue: drop a `.tres` in `resources/audio/cues/`, and it is playable
immediately as a placeholder. Sourcing a cue: drop the file at the manifest's
`file_name` and add a row to `CREDITS.md`. Neither requires touching code.


## 1b. The first playtest's list — cues added 2 September 2026

Twenty-five cues from the review's brief, each with a synthesised placeholder
of its own shape (`SoundDef.Fallback` grew from thirteen shapes to
thirty-one). The sourcing brief is the `frequency_notes` on each `.tres`.

| Cue | Bus | Where it fires | Placeholder shape |
| --- | --- | --- | --- |
| `axle_whir_loop` | SFX | the drive, from the pull to the last stop | MOTOR |
| `gear_grind` | SFX | the train taking the load on a pull | GRIND |
| `coil_buzz_loop` | Ambience | the charge coil idling, from run start | BUZZ |
| `receipt_print` | SFX | the receipt printing after a spin | PRINTER |
| `receipt_tear` | SFX | the floor closing, early or on time | TEAR |
| `coin_clatter_concrete` | SFX | a jackpot overflowing the tray | CLATTER |
| `cash_thud` | SFX | the ante settled | THUD |
| `leather_squeak` | SFX | the grip at the top of the pull | SQUEAK |
| `reel_tension` | SFX | the last drum running on with a match standing | RATCHET |
| `crt_hum_loop` | Ambience | the ledger's tube, from run start | HUM |
| `crt_click` / `crt_beep` | UI | the ledger rewriting; a new memo | CLICK / TONE |
| `nixie_tink` | UI | a counter tube changing | TINK |
| `nixie_hum_loop` / `sign_buzz_loop` | Ambience | the counters' supply; the sign's transformer | BUZZ |
| `sign_pop` | Ambience | the sign flickering, on its own clock | CLICK |
| `amb_vault_drone_loop` / `amb_wind_loop` | Ambience | the building; the vents | DRONE / WIND |
| `foley_drip` / `foley_groan` | Ambience | a puddle; the door's frame, on their own clocks | DRIP / GROAN |
| `mult_swell` | Music | a paying spin at ×2 or better, pitched by the multiplier | SWELL |
| `debt_sting` | Music | the vig, the slate, the collector | DROP |
| `alarm_pulse` | SFX | an ante missed, the House's person acting | ALARM |
| `switch_click` | UI | a reel locked, the stake stepped | SWITCH |
| `intercom_crackle` | UI | the Clerk keying the tannoy | CRACKLE |

The SFX bus carries the vault's reverb now (`Reverb_vault` in
`default_bus_layout.tres`): predelay 38 ms, a large room, damped, 22% wet.
Positional cues are placed in the room by `AudioDirector.FOLEY_AT`.

## 1c. The scoring performance — cues added 2 September 2026

Six cues for the chain, the total and the loss. The chain's beat is pitched
by the machine, a semitone a beat up a ladder of twelve
(`ScoreDirector.pitch_scale`), so `score_beat` is sourced at its root and
must take two octaves of pitch cleanly. Devices keep their own tier cues
(`artifact_t1..t4_trigger`), which now play on the device's beat rather than
the instant the lever is pulled.

| Cue | Bus | Where it fires | Placeholder shape |
| --- | --- | --- | --- |
| `score_beat` | SFX | one beat of the chain, pitched up the ladder | BELL |
| `score_break` | SFX | the rhythm break: the House, the stake, a bought row | CLACK |
| `score_cap` | SFX | the ladder past its twelfth rung — the sound of an enormous chain | BELL |
| `score_land` | SFX | the total landing after the pause | BELL |
| `score_dead` | SFX | a losing spin: one dry thud, outside the ladder | THUD |
| `tube_overload` | SFX | tier five: the tubes past what they were built for | BUZZ |

The pause before the total is silence by design: `AudioDirector.hush` drops
SFX, UI and Ambience fourteen decibels for exactly the pause and lets them
back up as the number lands. Tier five also enables a hard clip on the
master for under a second (`AudioDirector.overload`) — the one moment the
mix is allowed to distort. Sourcing for these should be done against the
timing, with the animation, never separately: the handover pairs P0.6 and
P1.4 for that reason.
