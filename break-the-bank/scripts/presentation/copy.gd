## Content copy, translated at the moment it is drawn.
##
## The door's captions go through [method Object.tr] in its helpers, but the
## larger half of this game's words are not captions: they are an artifact's
## name, a boss's tell, a floor's sign, and they live in .tres and are shown
## as data. The table's rule is that the English is the key, so a content
## string needs no key field and no per-locale copy of the resource — it needs
## looking up at the one moment it becomes words, which is here.
##
## Kept static and free of the tree so the resources stay data and the
## simulation, which never draws anything, never has to know this exists.
## [code]tools/text/extract.py --check[/code] is what makes sure every string
## has a row; CI runs it.
class_name Copy
extends RefCounted


## The translated text, or the English when the table has no row for it —
## which is also what a seed, a number or a name typed by the player does.
static func of(source: String) -> String:
	return TranslationServer.translate(source) if source != "" else ""


## Translated first, then cased. The other order shouts in English at a
## reader who is not reading English.
static func upper(source: String) -> String:
	return of(source).to_upper()


static func lower(source: String) -> String:
	return of(source).to_lower()


## Translated, then folded into a sentence: [param pattern] is itself a
## caption with a row, so the sentence's shape belongs to the translator too.
static func filled(pattern: String, values: Array) -> String:
	return of(pattern) % values
