import urllib.request, xml.etree.ElementTree as ET, gzip, csv, io, concurrent.futures, pathlib
root=pathlib.Path(__file__).resolve().parent.parent; out=root/'.work/csv_goc'; out.mkdir(exist_ok=True)
base='https://openaq-data-archive.s3.amazonaws.com/'
keys=[]
for loc in ('2161299','2161301'):
 u=base+'?list-type=2&prefix=records/csv.gz/locationid%3D'+loc+'%2Fyear%3D2024%2F'
 xml=urllib.request.urlopen(u,timeout=30).read(); ns={'s':'http://s3.amazonaws.com/doc/2006-03-01/'}
 for k in ET.fromstring(xml).findall('s:Contents/s:Key',ns): keys.append(k.text)
def dl(k):
 p=out/pathlib.Path(k).name
 if not p.exists(): p.write_bytes(urllib.request.urlopen(base+k,timeout=30).read())
 return p
with concurrent.futures.ThreadPoolExecutor(max_workers=24) as ex: list(ex.map(dl,keys))
rows=[]
for p in out.glob('*.gz'):
 with gzip.open(p,'rt',encoding='utf-8-sig',newline='') as f: rows.extend(csv.DictReader(f))
rows=[r for r in rows if r.get('parameter') in ('pm25','pm10','co','no2','o3','so2')]
rows.sort(key=lambda r:(r['datetime'],r['location_id'],r['parameter'],r['sensors_id']))
from tao_sql_server import write_sql
sql=write_sql(rows,len(keys))
(root/'hanoi_air_quality_vn_source_manifest.txt').write_text('\n'.join(keys)+'\n',encoding='utf-8')
print('keys',len(keys),'rows',len(rows),'sqlbytes',sql.stat().st_size)
