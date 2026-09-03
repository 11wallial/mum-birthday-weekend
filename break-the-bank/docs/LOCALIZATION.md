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
- **Content is not here yet.** Artifact, boss, contract and chit copy
  lives in `.tres` files and is shown as data. The route for that is
  Godot's resource remaps per locale, or a `description_key` per resource;
  neither is built. The HUD's prompts, the Clerk's lines and the
  statement's sentences are still literals in code.
- `tests/unit/test_localization.gd` holds the table loading and a
  runtime translation being honoured.
