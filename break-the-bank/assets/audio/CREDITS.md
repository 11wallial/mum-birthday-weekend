# Audio credits and licences

Every sourced file in `assets/audio/` must appear here before it ships.
`tools/audio/audit.gd --strict` fails the build on any file that does not, and
CI runs it — an asset nobody can trace is an asset nobody can clear.

One row per file. Keep the path exactly as it appears in the manifest.

| File | Source | Author | Licence | Retrieved | Notes |
| --- | --- | --- | --- | --- | --- |
| `music/music_bed_loop.wav` | this repository, `tools/audio/compose.py` | written for Break the Bank | project-owned | 2026-09-03 | composed and rendered offline; nothing sampled |
| `music/music_fifth_loop.wav` | this repository, `tools/audio/compose.py` | written for Break the Bank | project-owned | 2026-09-03 | composed and rendered offline; nothing sampled |
| `music/music_pulse_loop.wav` | this repository, `tools/audio/compose.py` | written for Break the Bank | project-owned | 2026-09-03 | composed and rendered offline; nothing sampled |
| `ui/ui_click.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `click_002.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_hover.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `tick_002.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_back.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `back_001.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_panel_open.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `open_001.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_panel_close.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `close_001.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_purchase_confirm.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `confirmation_001.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_draft_hover.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `tick_004.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_draft_select.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `select_003.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/switch_click.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `switch_002.ogg`, decoded to 44.1 kHz mono PCM |
| `retro/crt_click.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `tick_001.ogg`, decoded to 44.1 kHz mono PCM |
| `retro/crt_beep.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `question_001.ogg`, decoded to 44.1 kHz mono PCM |
| `retro/nixie_tink.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `glass_002.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/nudge_offered.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `pluck_001.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/gamble_offered.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `question_003.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/gamble_won.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `confirmation_003.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/gamble_lost.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `error_004.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/fail_sting_ante.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `error_006.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/fail_sting_debt.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `error_008.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/system_granted.wav` | [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `maximize_004.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_chip_place.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chip-lay-1.ogg`, decoded to 44.1 kHz mono PCM |
| `ui/ui_chip_stack.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-stack-2.ogg`, decoded to 44.1 kHz mono PCM |
| `mechanical/coin_drop_single.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-collide-1.ogg`, decoded to 44.1 kHz mono PCM |
| `mechanical/coin_cascade_small.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-handle-2.ogg`, decoded to 44.1 kHz mono PCM |
| `mechanical/coin_cascade_large.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-handle-5.ogg`, decoded to 44.1 kHz mono PCM |
| `mechanical/coin_clatter_concrete.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-collide-4.ogg`, decoded to 44.1 kHz mono PCM |
| `mechanical/cash_thud.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `chips-stack-6.ogg`, decoded to 44.1 kHz mono PCM |
| `logic/contract_signed.wav` | [Kenney Casino Audio 1.1](https://kenney.nl/assets/casino-audio) | Kenney Vleugels | CC0 1.0 | 2026-09-03 | from `card-place-2.ogg`, decoded to 44.1 kHz mono PCM |

## What counts as clearable

- **CC0 / public domain** (Kenney, Freesound filtered to CC0, OpenGameArt CC0):
  no attribution required, but record it here anyway so provenance survives.
- **Sonniss #GameAudioGDC bundles**: royalty-free for commercial media
  production, no attribution required, and the sounds may not be resold or
  redistributed standalone. Note the bundle year — terms are per-bundle.
- **Pixabay**: free for commercial use without attribution under the Pixabay
  Content Licence; must not be redistributed standalone, and avoid clips
  containing recognisable trademarks.
- **CC-BY** (much of Freesound): usable, but the attribution is a shipping
  obligation. Put the exact required credit string in Notes.
- **Not clearable**: anything CC-BY-NC (non-commercial), CC-BY-ND, sample-library
  content under a per-seat licence, or a clip whose licence you could not
  confirm at download time. Re-check the licence when you download; a licence
  recorded second-hand is not a licence.
| `mechanical/reel_stop_tick_a.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/reel_stop_tick_b.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/reel_stop_tick_c.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_004.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/reel_stop_final.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_heavy_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/reel_nudge.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_light_003.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/reel_start.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/score_land.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/score_beat.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/score_break.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_heavy_003.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/score_cap.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_004.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/score_dead.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactWood_medium_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/jackpot_bells.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/payout_chime_small.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/payout_chime_big.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactBell_heavy_003.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/works_fitted.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactPlate_medium_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/vault_deposit.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactPlate_heavy_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `mechanical/vault_break.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_heavy_004.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/curse_land.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactWood_heavy_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/artifact_t1_trigger.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactTin_medium_000.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/artifact_t2_trigger.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_light_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/artifact_t3_trigger.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_003.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/artifact_t4_trigger.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactPlate_heavy_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/artifact_acquire.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactMetal_medium_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `logic/ante_settled.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactPlank_medium_001.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `ui/ui_purchase_denied.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactSoft_medium_003.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `ui/ui_toggle.wav` | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `switch_004.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `ambience/foley_drip.wav` | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `impactGlass_light_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `ui/ui_seed_type.wav` | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney Vleugels | CC0 1.0 | 2026-09-04 | from `scratch_002.ogg`, decoded to 44.1 kHz mono PCM; retrieved via the gamesounds.xyz mirror |
| `ambience/amb_room_hum_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `ambience/amb_vault_drone_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `ambience/amb_neon_buzz_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `ambience/amb_wind_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `ambience/amb_mech_clatter_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `mechanical/machine_hum_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `mechanical/coil_buzz_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `mechanical/axle_whir_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `mechanical/reel_spin_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `retro/crt_hum_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `retro/nixie_hum_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `retro/sign_buzz_loop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/ante_warning_siren.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/debt_default_alarm.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/alarm_pulse.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/heat_rising.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/mult_swell.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/debt_sting.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `mechanical/tube_overload.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/synergy_activate.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/floor_clear_fanfare.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/run_win_fanfare.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `retro/sign_pop.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
| `logic/debt_vig_deduct.wav` | this repository, `tools/audio/synth.py` | written for Break the Bank | project-owned | 2026-09-04 | rendered offline from the cue's own frequency notes; nothing sampled |
