# Localization

Groundwork, laid early because it gets more expensive weekly.

- **Keys are the English.** `resources/locale/strings.csv` has a `keys`
  column and an `en` column that repeat the caption; Godot imports it to
  `strings.en.translation`, listed in `project.godot`. A string with no row
  comes back from `tr()` as itself, so dynamic text — a seed, a number, a
  name from a `.tres` — is safe to pass through.
- **The door translates in its helpers.** `TitleScreen._button`, `_small`,
  `_label` and `_slider` call `tr()` on what they are handed, so a caption
  is translated once, at the one place it is drawn. Do the same in any new
  panel's helper rather than at each call.
- **Another language is a column.** Add `fr` beside `en` with every row
  filled — an empty cell is an empty caption, not a fallback — and the
  importer makes `strings.fr.translation`; list it in `project.godot`.
- **Content copy goes through `Copy`.** Artifact, boss, contract, chit,
  floor and skin copy lives in `.tres` and is drawn as data, so it is
  looked up at the moment it becomes words: `Copy.of(artifact.display_name)`
  in the panel that draws it. Neither route the groundwork proposed was
  taken — no per-locale copy of every resource, no `description_key` field —
  because the table's own rule already answers it: the English is the key.
  `Copy.upper` and `Copy.lower` translate before they case, which is the
  order that does not shout in English at a reader who is not reading it,
  and `Copy.filled` translates a sentence's shape before filling it, so the
  shape belongs to the translator too.
- **Names that arrive through the bus are translated where they are drawn.**
  The simulation puts content names into payloads and recap dictionaries and
  never translates anything; the HUD, the receipt and the room call `Copy`
  on what they take out. That keeps the rule that the simulation knows
  nothing about presentation.
- **`tools/text/extract.py` fills the table.** It reads every player-visible
  string in the content and adds a row for anything missing, never rewriting
  or reordering what is already there. `--check` reports what is missing and
  exits non-zero; CI runs that, so a new artifact ships with a row or does
  not ship.
- **A composed sentence is translated by its shape.** `Copy.filled("%d due
  when the spins run out.", [owed])` looks the shape up and fills it after,
  so a translator can move the number to where the language wants it. The
  HUD's log, the cabinet's inspection cards, the draft, the back office, the
  statement and the Clerk all compose this way now. The extractor reads
  shapes as readily as sentences, and glues adjacent literals joined by `+`
  back together first, because the join is what the player is shown.
- **The statement is shapes all the way down.** `RunRecap` is simulation
  and translates nothing, so it returns each finding and the outcome as
  `{"shape", "values"}` — `RunRecap.said(...)` builds one, `RunRecap.say(...)`
  is its English for the lab and the tests — and the paper is where they
  become words. Two shapes where a count is involved, one for "once" and one
  for "%d times", because a language that counts differently cannot be served
  by folding "3 times" into a `%s`.
- **A Control translates itself; a Label3D does not.** Godot translates a
  Label or Button's own text as it draws it, so a caption set in English
  there is fine as long as the table has a row. The cabinet's words are
  `Label3D` — the console keys, the drums' verdicts, the ledger tube, the
  brass plates — and those are drawn exactly as they are set, so they have
  to arrive translated. `Copy` is how, in both cases.
- **`tools/text/pseudo_check.gd` is the backstop.** It gives every row in
  the table a translation that is the English in ⟦brackets⟧, sets a locale
  no build ships, plays the room, and reads back every label on the screen.
  Anything with letters and no brackets never went through the table. It is
  the only check here that reads what was drawn rather than what was
  written, and it found forty-six strings the extractor could not see —
  captions set in scenes, the machine's engraving, the Clerk's paragraphs
  split across lines. CI runs it at 120 moves.

```bash
godot --headless --path . --script res://tools/text/pseudo_check.gd -- --moves=120 --list
```

- `tests/unit/test_localization.gd` holds the table loading, a runtime
  translation being honoured, and every artifact, boss and chit having a
  row.
