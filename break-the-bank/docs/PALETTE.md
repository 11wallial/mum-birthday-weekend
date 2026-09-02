# The palette

The locked swatches, and the one rule. Every material in the set is built from
these in `scripts/presentation/look/materials.gd`; a colour that is not here
needs a reason in the commit.

## The room and the machine

| Swatch | Hex | Where |
| --- | --- | --- |
| Paint | `#272921` / `#373a2f` | the chassis enamel, chipped to oxide |
| Oxide | `#5a2e18` | rust, the plinth's stains, the pipe |
| Steel | `#676664` | machined parts, brackets, the lever |
| Brass | `#a97e35` | gearing, collars, the rail the tubes sit in |
| Ivory | `#98927f` | dial faces, the reel plates (never white) |
| Concrete | `#1e1d1b` | the floor, the plinth |
| Paper | `#cac4b6` | the receipt, the slate, the memos |

Shadows lean cool against the warm key: the ambient and the fog are the blue
of `#202532`, and the one fill in the room is a weak cold bounce off the left
wall. Nothing else in the set is blue.

## The electrics

| Swatch | Hex | Where |
| --- | --- | --- |
| Lamp | `#ffd49d` | the pendant's bulb, the key light |
| Nixie | `#ff8c24` | the counters, the odds, the halo behind a lit tube |
| Phosphor | `#5aff6d` | the ledger's CRT |
| Sign | per floor | the floor sign, swapped by `FloorMood` |
| Jackpot red | `#d8272121` | the heat dial's red zone, a voided pattern |

## The accent

| Swatch | Hex | Where |
| --- | --- | --- |
| **Score** | `#ffb538` | **scoring and state feedback only** |

`Materials.SCORE` lights a plate because it paid, flashes the payline bar on a
win, flares a tube as the total lands, and prints the receipt's total. It is
not on a button, a sign, a lamp or a trim. The player should learn, without
being told, that this colour flashing means the machine paid — and that
learning only holds if nothing decorative ever borrows it.

## The value structure

One bulb. The machine face is the brightest thing in the frame; the floor in
front of it steps down; the corners fall to near-black with a little warmth
left in them. A greyscale screenshot should show a bright island at the reels
and legible falloff to the frame's edges. Raising the wall wash or the ambient
to "see the room" flattens the frame into one orange midtone — the art
handover's first finding — so the room's lights are set once in `RoomSet` and
scaled per floor by `FloorMood`, and nowhere else.
