"""Tạo phương án Snowflake/Galaxy; không tạo bảng SQL hay thay đổi Star.

Chạy: python tools/tao_luoc_do_bo_sung.py (Pillow, Arial trên Windows).
"""
from copy import deepcopy
from datetime import datetime, timedelta, timezone, date
from collections import defaultdict
from decimal import Decimal
import csv
import html
import json
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont
from tao_thiet_ke_buoc5 import TABLES, ROOT, OUT, EVIDENCE


def column(name, dtype, key, meaning, source, nullable='Không'):
    return (name, dtype, nullable, key, meaning, source)


SNOW = deepcopy(TABLES)
SNOW['DimStation'] = [c for c in TABLES['DimStation'] if c[0] != 'CityName'] + [
    column('CityKey', 'int', 'FK → DimCity', 'Thành phố của trạm', 'Tra CityCode cấu hình HAN')]
SNOW['DimPollutant'] = [c for c in TABLES['DimPollutant'] if c[0] != 'Unit'] + [
    column('UnitKey', 'int', 'FK → DimUnit', 'Đơn vị chuẩn của chất', 'Tra UnitCode UG_M3 sau kiểm tra unit/units')]
SNOW['DimCity'] = [
    column('CityKey', 'int IDENTITY(1,1)', 'PK', 'Khóa thành phố nội bộ', 'Sinh tại kho phương án'),
    column('CityCode', 'nvarchar(20)', 'UQ / NK', 'Mã cấu hình nội bộ HAN, không phải mã hành chính', 'Cấu hình phạm vi Hà Nội'),
    column('CityName', 'nvarchar(80)', '—', 'Tên thành phố', 'Hằng cấu hình Hà Nội')]
SNOW['DimUnit'] = [
    column('UnitKey', 'int IDENTITY(1,1)', 'PK', 'Khóa đơn vị nội bộ', 'Sinh tại kho phương án'),
    column('UnitCode', 'nvarchar(20)', 'UQ / NK', 'Mã đơn vị nội bộ UG_M3', 'Cấu hình đơn vị chuẩn'),
    column('UnitSymbol', 'nvarchar(40)', 'UQ', 'Ký hiệu µg/m³', 'SQL unit / CSV units sau xác minh')]

GALAXY = deepcopy(TABLES)
GALAXY['FactCoverageDaily'] = [
    column('CoverageKey', 'bigint IDENTITY(1,1)', 'PK', 'Khóa kỹ thuật fact độ phủ', 'Sinh tại phương án Galaxy'),
    column('DateKey', 'int', 'FK → DimDate; UQ grain', 'Ngày địa phương', 'Lịch đủ 366 ngày năm 2024 UTC+07'),
    column('StationKey', 'int', 'FK → DimStation; UQ grain', 'Trạm theo phạm vi', '2 trạm trong DimStation'),
    column('PollutantKey', 'int', 'FK → DimPollutant; UQ grain', 'Chất theo phạm vi', '2 chất trong DimPollutant'),
    column('ExpectedHourCount', 'tinyint', 'Measure', 'Số giờ lịch dùng làm mẫu số: 24 mỗi ngày', 'Lịch địa phương, không phải lịch vận hành trạm'),
    column('ObservedHourCount', 'tinyint', 'Measure', 'Số giờ phân biệt có ít nhất một phép đo hợp lệ', 'COUNT DISTINCT giờ local từ fact IsValid=1 theo ngày–trạm–chất'),
    column('MissingHourCount', 'tinyint', 'Measure / derived', 'Số giờ lịch không có quan sát hợp lệ', 'ExpectedHourCount - ObservedHourCount; cột tính toán'),
    column('ValidMeasurementCount', 'int', 'Measure', 'Số phép đo hợp lệ; có thể lớn hơn số giờ khi nhiều sensor', 'COUNT fact IsValid=1 theo ngày–trạm–chất'),
    column('BatchId', 'uniqueidentifier', 'Lineage', 'Mã lần tính lại độ phủ', 'ETL sinh; lưu chính sách tính và dấu vết lô trong nhật ký')]


def draw_model(stem, title, subtitle, tables, positions, edges, notes, size):
    """Một đặc tả cột và tọa độ dùng cho cả PNG và draw.io."""
    OUT.mkdir(parents=True, exist_ok=True)
    mx = ET.Element('mxfile', host='app.diagrams.net')
    dg = ET.SubElement(mx, 'diagram', name=title)
    model = ET.SubElement(dg, 'mxGraphModel', grid='1', pageWidth=str(size[0]), pageHeight=str(size[1]))
    root = ET.SubElement(model, 'root')
    ET.SubElement(root, 'mxCell', id='0')
    ET.SubElement(root, 'mxCell', id='1', parent='0')
    im = Image.new('RGB', size, '#f3f6fa')
    dr = ImageDraw.Draw(im)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)
    bold = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 24)
    heading = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 34)

    def text_cell(cid, text, x, y, w, h, fontsize=20):
        c = ET.SubElement(root, 'mxCell', id=cid, value=html.escape(text), vertex='1', parent='1',
                          style=f'text;html=1;align=left;verticalAlign=top;fontSize={fontsize};')
        ET.SubElement(c, 'mxGeometry', x=str(x), y=str(y), width=str(w), height=str(h), attrib={'as': 'geometry'})

    dr.text((50, 30), title, font=heading, fill='#12334a')
    dr.text((50, 85), subtitle, font=font, fill='#34475a')
    text_cell('title', title, 50, 30, size[0]-100, 50, 34)
    text_cell('subtitle', subtitle, 50, 85, size[0]-100, 40)
    for i, (parent, child, fk, pts, label_pos) in enumerate(edges):
        assert any(c[0] == fk and c[3].startswith('FK → '+parent) for c in tables[child])
        dr.line(pts, fill='#51758f', width=3)
        x,y = pts[-1]; prevx,prevy = pts[-2]
        if x != prevx:
            sign = 1 if x > prevx else -1
            arrow = [(x,y),(x-sign*13,y-7),(x-sign*13,y+7)]
        else:
            sign = 1 if y > prevy else -1
            arrow = [(x,y),(x-7,y-sign*13),(x+7,y-sign*13)]
        dr.polygon(arrow, fill='#51758f')
        dr.text(label_pos, '1 → N', font=font, fill='#34475a')
        edge = ET.SubElement(root, 'mxCell', id=f'e{i}', source=parent, target=child,
            value=f'1 → N ({fk})', edge='1', parent='1',
            style='edgeStyle=orthogonalEdgeStyle;endArrow=block;strokeColor=#51758f;fontSize=16;')
        geo = ET.SubElement(edge, 'mxGeometry', relative='1', attrib={'as':'geometry'})
        points = ET.SubElement(geo, 'Array', attrib={'as':'points'})
        for px,py in pts[1:-1]:
            ET.SubElement(points, 'mxPoint', x=str(px), y=str(py))
    for table, cols in tables.items():
        x,y,w,h = positions[table]
        dr.rounded_rectangle((x,y,x+w,y+h), radius=9, fill='white', outline='#b9c8d4', width=2)
        dr.rectangle((x+1,y+1,x+w-1,y+48), fill='#12334a' if table.startswith('Fact') else '#23657a')
        dr.text((x+16,y+11), table, font=bold, fill='white')
        labels=[]
        for i,c in enumerate(cols):
            tag = ' [PK]' if c[3]=='PK' else ' [FK]' if c[3].startswith('FK') else ''
            label = f'{c[0]} : {c[1]}{tag}'
            assert dr.textbbox((0,0),label,font=font)[2] < w-28, label
            assert 64+i*32+25 < h, (table, h)
            labels.append(label)
            dr.text((x+14,y+64+i*32),label,font=font,fill='#172f40')
        c=ET.SubElement(root,'mxCell',id=table,vertex='1',parent='1',
            value='<b>'+table+'</b><br><br>'+'<br>'.join(html.escape(l) for l in labels),
            style='rounded=1;whiteSpace=wrap;html=1;align=left;verticalAlign=top;spacing=14;fontSize=18;fillColor=#ffffff;strokeColor=#23657a;')
        ET.SubElement(c,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})
    for i,note in enumerate(notes):
        y=size[1]-180+i*36
        assert dr.textbbox((0,0),note,font=font)[2] < size[0]-100
        dr.text((50,y),note,font=font,fill='#172f40')
        text_cell(f'note{i}',note,50,y,size[0]-100,35)
    ET.indent(mx)
    ET.ElementTree(mx).write(OUT/f'{stem}.drawio',encoding='utf-8',xml_declaration=True)
    im.save(OUT/f'{stem}.png')
    # Từ điển đầy đủ của từng phương án, không đổi từ điển Star được chọn.
    md=[f'# Từ điển phương án {title}', '', 'Phương án thiết kế để so sánh. Chưa tạo bảng SQL; mô hình triển khai chính vẫn là Star Schema.', '']
    for t,cols in tables.items():
        md += [f'## {t}', '', '| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |', '| --- | --- | --- | --- | --- | --- |']
        md += ['| '+' | '.join(c)+' |' for c in cols]+['']
    (OUT/f'tu_dien_{stem}.md').write_text('\n'.join(md),encoding='utf-8')
    parsed=ET.parse(OUT/f'{stem}.drawio')
    assert len(parsed.findall('.//mxCell[@edge="1"]'))==len(edges)
    return {'tables':len(tables),'facts':sum(t.startswith('Fact') for t in tables),
            'columns':sum(len(c) for c in tables.values()),'relationships':len(edges),'status':'PASS'}


def coverage_evidence():
    with (ROOT/'data/source/hanoi_air_quality_vn_monitoring_source.csv').open(encoding='utf-8-sig') as f:
        rows=list(csv.DictReader(f))
    hours=defaultdict(set); counts=defaultdict(int)
    for r in rows:
        if r['parameter'] not in ('pm25','pm10') or r['location_id'] not in ('2161299','2161301'):
            continue
        dt=datetime.fromisoformat(r['datetime']).astimezone(timezone(timedelta(hours=7)))
        if dt.year!=2024 or r['units']!='µg/m³' or not r['value'] or Decimal(r['value'])<0:
            continue
        k=(dt.date().isoformat(),r['location_id'],r['parameter'])
        hours[k].add(dt.hour); counts[k]+=1
    output=[]
    for i in range(366):
        day=(date(2024,1,1)+timedelta(days=i)).isoformat()
        for station in ('2161299','2161301'):
            for pollutant in ('pm25','pm10'):
                k=(day,station,pollutant); observed=len(hours[k])
                output.append([day,station,pollutant,24,observed,24-observed,counts[k]])
    assert len(output)==1464 and sum(x[6] for x in output)==11500
    expected={('2161299','pm25'):3251,('2161299','pm10'):3253,('2161301','pm25'):2498,('2161301','pm10'):2498}
    annual=[]
    for (s,p),n in expected.items():
        group=[r for r in output if r[1:3]==[s,p]]
        obs=sum(r[4] for r in group); total=sum(r[3] for r in group)
        assert obs==n and total==8784 and sum(r[5] for r in group)==8784-n
        annual.append({'StationId':s,'PollutantCode':p,'ExpectedHourCount':total,'ObservedHourCount':obs,'MissingHourCount':total-obs})
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    with (EVIDENCE/'buoc5_galaxy_do_phu_ngay.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.writer(f); w.writerow(['LocalDate','StationId','PollutantCode','ExpectedHourCount','ObservedHourCount','MissingHourCount','ValidMeasurementCount']); w.writerows(output)
    return {'daily_rows':len(output),'annual':annual,'status':'PASS - minh họa tính từ CSV; chưa nạp fact Galaxy'}


def main():
    snow_positions={'DimDate':(50,170,430,370),'DimTime':(50,650,430,270),
        'FactAirQuality':(620,280,540,520),'DimStation':(1300,170,470,350),
        'DimPollutant':(1300,650,470,250),'DimSensor':(1300,1010,470,200),
        'DimCity':(1950,170,430,220),'DimUnit':(1950,650,430,220)}
    snow_edges=[
        ('DimDate','FactAirQuality','DateKey',[(480,350),(550,350),(550,390),(620,390)],(490,320)),
        ('DimTime','FactAirQuality','TimeKey',[(480,780),(575,780),(575,455),(620,455)],(490,750)),
        ('DimStation','FactAirQuality','StationKey',[(1300,345),(1230,345),(1230,490),(1160,490)],(1235,315)),
        ('DimPollutant','FactAirQuality','PollutantKey',[(1300,775),(1250,775),(1250,555),(1160,555)],(1230,740)),
        ('DimSensor','FactAirQuality','SensorKey',[(1300,1110),(1205,1110),(1205,620),(1160,620)],(1210,1075)),
        ('DimCity','DimStation','CityKey',[(1950,280),(1860,280),(1860,345),(1770,345)],(1810,250)),
        ('DimUnit','DimPollutant','UnitKey',[(1950,760),(1870,760),(1870,775),(1770,775)],(1810,720))]
    snow=draw_model('snowflake_schema','SNOWFLAKE | LƯỢC ĐỒ BÔNG TUYẾT',
        'Phương án so sánh: chuẩn hóa địa lý và đơn vị; giữ nguyên grain phép đo của Star.',SNOW,snow_positions,snow_edges,
        ['1 → N: từ bảng cha sang bảng chứa FK. DimCity → DimStation → Fact; DimUnit → DimPollutant → Fact.',
         'UQ fact: (StationKey, SensorKey, ObservedAtUTC, PollutantKey). Ngày/giờ lấy theo UTC+07.',
         'DistrictName chưa có metadata xác minh: NULL. CityCode / UnitCode là mã cấu hình nội bộ.',
         'Chỉ là phương án thiết kế. Chọn STAR để triển khai SQL Server, ETL và Power BI.'],(2430,1490))
    galaxy_positions={'DimDate':(700,160,470,370),'DimStation':(1330,160,480,350),
        'DimPollutant':(1970,160,480,250),'FactAirQuality':(700,720,550,520),
        'FactCoverageDaily':(1650,720,650,400),'DimTime':(50,660,440,270),'DimSensor':(50,1050,440,200)}
    galaxy_edges=[
        ('DimDate','FactAirQuality','DateKey',[(850,530),(850,720)],(865,590)),
        ('DimStation','FactAirQuality','StationKey',[(1440,510),(1440,630),(1060,630),(1060,720)],(1080,600)),
        ('DimPollutant','FactAirQuality','PollutantKey',[(2040,410),(2040,570),(1170,570),(1170,720)],(1220,540)),
        ('DimDate','FactCoverageDaily','DateKey',[(1170,345),(1220,345),(1220,660),(1760,660),(1760,720)],(1560,630)),
        ('DimStation','FactCoverageDaily','StationKey',[(1580,510),(1580,610),(1950,610),(1950,720)],(1840,580)),
        ('DimPollutant','FactCoverageDaily','PollutantKey',[(2260,410),(2260,720)],(2270,540)),
        ('DimTime','FactAirQuality','TimeKey',[(490,795),(590,795),(590,880),(700,880)],(510,765)),
        ('DimSensor','FactAirQuality','SensorKey',[(490,1150),(610,1150),(610,980),(700,980)],(510,1120))]
    galaxy=draw_model('galaxy_schema','GALAXY | LƯỢC ĐỒ DẢI NGÂN HÀ',
        'Hai fact khác grain, dùng chung DimDate / DimStation / DimPollutant. Các giao điểm đường nối không tạo quan hệ.',
        GALAXY,galaxy_positions,galaxy_edges,
        ['FactAirQuality: trạm + cảm biến + thời điểm UTC + chất. FactCoverageDaily: ngày local + trạm + chất.',
         'UQ độ phủ: (DateKey, StationKey, PollutantKey). Không nối trực tiếp hai fact, không gắn DimTime/DimSensor vào fact ngày.',
         'Giờ có đo = số giờ phân biệt có phép đo hợp lệ; giờ thiếu = 24 - giờ có đo. Giờ thiếu không phải nồng độ 0.',
         'Phương án mở rộng để so sánh; triển khai chính vẫn là STAR. CoverageDaily chưa được tạo trong SQL Server.'],(2500,1550))
    result={'snowflake':snow,'galaxy':galaxy,'coverage_csv_check':coverage_evidence(),'selected_implementation':'Star Schema'}
    (EVIDENCE/'buoc5_kiem_tra_ba_luoc_do.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
