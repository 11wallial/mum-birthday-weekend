"""Roll Compass competition window to 2024-26 using the Clearing House 2026 places file.
Usage: python merge_places_2026.py <page.html> <places-2026.json> <out.html> [courses-full.json]"""
import json, sys
src, pf, out = sys.argv[1:4]
t = open(src).read(); i = t.index("const C=[") + 8
C, end = json.JSONDecoder().raw_decode(t[i:])
P = json.load(open(pf))
MAP = {"Bangor (North Wales)":["Bangor - North Wales"],"Bath":["Bath"],"Birmingham":["Birmingham"],"Cardiff (South Wales)":["South Wales"],
 "Coventry & Warwick":["Coventry and Warwick"],"East Anglia (UEA)":["East Anglia"],"East London (UEL)":["East London"],"Edinburgh":["Edinburgh"],
 "Essex (Tavistock)":["Essex"],"Exeter":["Exeter"],"Glasgow":["Glasgow"],"Hertfordshire":["Hertfordshire"],
 "King's College London (IoPPN)":["Institute of Psychiatry, Psychology and Neuroscience - KCL"],
 "Lancaster":["Lancaster full-time","Lancaster part-time"],"Leeds":["Leeds"],"Leicester":["Leicester"],"Liverpool":["Liverpool"],
 "Manchester":["Manchester"],"Newcastle":["Newcastle"],"North Thames (UCL)":["University College London"],"Oxford":["Oxford"],
 "Plymouth":["Plymouth"],"Royal Holloway (North Thames)":["Royal Holloway"],"Salomons (CCCU)":["Salomons - CCCU"],"Sheffield":["Sheffield"],
 "Southampton":["Southampton"],"Staffordshire":["Staffordshire"],"Surrey":["Surrey"],"Teesside":["Teesside"],
 "Trent (Lincoln & Nottingham)":["Trent - Lincoln and Nottingham"]}
used = {k for v in MAP.values() for k in v}
assert used == set(P["nhs"]), used ^ set(P["nhs"])
tot = sum(v["applications"] for v in P["nhs"].values()) + sum(v["applications"] for v in P["self"].values())
print("applications check", tot, P["national"]["applications"])
chg = []
for c in C:
    if c["name"] not in MAP: assert c["comp"] is None; continue
    rows = [P["nhs"][k] for k in MAP[c["name"]]]
    a = sum(r["applications"] for r in rows); pl = sum(r["places"] for r in rows)
    py = dict(c["comp"]["perYear"]); c["comp"]["perYearAll"] = dict(py)
    old = c["comp"]["avg"]
    py["2026"] = {"applications": a, "places": pl, "ratio": round(a / pl, 2) if pl else None}
    c["comp"]["perYearAll"]["2026"] = py["2026"]
    py.pop("2023", None)
    use = {y: d for y, d in py.items() if d["ratio"]}
    c["comp"]["perYear"] = use
    c["comp"]["avg"] = round(sum(d["ratio"] for d in use.values()) / len(use), 1)
    chg.append((c["name"], old, c["comp"]["avg"], py["2026"]["ratio"]))
for n, o, a, r in sorted(chg, key=lambda x: x[2]): print(f"{n:34}{o:>6}{a:>6}   2026: {r}")
t = t[:i] + json.dumps(C, separators=(",", ":")) + t[i + end:]
open(out, "w").write(t)
if len(sys.argv) > 4:
    d = json.load(open(sys.argv[4])); L = d if isinstance(d, list) else d["courses"]; m = {c["name"]: c for c in C}
    for c in L:
        if c["name"] in m: c["comp"] = m[c["name"]]["comp"]
    json.dump(d, open(sys.argv[4], "w"), ensure_ascii=False, separators=(",", ":"))
