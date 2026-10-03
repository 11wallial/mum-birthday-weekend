"""Parse Clearing House 'Number of places for 2026 entry.xlsx' (stdlib only).
Usage: python parse_places_2026.py <file.xlsx> <out.json>"""
import json, re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
ss = [re.sub(r"<[^>]+>", "", x) for x in re.findall(r"<si>(.*?)</si>", z.read("xl/sharedStrings.xml").decode(), re.S)]
x = z.read("xl/worksheets/sheet1.xml").decode()
out = {"national": {}, "nhs": {}, "self": {}}
sec = None
for r in re.findall(r"<row [^>]*>(.*?)</row>", x, re.S):
    cells = []
    for b, v in re.findall(r'<c r="[A-Z]+\d+"([^>]*?)(?:/>|>(?:<f>.*?</f>)?(?:<v>(.*?)</v>)?.*?</c>)', r, re.S):
        cells.append(ss[int(v)] if 't="s"' in b and v else (v or ""))
    cells = [c for c in cells if c != ""]
    if not cells: continue
    s = cells[0]
    if s.startswith("Applications and places for NHS"): sec = "nhs"; continue
    if s.startswith("Applications and places for self-funded"): sec = "self"; continue
    m = re.match(r"([\d,]+) (Applicants|places)$", s)
    if m: out["national"][m.group(2).lower()] = int(m.group(1).replace(",", ""))
    m = re.match(r"(\d+)% success", s)
    if m: out["national"]["success_pct"] = int(m.group(1))
    m = re.search(r"so ([\d,]+) applications", s)
    if m: out["national"]["applications"] = int(m.group(1).replace(",", ""))
    if sec and len(cells) == 3 and cells[0].isdigit() and cells[1].isdigit():
        out[sec][cells[2]] = {"applications": int(cells[0]), "places": int(cells[1])}
json.dump(out, open(sys.argv[2], "w"), indent=1)
print(out["national"], len(out["nhs"]), "NHS rows,", len(out["self"]), "self-funded")
