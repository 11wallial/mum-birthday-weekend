# Scanned surfaces

Photogrammetry-derived PBR sets, three files each:

| File | What it is |
| --- | --- |
| `albedo.jpg` | Base colour. Partly desaturated — see CREDITS.md. |
| `normal.jpg` | Tangent-space normals, **OpenGL convention** (green up). |
| `arm.jpg` | Ambient occlusion (R), roughness (G), metallic (B), packed. |

The ARM packing is why there are three files and not five: Godot reads a channel
per map, so one image feeds `ao_texture`, `roughness_texture` and
`metallic_texture` at a third of the bytes.

Poly Haven serves both `nor_gl` and `nor_dx`. Take **`nor_gl`** — Godot expects
the OpenGL convention, and a DirectX normal map lights every surface as though
it were inverted, which reads as a subtly wrong surface rather than an obvious
bug.

`Materials` still owns the palette. These supply grain, wear and the roughness
break-up; the colour comes from the tint each material passes in.
