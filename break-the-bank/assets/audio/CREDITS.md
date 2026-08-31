# Audio credits and licences

Every sourced file in `assets/audio/` must appear here before it ships.
`tools/audio/audit.gd --strict` fails the build on any file that does not, and
CI runs it — an asset nobody can trace is an asset nobody can clear.

One row per file. Keep the path exactly as it appears in the manifest.

| File | Source | Author | Licence | Retrieved | Notes |
| --- | --- | --- | --- | --- | --- |
| _(none yet — every cue is currently a synthesised placeholder)_ | | | | | |

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
