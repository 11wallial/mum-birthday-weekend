#!/usr/bin/env python3
"""Inline data + css + js into a single self-contained trainer/index.html.

Kept self-contained deliberately: it must work from file://, from GitHub Pages,
and as a published artifact, with no fetch and no CORS.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "trainer", "src")
DATA = os.path.join(ROOT, "trainer", "data")
OUT = os.path.join(ROOT, "trainer", "index.html")

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

files = {
    "concepts":    "concepts.json",
    "items":       "items_research.json",
    "written":     "written.json",
    "interview":   "interview.json",
    "formulation": "formulation.json",
    "roleplay":    "roleplay.json",
}
payload = {}
for key, fn in files.items():
    payload[key] = json.loads(read(os.path.join(DATA, fn)))

blob = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
# safe to embed inside a <script> element
blob = blob.replace("</", "<\\/")

js = "\n".join(read(os.path.join(SRC, f)) for f in
               ["engine.js", "views-core.js", "views-modes.js", "boot.js"])

html = f"""<title>DClinPsy Trainer</title>
<meta name="description" content="A preparation engine for UK Doctorate in Clinical Psychology selection, built from real past papers and one official marking scheme.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400..800&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&display=swap" rel="stylesheet">
<style>
{read(os.path.join(SRC, 'styles.css'))}
</style>
{read(os.path.join(SRC, 'shell.html'))}
<script id="trainer-data" type="application/json">{blob}</script>
<script>
const DATA = JSON.parse(document.getElementById('trainer-data').textContent);
{js}
</script>
"""

with open(OUT, "w", encoding="utf-8") as f:
    f.write(html)

kb = len(html.encode()) / 1024
print(f"built {OUT}  ({kb:.0f} KB)")
print(f"  concepts   {len(payload['concepts']['nodes'])}")
print(f"  items      {len(payload['items']['items'])}")
print(f"  papers     {len(payload['written']['exercises'])}"
      f" ({sum(len(q['rubric']) for e in payload['written']['exercises'] for q in e['questions'])} rubric points)")
print(f"  questions  {len(payload['interview']['questions'])} in {len(payload['interview']['themes'])} themes")
print(f"  vignettes  {len(payload['formulation']['vignettes'])}")
print(f"  roleplays  {len(payload['roleplay']['scenarios'])}")
