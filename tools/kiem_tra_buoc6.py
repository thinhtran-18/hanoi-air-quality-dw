"""Doi chieu metadata SQL voi tu dien Star, luu minh chung va ve so do tu kho that.

Mac dinh chi doc, in ket qua. --write ghi JSON/PNG; --test-constraints chay
SQL kiem thu transaction/ROLLBACK tren kho chua nap ETL. Khong cai them driver.
SQLCMD dung Windows Authentication; HANOI_SQL_SERVER co the doi server cuc bo.
"""
import argparse
import csv
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'report/minh_chung'
CORE = ('DimDate', 'DimTime', 'DimStation', 'DimPollutant', 'DimSensor', 'FactAirQuality')


def command(database):
    return ['sqlcmd', '-S', os.environ.get('HANOI_SQL_SERVER', 'localhost'),
            '-E', '-C', '-d', database, '-b', '-f', '65001']


def query(sql, database='hanoi_air_dw'):
    result = subprocess.run(command(database) + ['-y', '0', '-w', '65535',
                            '-Q', 'SET NOCOUNT ON; ' + sql + ' FOR JSON PATH, INCLUDE_NULL_VALUES;'],
                            capture_output=True, encoding='utf-8-sig', errors='replace')
    if result.returncode:
        raise RuntimeError('Truy van SQL khong thanh cong; xem loi trong SSMS/sqlcmd cuc bo.')
    return json.loads(''.join(result.stdout.strip().splitlines()))


def render(columns, links, output):
    from PIL import Image, ImageDraw, ImageFont
    image = Image.new('RGB', (1920, 1400), '#f3f6fa')
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)
    bold = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 24)
    heading = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 32)
    draw.text((60, 32), 'STAR ĐÃ TRIỂN KHAI | hanoi_air_dw | BƯỚC 6', font=heading, fill='#12334a')
    draw.text((60, 82), 'Cột và 5 quan hệ dimension–fact đọc trực tiếp từ sys.columns / sys.foreign_keys.', font=font, fill='#34475a')
    positions = {'DimDate': (60, 140, 420, 370), 'DimTime': (60, 640, 420, 280),
                 'DimStation': (1380, 140, 480, 340), 'DimPollutant': (1380, 580, 480, 250),
                 'DimSensor': (1380, 930, 480, 220), 'FactAirQuality': (650, 260, 520, 550)}
    routes = {'DimDate': [(480, 325), (560, 325), (560, 370), (650, 370)],
              'DimTime': [(480, 780), (590, 780), (590, 470), (650, 470)],
              'DimStation': [(1380, 310), (1270, 310), (1270, 430), (1170, 430)],
              'DimPollutant': [(1380, 705), (1300, 705), (1300, 530), (1170, 530)],
              'DimSensor': [(1380, 1040), (1240, 1040), (1240, 630), (1170, 630)]}
    for link in links:
        if link['ChildTable'] != 'FactAirQuality' or link['ParentTable'] not in routes:
            continue
        pts = routes[link['ParentTable']]
        draw.line(pts, fill='#51758f', width=3)
        x, y = pts[-1]
        direction = 1 if x == 650 else -1
        draw.polygon([(x, y), (x-direction*13, y-7), (x-direction*13, y+7)], fill='#51758f')
        draw.text((pts[0][0]+(12 if direction == 1 else -100), pts[0][1]-30), '1 → nhiều', font=font, fill='#34475a')
    for table in CORE:
        x, y, width, height = positions[table]
        draw.rounded_rectangle((x, y, x+width, y+height), 10, fill='white', outline='#b9c8d4', width=2)
        draw.rectangle((x+1, y+1, x+width-1, y+48), fill='#12334a' if table.startswith('Fact') else '#23657a')
        draw.text((x+16, y+11), 'dbo.'+table, font=bold, fill='white')
        for i, col in enumerate(c for c in columns if c['TableName'] == table):
            label = col['ColumnName'] + ' : ' + col['TypeDisplay']
            assert draw.textbbox((0, 0), label, font=font)[2] < width-28, label
            draw.text((x+14, y+64+i*33), label, font=font, fill='#172f40')
    notes = ['6 bảng Star / 40 cột; 5 FK dimension, thêm FK BatchId → etl.BatchLog để truy vết.',
             'UQ fact: (StationKey, SensorKey, ObservedAtUTC, PollutantKey). Không cascade.',
             'Ngoài hình: stg.AirQuality, etl.BatchLog, etl.RejectRow. Không đưa bảng log vào mô hình Power BI.',
             'DimDate = 366 ngày; DimTime = 24 giờ. Fact và dimension mô tả chưa nạp ETL.',
             'Ảnh kết xuất từ metadata SQL thật bằng Python; không phải ảnh Database Diagram trong SSMS.']
    for i, note in enumerate(notes):
        draw.text((60, 1180+i*37), note, font=font, fill='#172f40')
    image.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--test-constraints', action='store_true')
    args = parser.parse_args()
    columns = query("""SELECT s.name AS SchemaName,t.name AS TableName,c.column_id AS Ordinal,
        c.name AS ColumnName,ty.name AS SqlType,c.max_length AS MaxLength,c.precision AS [Precision],
        c.scale AS Scale,c.is_nullable AS IsNullable,c.is_identity AS IsIdentity
        FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
        JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id
        WHERE s.name=N'dbo' AND t.name IN (N'DimDate',N'DimTime',N'DimStation',N'DimPollutant',N'DimSensor',N'FactAirQuality')
        ORDER BY t.name,c.column_id""")
    with (ROOT/'docs/thiet_ke/tu_dien_du_lieu.csv').open(encoding='utf-8-sig', newline='') as file:
        expected = list(csv.DictReader(file))
    assert len(columns) == len(expected) == 40, 'Sai tong so cot Star'
    by_key = {(c['TableName'], c['ColumnName']): c for c in columns}
    for item in expected:
        actual = by_key[(item['Bang'], item['Cot'])]
        dtype = item['Kieu_SQL_Server'].replace(' IDENTITY(1,1)', '')
        match = re.fullmatch(r'(\w+)(?:\((\d+)(?:,(\d+))?\))?', dtype)
        base, first, second = match.groups()
        assert actual['SqlType'] == base, item
        assert bool(actual['IsNullable']) == (item['Cho_NULL'] == 'Có'), item
        assert bool(actual['IsIdentity']) == ('IDENTITY' in item['Kieu_SQL_Server']), item
        if base == 'nvarchar':
            assert actual['MaxLength'] == int(first)*2, item
        elif base == 'decimal':
            assert (actual['Precision'], actual['Scale']) == (int(first), int(second)), item
        elif base == 'float':
            assert actual['Precision'] == int(first), item
        elif base in ('datetimeoffset', 'datetime2', 'time'):
            assert actual['Scale'] == int(first), item
        actual['TypeDisplay'] = item['Kieu_SQL_Server']
    links = query("""SELECT fk.name AS Name,OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ChildSchema,
        OBJECT_NAME(fk.parent_object_id) AS ChildTable,pc.name AS ChildColumn,
        OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ParentSchema,OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
        rc.name AS ParentColumn,fk.is_disabled AS IsDisabled,fk.is_not_trusted AS IsNotTrusted
        FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=fk.object_id
        JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
        JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id ORDER BY fk.name""")
    assert len(links) == 8 and all(not f['IsDisabled'] and not f['IsNotTrusted'] for f in links)
    core_links = [f for f in links if f['ChildTable']=='FactAirQuality' and f['ParentSchema']=='dbo']
    assert {f['ParentTable'] for f in core_links} == set(CORE)-{'FactAirQuality'}
    counts = query("""SELECT 'DimDate' AS TableName,COUNT_BIG(*) AS RowsInTable FROM dbo.DimDate
        UNION ALL SELECT 'DimTime',COUNT_BIG(*) FROM dbo.DimTime
        UNION ALL SELECT 'DimStation',COUNT_BIG(*) FROM dbo.DimStation
        UNION ALL SELECT 'DimPollutant',COUNT_BIG(*) FROM dbo.DimPollutant
        UNION ALL SELECT 'DimSensor',COUNT_BIG(*) FROM dbo.DimSensor
        UNION ALL SELECT 'FactAirQuality',COUNT_BIG(*) FROM dbo.FactAirQuality
        UNION ALL SELECT 'stg.AirQuality',COUNT_BIG(*) FROM stg.AirQuality
        UNION ALL SELECT 'etl.BatchLog',COUNT_BIG(*) FROM etl.BatchLog
        UNION ALL SELECT 'etl.RejectRow',COUNT_BIG(*) FROM etl.RejectRow""")
    assert {c['TableName']:c['RowsInTable'] for c in counts} == dict(DimDate=366,DimTime=24,DimStation=0,DimPollutant=0,DimSensor=0,FactAirQuality=0,**{'stg.AirQuality':0,'etl.BatchLog':0,'etl.RejectRow':0})
    constraints = query("""SELECT type_desc AS ConstraintType,COUNT(*) AS ConstraintCount FROM sys.key_constraints
        WHERE parent_object_id IN (SELECT object_id FROM sys.tables WHERE is_ms_shipped=0 AND name<>N'sysdiagrams') GROUP BY type_desc
        UNION ALL SELECT 'FOREIGN_KEY_CONSTRAINT',COUNT(*) FROM sys.foreign_keys
        UNION ALL SELECT 'CHECK_CONSTRAINT',COUNT(*) FROM sys.check_constraints""")
    source = query("""SELECT COUNT_BIG(*) AS TotalRows,SUM(CASE WHEN parameter IN (N'pm25',N'pm10') THEN CONVERT(bigint,1) ELSE 0 END) AS PMRows FROM dbo.air_quality_hourly""", 'hanoi_air_vn')[0]
    assert source == {'TotalRows':23036,'PMRows':11500}
    tests = []
    if args.test_constraints:
        result = subprocess.run(command('hanoi_air_dw')+['-i',str(ROOT/'sql/checks/thu_rang_buoc_buoc6.sql'),'-W','-s','|','-w','180'],capture_output=True,encoding='utf-8-sig',errors='replace')
        if result.returncode:
            raise RuntimeError('Kiem thu constraint chua dat; xem SSMS/sqlcmd cuc bo.')
        for line in result.stdout.splitlines():
            parts = line.strip().split('|')
            if len(parts)==4 and parts[1] in ('PASS','FAIL'):
                tests.append(dict(zip(('TestId','Result','ExpectedError','ActualError'), parts)))
        assert len(tests)==30 and all(t['Result']=='PASS' for t in tests)
    report = {'checked_at':datetime.now().astimezone().isoformat(timespec='seconds'),
              'database':'hanoi_air_dw','status':'PASS','core_column_comparison':'40/40 match dictionary: name/type/NULL/identity',
              'row_counts':counts,'source_counts':source,'constraints':constraints,'columns':columns,'foreign_keys':links,
              'behavioral_tests':tests,'measurement_etl_implemented':False}
    if args.write:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT/'buoc6_kiem_tra_cau_truc.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        render(columns,links,OUT/'buoc6_star_thuc_te.png')
        if tests:
            with (OUT/'buoc6_thu_rang_buoc.csv').open('w',encoding='utf-8-sig',newline='') as file:
                writer=csv.DictWriter(file,fieldnames=list(tests[0]));writer.writeheader();writer.writerows(tests)
    print(json.dumps({'status':'PASS','matched_core_columns':len(columns),'foreign_keys':len(links),
                      'behavioral_tests':len(tests),'row_counts':counts,'source_counts':source},ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
