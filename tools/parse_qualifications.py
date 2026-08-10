import pdfplumber, re, glob, json

QH="Any additional relevant academic qualifications"
UH="Completion of a BPS accredited undergraduate degree"
SPLIT=500

def cluster(ws, tol=7):
    rows=[]
    for w in sorted(ws, key=lambda w:w['top']):
        for r in rows:
            if abs(r['top']-w['top'])<=tol: r['w'].append(w); break
        else: rows.append({'top':w['top'],'w':[w]})
    return rows

def table(ws, y0, xmin, xmax, ystop=None):
    out={}
    sel=[w for w in ws if w['top']>y0+4 and xmin<=w['x0']<xmax and (ystop is None or w['top']<ystop)]
    for r in cluster(sel):
        toks=sorted(r['w'], key=lambda t:t['x0'])
        lab=' '.join(t['text'] for t in toks if not re.fullmatch(r'\d+',t['text'])).strip()
        nums=[t['text'] for t in toks if re.fullmatch(r'\d+',t['text'])]
        if not lab or not nums: continue
        if lab.startswith('Number of responses') or lab.startswith('Copyright') or lab=='Page': continue
        if lab.startswith('Response'): continue
        out[lab]=out.get(lab,0)+int(nums[-1])
    return out

def parse(path):
    with pdfplumber.open(path) as pdf:
        for pg in pdf.pages:
            t=pg.extract_text() or ''
            if QH not in t: continue
            ws=pg.extract_words()
            qy=uy=nrY=None
            for r in cluster(ws):
                line=' '.join(x['text'] for x in sorted(r['w'],key=lambda x:x['x0']))
                if QH in line and qy is None: qy=r['top']
                if line.startswith(UH) and uy is None: uy=r['top']
                if 'Number of responses' in line and uy is not None and nrY is None and r['top']>uy: nrY=r['top']
            if qy is None or uy is None: continue
            und=table(ws, uy, 0, SPLIT, nrY)         # single-select: undergrad route
            qual=table(ws, qy, SPLIT-12, 10**6)      # multi-select: extra qualifications
            # drop footer artefacts
            for k in list(qual):
                if k.strip() in ('Page','Copyright'): qual.pop(k)
            return {"undergrad":und,"quals":qual}
    return None

res={}
for f in sorted(glob.glob('*Alternative_Handbook*.pdf')):
    c=re.search(r'__(.+)\.pdf',f).group(1)
    d=parse(f)
    if not d: print(f"{c}: NOT FOUND"); continue
    n=sum(d['undergrad'].values()); none=d['quals'].get('None',0)
    res[c]={"respondents":n,"none":none,"pct":round(none/n*100,1) if n else None,
            "quals":d['quals'],"undergrad":d['undergrad']}
    print(f"{c:<12} respondents={n:<4} none={none:<3} -> {none/n*100:5.1f}%   quals={d['quals']}")
json.dump(res,open('/tmp/qual.json','w'),indent=1)
