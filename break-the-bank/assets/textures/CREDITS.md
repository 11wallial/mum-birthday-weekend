# Texture and HDRI credits

Every scanned file under `assets/textures/` and `assets/hdri/` appears here.
Same rule as the audio set: an asset nobody can trace is an asset nobody can
clear, and CC0 needing no attribution is not a reason to skip the row.

All of the below are **CC0 1.0 Universal (public domain dedication)** from
[Poly Haven](https://polyhaven.com), retrieved 2026-09-01. No attribution is
legally required; it is recorded anyway so provenance survives.

| Local path | Poly Haven asset | Licence | What it dresses |
| --- | --- | --- | --- |
| `textures/painted_metal/` | `green_metal_rust` | CC0 | Chassis paint, monitor housing, module bodies |
| `textures/rusted_metal/` | `rusty_metal_04` | CC0 | Frame, straps, brackets, pipework |
| `textures/plate_metal/` | `metal_plate` | CC0 | Brass, steel and chrome — tinted, not used raw |
| `textures/concrete/` | `concrete_floor_worn_02` | CC0 | Plinth, floor |
| `textures/plaster/` | `clay_plaster` | CC0 | Walls and dado |
| `hdri/basement_garage.hdr` | `abandoned_garage` | CC0 | Ambient light and reflections |

## These files are derived, not originals

Each was processed on the way in, and the shipped file is not what Poly Haven
serves. CC0 permits derivatives; the changes are recorded so anyone can redo
them from the source:

- **Resized to 1024²** from the 2K originals. The textures tile at one to three
  repeats per metre and the machine is a few hundred pixels tall on a phone, so
  2K was resolution nobody would ever see, at four times the download and
  sixteen times the VRAM. The HDRI is the 1K variant, which is ample for ambient
  and reflections since it is never seen directly.
- **Albedo chroma reduced to 40%.** The palette in `Materials` is tuned and
  tints by multiplication. A fully saturated scan fights that and gives five
  unrelated colour schemes; a fully grey one throws away the variation that
  makes rust read as rust. Forty per cent keeps the character and lets the
  palette lead.
- **Normal and ARM maps kept at 4:4:4.** Their channels carry direction and
  material properties rather than colour, and chroma subsampling smears them
  into each other.

## What was deliberately not used

**Quixel Megascans / Fab.** The free tier is licensed for use *in Unreal
Engine*. Using it in a Godot project is outside the grant, not a grey area, so
the host is not in the allowlist and nothing here comes from it.
