"""Merge 2026/27 handbook qualification counts into the Compass v3 page (const C=[...])."""
import json, sys
src, qfile, out = sys.argv[1:4]
t = open(src).read()
i = t.index("const C=[") + 8
C, end = json.JSONDecoder().raw_decode(t[i:])
Q = {r["file"]: r for r in json.load(open(qfile))}
MAP = {"Bangor (North Wales)":"Bangor_University_-_North_Wales","Bath":"University_of_Bath","Belfast (QUB)":"Queens_University_of_Belfast",
 "Birmingham":"University_of_Birmingham","Cardiff (South Wales)":"South_Wales_-_Cardiff_University","Coventry & Warwick":"Coventry_and_Warwick",
 "East Anglia (UEA)":"University_of_East_Anglia","East London (UEL)":"University_of_East_London","Edinburgh":"University_of_Edinburgh",
 "Essex (Tavistock)":"University_of_Essex","Exeter":"University_of_Exeter","Glasgow":"University_of_Glasgow",
 "Hertfordshire":"University_of_Hertfordshire","Hull":"University_of_Hull","King's College London (IoPPN)":"King_s_College_London",
 "Lancaster":"Lancaster_University","Leeds":"University_of_Leeds","Leicester":"University_of_Leicester","Liverpool":"University_of_Liverpool",
 "Manchester":"University_of_Manchester","Newcastle":"Newcastle_University","North Thames (UCL)":"North_Thames___University_College_London",
 "Oxford":"University_of_Oxford","Plymouth":"University_of_Plymouth","Royal Holloway (North Thames)":"Royal_Holloway___University_of_London",
 "Salomons (CCCU)":"Salomons___Canterbury_Christ_Church_University","Sheffield":"University_of_Sheffield",
 "Southampton":"University_of_Southampton","Staffordshire":"Staffordshire_University","Surrey":"University_of_Surrey",
 "Teesside":"Teesside_University","Trent (Lincoln & Nottingham)":"Trent_-_Universities_of_Lincoln_and_Nottingham"}
assert len(C) == 32 and len(set(MAP.values())) == 32 and set(MAP.values()) == set(Q), set(Q) ^ set(MAP.values())
for c in C:
    q = Q[MAP[c["name"]]]
    c["qualPrev"] = c["qual"]
    c["qual"] = {"p": q["p"], "n": q["n"], "none": q["none"]}
n = sum(c["qual"]["n"] for c in C); k = sum(c["qual"]["none"] for c in C)
print("pooled", k, n, round(100*k/n, 1), "range n", min(c["qual"]["n"] for c in C), max(c["qual"]["n"] for c in C))
t = t[:i] + json.dumps(C, separators=(",", ":")) + t[i + end:]
open(out, "w").write(t)
