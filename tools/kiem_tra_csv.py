import csv,gzip,pathlib,collections,json
root=pathlib.Path(__file__).resolve().parent/'csv_goc'; rows=[]
for p in root.glob('*.gz'):
 with gzip.open(p,'rt',encoding='utf-8-sig',newline='') as f: rows.extend(csv.DictReader(f))
info={'files':len(list(root.glob('*.gz'))),'rows':len(rows),'stations':collections.Counter(r['location'] for r in rows),'parameters':collections.Counter(r['parameter'] for r in rows),'min':min(r['datetime'] for r in rows),'max':max(r['datetime'] for r in rows),'units':collections.Counter(r['units'] for r in rows),'null':sum(not r['value'] for r in rows),'negative':sum(float(r['value'])<0 for r in rows if r['value'])}
print(json.dumps(info,ensure_ascii=True))
cols=list(rows[0].keys()); out=pathlib.Path(r'D:\Kho_dl_Khaipha_dl\hanoi_air_quality_vn_monitoring_source.csv')
with out.open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=cols); w.writeheader(); w.writerows(rows)
print('source csv bytes',out.stat().st_size)
