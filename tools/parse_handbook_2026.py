"""Parse the 2026/27 BPS Alternative Handbook course PDFs -> qualifications-2026-27.json.
Usage: python parse_handbook_2026.py <dir-with-pdfs> <out.json>   (needs pdfplumber)"""
import glob, json, os, re, sys, pdfplumber
src, out = sys.argv[1], sys.argv[2]
rows = []
for f in sorted(glob.glob(os.path.join(src, "*Alternative_Handbook_2026-2027_-_*.pdf"))):
    name = f.split("2026-2027_-_")[1][:-4]
    with pdfplumber.open(f) as pdf:
        t = "\n".join((p.extract_text() or "") for p in pdf.pages)
    n = int(re.search(r"received (\d+) responses", t).group(1))
    i = t.index("Additional relevant academic qualifications")
    blk = t[i:i + 800].split("Number of responses")[0]
    m = re.search(r"\nNone (\d+)", blk)
    none = int(m.group(1)) if m else 0
    rows.append({"file": name, "n": n, "none": none, "p": round(100 * none / n, 1)})
json.dump(rows, open(out, "w"), indent=1)
print(len(rows), "courses;", sum(r["none"] for r in rows), "of", sum(r["n"] for r in rows))
