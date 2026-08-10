import pdfplumber, json, re, glob, os

def parse(path):
    out={"nhs":{}, "self":{}, "national":{}}
    section=None
    with pdfplumber.open(path) as pdf:
        for pg in pdf.pages:
            rows={}
            for w in pg.extract_words():
                rows.setdefault(round(w['top']/2)*2, []).append((w['x0'], w['text']))
            for k in sorted(rows):
                line=sorted(rows[k], key=lambda t:t[0])
                txt=' '.join(t for _,t in line)
                if 'self-funded course centres' in txt: section='self'; continue
                if 'NHS course centres' in txt and 'Applications' in txt: section='nhs'; continue
                m=re.search(r'([\d,]+)\s*Applicants', txt);  out['national'].setdefault('applicants', m.group(1)) if m else None
                m=re.search(r'([\d,]+)\s*places', txt);      out['national'].setdefault('places', m.group(1)) if m else None
                m=re.search(r'(\d+)%\s*success', txt);       out['national'].setdefault('success_pct', m.group(1)) if m else None
                if section is None: continue
                if txt.startswith('Applications'): continue
                apps=''.join(t for x,t in line if x<160).replace(',','')
                plcs=''.join(t for x,t in line if 160<=x<178).replace(',','')
                name=' '.join(t for x,t in line if x>=178).strip()
                if not (apps.isdigit() and plcs.isdigit() and name): continue
                out[section][name]={"applications":int(apps), "places":int(plcs)}
    return out

res={}
for f in sorted(glob.glob('*Number_of_places*.pdf')):
    yr=re.search(r'(20\d\d)_entry', f).group(1)
    res[yr]=parse(f)
    n=res[yr]['national']
    print(f"--- {yr}: national {n} | NHS centres {len(res[yr]['nhs'])} | self-funded {len(res[yr]['self'])}")
json.dump(res, open('/tmp/places.json','w'), indent=1)
