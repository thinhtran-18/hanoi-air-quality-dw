"""Tạo từ điển, draw.io, PNG và minh chứng grain từ cùng đặc tả.

Chạy tại repo: python tools/tao_thiet_ke_buoc5.py
Cần Pillow để vẽ PNG; không kết nối hay thay đổi SQL Server.
"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
from collections import Counter
from decimal import Decimal
import csv
import json
import hashlib
import html
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/thiet_ke'
EVIDENCE = ROOT / 'report/minh_chung'
# Cột: tên, kiểu SQL Server, cho NULL, khóa, ý nghĩa, ánh xạ nguồn/quy tắc.
TABLES = {
 'DimDate': [
  ('DateKey','int','Không','PK','Khóa ngày YYYYMMDD','Từ ObservedAtLocal'),
  ('FullDate','date','Không','UQ','Ngày địa phương','CAST(ObservedAtLocal AS date)'),
  ('DayOfMonth','tinyint','Không','—','Ngày trong tháng 1–31','DAY(FullDate)'),
  ('MonthNumber','tinyint','Không','—','Tháng 1–12','MONTH(FullDate)'),
  ('QuarterNumber','tinyint','Không','—','Quý 1–4','DATEPART(quarter, FullDate)'),
  ('YearNumber','smallint','Không','—','Năm địa phương','YEAR(FullDate)'),
  ('DayOfWeekISO','tinyint','Không','—','Thứ Hai=1 đến Chủ Nhật=7','Tính từ lịch, độc lập SET DATEFIRST'),
  ('DayName','nvarchar(12)','Không','—','Tên thứ tiếng Việt','Ánh xạ DayOfWeekISO')],
 'DimTime': [
  ('TimeKey','int','Không','PK','Khóa giờ HHMMSS dạng số; 00:00:00 = 0','Từ ObservedAtLocal; Hour*10000+Minute*100+Second'),
  ('FullTime','time(0)','Không','UQ','Giờ địa phương','CAST(ObservedAtLocal AS time(0))'),
  ('HourNumber','tinyint','Không','—','Giờ 0–23','DATEPART(hour, ObservedAtLocal)'),
  ('MinuteNumber','tinyint','Không','—','Phút 0–59; hiện tại 0','DATEPART(minute, ObservedAtLocal)'),
  ('SecondNumber','tinyint','Không','—','Giây 0–59; hiện tại 0','DATEPART(second, ObservedAtLocal)')],
 'DimStation': [
  ('StationKey','int IDENTITY(1,1)','Không','PK','Khóa nội bộ, không phải mã OpenAQ','Sinh tại kho'),
  ('StationId','int','Không','UQ / NK','Mã location OpenAQ','SQL: location_id; CSV: location_id'),
  ('StationName','nvarchar(160)','Không','—','Tên đầy đủ như nguồn, giữ hậu tố','SQL: location_name; CSV: location'),
  ('Latitude','decimal(10,6)','Có','—','Vĩ độ','SQL: latitude; CSV: lat'),
  ('Longitude','decimal(10,6)','Có','—','Kinh độ','SQL: longitude; CSV: lon'),
  ('CityName','nvarchar(80)','Không','—','Thành phố theo phạm vi đã chốt','Hằng cấu hình: Hà Nội'),
  ('DistrictName','nvarchar(80)','Có','—','Địa bàn quận/huyện khi có metadata xác minh','Nguồn hiện tại không có: NULL; không suy đoán')],
 'DimPollutant': [
  ('PollutantKey','int IDENTITY(1,1)','Không','PK','Khóa chất nội bộ','Sinh tại kho'),
  ('PollutantCode','nvarchar(20)','Không','UQ / NK','Mã chất: pm25 hoặc pm10','SQL/CSV: parameter; chuẩn hóa chữ thường'),
  ('PollutantName','nvarchar(40)','Không','—','Tên hiển thị PM2.5 hoặc PM10','Ánh xạ cấu hình từ PollutantCode'),
  ('Unit','nvarchar(40)','Không','—','Đơn vị chuẩn µg/m³','SQL: unit; CSV: units; kiểm tra trước nạp')],
 'DimSensor': [
  ('SensorKey','int IDENTITY(1,1)','Không','PK','Khóa cảm biến nội bộ','Sinh tại kho'),
  ('SensorId','int','Không','UQ / NK','Mã cảm biến OpenAQ','SQL: sensor_id; CSV: sensors_id'),
  ('SensorDescription','nvarchar(255)','Có','—','Mô tả phục vụ truy vết, không suy ra model/hiệu chuẩn','Sinh mô tả từ SensorId; metadata thực tế chưa có')],
 'FactAirQuality': [
  ('AirQualityKey','bigint IDENTITY(1,1)','Không','PK','Khóa kỹ thuật dòng fact; không thay khóa grain','Sinh tại kho'),
  ('DateKey','int','Không','FK → DimDate','Ngày địa phương của phép đo','Tra DimDate từ ObservedAtLocal'),
  ('TimeKey','int','Không','FK → DimTime','Giờ địa phương của phép đo','Tra DimTime từ ObservedAtLocal'),
  ('StationKey','int','Không','FK → DimStation; UQ grain','Trạm của phép đo','Tra StationId bằng location_id'),
  ('PollutantKey','int','Không','FK → DimPollutant; UQ grain','Chất của phép đo','Tra PollutantCode bằng parameter'),
  ('SensorKey','int','Không','FK → DimSensor; UQ grain','Cảm biến của phép đo','Tra SensorId bằng SQL sensor_id / CSV sensors_id'),
  ('ObservedAtSource','datetimeoffset(0)','Không','—','Thời điểm nguồn giữ nguyên offset','SQL: observed_at; CSV: datetime'),
  ('ObservedAtUTC','datetime2(0)','Không','UQ grain','Thời điểm UTC, quy ước mọi giá trị ở UTC','CAST(SWITCHOFFSET(ObservedAtSource, +00:00) AS datetime2(0))'),
  ('ObservedAtLocal','datetimeoffset(0)','Không','—','Thời điểm phân tích, luôn có offset +07:00','SWITCHOFFSET(ObservedAtSource, +07:00)'),
  ('Value','float(53)','Có','Measure','Nồng độ theo Unit của chiều chất; không cộng nồng độ','SQL/CSV: value; giữ độ chính xác kiểu nguồn, không làm tròn khi nạp'),
  ('IsValid','bit','Không','—','Đạt quy tắc kỹ thuật đã chốt; không chứng nhận hiệu chuẩn','ETL sinh theo quy tắc tài liệu; không có DEFAULT 1'),
  ('SourceId','bigint','Không','Lineage','ID bản ghi trong bảng SQL nguồn hiện hành','SQL: dbo.air_quality_hourly.id; CSV không có, không lấy số dòng CSV'),
  ('BatchId','uniqueidentifier','Không','Lineage','Mã lần nạp ETL','ETL sinh một UUID mỗi lần chạy, dùng chung các dòng của lần nạp')]
}

def write_artifacts():
 OUT.mkdir(parents=True, exist_ok=True)
 rows = [(t, *c) for t, cols in TABLES.items() for c in cols]
 with (OUT/'tu_dien_du_lieu.csv').open('w', encoding='utf-8-sig', newline='') as f:
  w=csv.writer(f); w.writerow(['Bang','Cot','Kieu_SQL_Server','Cho_NULL','Khoa','Y_nghia','Nguon_quy_tac']); w.writerows(rows)
 md=['# Từ điển dữ liệu Star Schema', '', 'Đặc tả bước 5; chưa phải bảng đã triển khai. PK: khóa chính; FK: khóa ngoại; NK: khóa tự nhiên; UQ: duy nhất. Mọi FK đều NOT NULL. Đọc cùng `thiet_ke_star_schema.md` để áp dụng các quy tắc cấp bảng.', '']
 for t, cols in TABLES.items():
  md += [f'## dbo.{t}', '', '| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |', '| --- | --- | --- | --- | --- | --- |']
  md += ['| '+' | '.join(c)+' |' for c in cols]; md += ['']
 (OUT/'tu_dien_du_lieu.md').write_text('\n'.join(md), encoding='utf-8')
 # Cùng danh sách cột và bố cục cho bản chỉnh sửa draw.io và PNG.
 positions={'DimDate':(60,140,420,370),'DimTime':(60,640,420,280),
 'DimStation':(1380,140,480,340),'DimPollutant':(1380,580,480,250),
 'DimSensor':(1380,930,480,220),'FactAirQuality':(650,260,520,550)}
 routes={'DimDate':[(480,325),(560,325),(560,370),(650,370)],
 'DimTime':[(480,780),(590,780),(590,470),(650,470)],
 'DimStation':[(1380,310),(1270,310),(1270,430),(1170,430)],
 'DimPollutant':[(1380,705),(1300,705),(1300,530),(1170,530)],
 'DimSensor':[(1380,1040),(1240,1040),(1240,630),(1170,630)]}
 mx=ET.Element('mxfile',host='app.diagrams.net'); diag=ET.SubElement(mx,'diagram',name='Star Schema'); model=ET.SubElement(diag,'mxGraphModel',grid='1',pageWidth='1920',pageHeight='1400'); root=ET.SubElement(model,'root'); ET.SubElement(root,'mxCell',id='0'); ET.SubElement(root,'mxCell',id='1',parent='0')
 im=Image.new('RGB',(1920,1400),'#f3f6fa'); dr=ImageDraw.Draw(im)
 regular=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20); bold=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',24); title=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',34)
 dr.text((60,35),'STAR SCHEMA | CHẤT LƯỢNG KHÔNG KHÍ HÀ NỘI 2024',font=title,fill='#12334a')
 dr.text((60,88),'Một dòng fact = một trạm + một cảm biến + một thời điểm UTC + một chất',font=regular,fill='#34475a')
 for t, pts in routes.items():
  dr.line(pts, fill='#51758f',width=3); x,y=pts[-1]; direction=1 if x==650 else -1
  dr.polygon([(x,y),(x-direction*13,y-7),(x-direction*13,y+7)],fill='#51758f')
  dr.text((pts[0][0]+(12 if x==650 else -100),pts[0][1]-30),'1 → nhiều',font=regular,fill='#34475a')
  e=ET.SubElement(root,'mxCell',id='edge_'+t,value='1 → nhiều',edge='1',parent='1',source=t,target='FactAirQuality',style='edgeStyle=orthogonalEdgeStyle;endArrow=block;strokeColor=#51758f;')
  g=ET.SubElement(e,'mxGeometry',relative='1',attrib={'as':'geometry'}); a=ET.SubElement(g,'Array',attrib={'as':'points'})
  for px,py in pts[1:-1]: ET.SubElement(a,'mxPoint',x=str(px),y=str(py))
 for t,cols in TABLES.items():
  x,y,w,h=positions[t]; labels=[f'{c[0]} : {c[1]}'+(' [PK]' if c[3]=='PK' else ' [FK]' if c[3].startswith('FK') else '') for c in cols]
  dr.rounded_rectangle((x,y,x+w,y+h),radius=10,fill='white',outline='#b9c8d4',width=2); dr.rectangle((x+1,y+1,x+w-1,y+48),fill='#12334a' if t=='FactAirQuality' else '#23657a'); dr.text((x+18,y+12),'dbo.'+t,font=bold,fill='white')
  for i,label in enumerate(labels):
   assert dr.textbbox((0,0),label,font=regular)[2] < w-30, label
   dr.text((x+16,y+65+i*33),label,font=regular,fill='#172f40')
  value='<b>dbo.'+t+'</b><br><br>'+'<br>'.join(html.escape(s) for s in labels)
  cell=ET.SubElement(root,'mxCell',id=t,value=value,vertex='1',parent='1',style='rounded=1;whiteSpace=wrap;html=1;align=left;verticalAlign=top;spacing=16;fontSize=18;fillColor=#ffffff;strokeColor=#23657a;')
  ET.SubElement(cell,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})
 notes=['UQ fact: (StationKey, SensorKey, ObservedAtUTC, PollutantKey)',
 'DateKey / TimeKey lấy từ giờ địa phương UTC+07. Giữ nguyên offset nguồn.',
 '5 quan hệ trực tiếp 1 → nhiều; lọc một chiều từ dimension vào fact.',
 'Không nối DimStation với DimSensor trong Power BI. Không cộng PM2.5 với PM10.',
 'Dữ liệu lịch sử không liên tục. Giờ thiếu không phải 0; trung bình chỉ trên mẫu hiện có.']
 for i,n in enumerate(notes): dr.text((60,1180+i*38),n,font=regular,fill='#172f40')
 n=ET.SubElement(root,'mxCell',id='notes',value='<br>'.join(html.escape(s) for s in notes),vertex='1',parent='1',style='text;html=1;align=left;fontSize=20;'); ET.SubElement(n,'mxGeometry',x='60',y='1180',width='1800',height='200',attrib={'as':'geometry'})
 ET.indent(mx); ET.ElementTree(mx).write(OUT/'star_schema.drawio',encoding='utf-8',xml_declaration=True)
 im.save(OUT/'star_schema.png')

def validate_source():
 src=ROOT/'data/source/hanoi_air_quality_vn_monitoring_source.csv'
 with src.open(encoding='utf-8-sig', newline='') as f: allrows=list(csv.DictReader(f))
 rows=[r for r in allrows if r['parameter'] in ('pm25','pm10')]
 keys=[]; hours=Counter(); unit=set(); sensors=set(); stations=set(); example=[]; boundary=[]
 for r in rows:
  dt=datetime.fromisoformat(r['datetime']); utc=dt.astimezone(timezone.utc); local=dt.astimezone(timezone(timedelta(hours=7)))
  assert local.year==2024 and local.minute==0 and local.second==0
  assert Decimal(r['value'])>=0
  keys.append((r['location_id'],r['sensors_id'],utc.isoformat(),r['parameter']))
  hours[local.isoformat()]+=1; unit.add(r['units']); sensors.add(r['sensors_id']); stations.add(r['location_id'])
  if r['datetime']=='2024-01-29T14:00:00+07:00': example.append(r)
  if local.hour==0 and not boundary: boundary.append({'source':r['datetime'],'utc':utc.isoformat(),'local_date_key':int(local.strftime('%Y%m%d')),'local_time_key':0})
 duplicate=sum(v-1 for v in Counter(keys).values() if v>1)
 assert duplicate==0 and len(rows)==11500 and len(sensors)==4 and len(stations)==2
 assert unit=={'µg/m³'}
 result={'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'source_rows':len(allrows),'scope_rows':len(rows),'stations':sorted(stations),'sensors':sorted(sensors),'units':sorted(unit),'duplicate_grain_rows':duplicate,'max_rows_same_local_hour':max(hours.values()),'hours_with_multiple_rows':sum(v>1 for v in hours.values()),'example_same_local_hour':example,'midnight_example':boundary,'dimension_columns':{t:len(c) for t,c in TABLES.items()},'expected_dimensions':{'DimDate':366,'DimTime':24,'DimStation':2,'DimPollutant':2,'DimSensor':4},'status':'PASS - thiết kế và kiểm tra CSV; chưa tạo bảng/nạp fact'}
 EVIDENCE.mkdir(parents=True,exist_ok=True); (EVIDENCE/'buoc5_kiem_tra_grain.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 parsed=ET.parse(OUT/'star_schema.drawio'); cells=parsed.findall('.//mxCell')
 assert sum(c.get('edge')=='1' for c in cells)==5
 for t,cols in TABLES.items():
  value=next(c.get('value') for c in cells if c.get('id')==t)
  assert all(c[0] in value for c in cols)
 print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':
 write_artifacts()
 validate_source()
