"""Puts every string the content carries into the translator's table.

The door's captions have gone through tr() since the groundwork landed, but
content copy — an artifact's name, a boss's tell, a floor's sign — lives in
.tres and was shown as data, which meant a translator could not reach the
larger half of the game's words. The route taken is the one the rest of the
table already uses: the English is the key. No key field per resource, no
per-locale copy of every .tres; a row, and tr() at the moment it is drawn.

    python3 tools/text/extract.py           # merge new strings into the table
    python3 tools/text/extract.py --check   # CI: fail if anything is missing

Rows already in the table are never rewritten or reordered — a translator's
work is not this script's to move — and a row whose string has left the
content stays, because a language column may still be carrying it.
"""
import argparse
import csv
import io
import pathlib
import sys

import voice

TABLE = voice.ROOT / "resources/locale/strings.csv"


def table_rows() -> tuple[list[str], list[list[str]]]:
	text = TABLE.read_text(encoding="utf-8")
	rows = list(csv.reader(io.StringIO(text)))
	return rows[0], rows[1:]


def content_strings() -> list[str]:
	seen: dict[str, None] = {}
	for _where, text in voice.strings_from_content(shortest=1):
		seen.setdefault(text.replace("\\n", "\n"), None)
	return list(seen)


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--check", action="store_true",
			help="report what is missing and exit non-zero, rather than adding it")
	args = parser.parse_args()

	header, rows = table_rows()
	have = {row[0] for row in rows if row}
	missing = [text for text in content_strings() if text not in have]

	if args.check:
		print("%d of %d content strings are in the table" % (
			len(content_strings()) - len(missing), len(content_strings())))
		for text in missing[:20]:
			print("  missing  %s" % text[:90])
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
	sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
	raise SystemExit(main())
