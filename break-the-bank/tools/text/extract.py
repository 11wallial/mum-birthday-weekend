"""Puts every string the player is shown into the translator's table.

The door's captions have gone through tr() since the groundwork landed, but
the larger half of this game's words were out of reach: content copy — an
artifact's name, a boss's tell, a floor's sign — lives in .tres and is drawn
as data, and the captions written in code had no rows either. The route taken
is the one the table already uses: the English is the key. No key field per
resource, no per-locale copy of every .tres; a row, and a lookup at the moment
it is drawn.

    python3 tools/text/extract.py           # merge new strings into the table
    python3 tools/text/extract.py --check   # CI: fail if anything is missing
    python3 tools/text/extract.py --list    # what it reads, and from where

Rows already in the table are never rewritten or reordered — a translator's
work is not this script's to move — and a row whose string has left the game
stays, because a language column may still be carrying it.
"""
import argparse
import csv
import io
import re
import sys

import voice

TABLE = voice.ROOT / "resources/locale/strings.csv"

# A literal in one of the files that draws things is player text when it reads
# like text: a path, an id, a node name or a bare format specifier is not.
# voice.py's own reader is stricter on purpose — it judges prose, and "THE
# COLLECTION" has no prose to judge — but a caption still needs a row.
NOT_TEXT = re.compile(r"^(res://|user://|[a-z_]+$|%[sdfx]$)")
HAS_WORDS = re.compile(r"[A-Za-z]{2}")
NOT_DRAWN = ("push_warning", "push_error", "print(")


def table_rows() -> tuple[list[str], list[list[str]]]:
	rows = list(csv.reader(io.StringIO(TABLE.read_text(encoding="utf-8"))))
	return rows[0], [row for row in rows[1:] if row]


def content_strings() -> list[str]:
	seen: dict[str, None] = {}
	for _where, text in voice.strings_from_content(shortest=1):
		seen.setdefault(text.replace("\\n", "\n"), None)
	return list(seen)


def drawn(text: str) -> bool:
	if len(text) < 4 or NOT_TEXT.match(text) or not HAS_WORDS.search(text):
		return False
	if re.fullmatch(r"[\w./-]+", text):
		return False
	return " " in text or text.isupper()


def code_strings() -> list[str]:
	"""Captions and sentences written in the files that draw them. A composed
	sentence counts: its shape is what a translator reshapes, and the numbers
	are filled in after it."""
	seen: dict[str, None] = {}
	for name in voice.CODE:
		path = voice.ROOT / name
		if not path.exists():
			continue
		# The Clerk's lines are written as adjacent literals joined by +, across
		# several lines of source. The player is shown the join, so that is what
		# needs a row: glue them back together before reading them out.
		source = re.sub(r'"\s*\+\s*"', "", path.read_text())
		for line in source.splitlines():
			stripped = line.strip()
			if stripped.startswith("#") or any(call in stripped for call in NOT_DRAWN):
				continue
			for text in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
				if drawn(text):
					seen.setdefault(text.replace("\\n", "\n"), None)
	return list(seen)


def every_string() -> list[str]:
	seen: dict[str, None] = {}
	for text in content_strings() + code_strings():
		seen.setdefault(text, None)
	return list(seen)


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--check", action="store_true",
			help="report what is missing and exit non-zero, rather than adding it")
	parser.add_argument("--list", action="store_true", help="print every string it reads")
	args = parser.parse_args()

	if args.list:
		for text in every_string():
			print(text.replace("\n", "\\n"))
		return 0

	header, rows = table_rows()
	have = {row[0] for row in rows}
	strings = every_string()
	missing = [text for text in strings if text not in have]

	if args.check:
		print("%d of %d strings are in the table (%d in content, %d in code)" % (
			len(strings) - len(missing), len(strings),
			len(content_strings()), len(code_strings())))
		for text in missing[:20]:
			print("  missing  %s" % text.replace("\n", "\\n")[:90])
		if len(missing) > 20:
			print("  ... and %d more" % (len(missing) - 20))
		return 1 if missing else 0

	# The English fills every column: a row with an empty cell is an empty
	# caption in that language, not a fallback to the English.
	for text in missing:
		rows.append([text] + [text] * (len(header) - 1))
	out = io.StringIO()
	writer = csv.writer(out, lineterminator="\n", quoting=csv.QUOTE_ALL)
	writer.writerow(header)
	writer.writerows(rows)
	TABLE.write_text(out.getvalue(), encoding="utf-8")
	print("added %d rows; the table now holds %d" % (len(missing), len(rows)))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
