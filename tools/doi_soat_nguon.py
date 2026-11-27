"""Kiểm tra manifest, dữ liệu gốc và CSV ghép; tạo hồ sơ bước 3."""
import argparse
import collections
import csv
import gzip
import hashlib
import json
import re
import subprocess
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / 'data/raw'
MANIFEST = ROOT / 'data/source/hanoi_air_quality_vn_source_manifest.txt'
MERGED = ROOT / 'data/source/hanoi_air_quality_vn_monitoring_source.csv'
SQL = ROOT / 'sql/source/hanoi_air_quality_vn_monitoring_real.sql'
BASE = 'https://openaq-data-archive.s3.amazonaws.com/'
FIELDS = ['location_id', 'sensors_id', 'location', 'datetime', 'lat', 'lon', 'parameter', 'units', 'value']
PATTERN = re.compile(r'^records/csv\.gz/locationid=(\d+)/year=2024/month=(\d{2})/(location-\d+-2024\d{4}\.csv\.gz)$')


def digest(path):
    """Tính SHA-256 của byte tệp hiện tại."""
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def normalized(row):
    """So sánh tất cả các trường; số thập phân bằng nhau dù khác cách viết."""
    return tuple(Decimal(row[k]) if k in ('lat', 'lon', 'value') and row[k] != '' else row[k] for k in FIELDS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='Tạo hồ sơ và biên bản bước 3')
    args = parser.parse_args()
    keys = MANIFEST.read_text(encoding='utf-8-sig').splitlines()
    entries = []
    names = []
    issues = []
    for key in keys:
        match = PATTERN.fullmatch(key)
        if not match:
            issues.append(f'Đường dẫn manifest không hợp lệ: {key}')
            continue
        station, month, name = match.groups()
        if not name.startswith(f'location-{station}-2024{month}'):
            issues.append(f'Mã trạm hoặc tháng không khớp tên file: {key}')
        entries.append((key, station, name))
        names.append(name)
    duplicate_names = [name for name, count in collections.Counter(names).items() if count > 1]
    issues.extend(f'Tên trùng trong manifest: {name}' for name in duplicate_names)
    local_names = {p.name for p in RAW.glob('*.csv.gz')}
    missing = sorted(set(names) - local_names)
    extra = sorted(local_names - set(names))
    issues.extend(f'Thiếu file: {name}' for name in missing)
    issues.extend(f'File thừa: {name}' for name in extra)
    raw_counter = collections.Counter()
    raw_keys = collections.Counter()
    metadata = []
    counts = collections.Counter()
    total = 0
    for key, station, name in entries:
        path = RAW / name
        if not path.is_file():
            continue
        try:
            with gzip.open(path, 'rt', encoding='utf-8-sig', newline='') as f:
                reader = csv.DictReader(f)
                if reader.fieldnames != FIELDS:
                    raise ValueError(f'Cột không khớp: {reader.fieldnames}')
                rows = list(reader)
            if not rows:
                raise ValueError('File không có phép đo')
            if any(row['location_id'] != station for row in rows):
                raise ValueError('Mã trạm trong dữ liệu không khớp manifest')
            times = [datetime.fromisoformat(row['datetime']) for row in rows]
            if any(t.utcoffset() is None for t in times):
                raise ValueError('Timestamp thiếu múi giờ')
            for row in rows:
                raw_counter[normalized(row)] += 1
                raw_keys[(row['location_id'], row['sensors_id'], row['datetime'], row['parameter'])] += 1
                counts[(row['location_id'], row['parameter'])] += 1
            total += len(rows)
            sensor_parameters = sorted({f"{row['sensors_id']}:{row['parameter']}" for row in rows})
            metadata.append({
                'file': name, 'url': BASE + key, 'ma_tram': station,
                'ten_tram_nguon': rows[0]['location'], 'cam_bien_chi_tieu': '; '.join(sensor_parameters),
                'ngay_tai_goc': 'chưa xác định', 'thoi_gian_dau': min(times).isoformat(),
                'thoi_gian_cuoi': max(times).isoformat(), 'don_vi': '; '.join(sorted({r['units'] for r in rows})),
                'so_phep_do': len(rows), 'kich_thuoc_byte': path.stat().st_size, 'sha256': digest(path),
                'trang_tram': f'https://explore.openaq.org/locations/{station}',
                'nha_cung_cap_tren_openaq': 'Hanoi Air Quality Monitoring Network',
                'chu_so_huu_tren_openaq': 'Unknown Governmental Organization',
            })
        except (OSError, EOFError, UnicodeError, csv.Error, ValueError, KeyError, InvalidOperation) as error:
            issues.append(f'Không đọc hoặc kiểm chứng được {name}: {error}')
    with MERGED.open(encoding='utf-8-sig', newline='') as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != FIELDS:
            raise ValueError(f'Cột CSV ghép không khớp: {reader.fieldnames}')
        merged_rows = list(reader)
    merged_counter = collections.Counter(normalized(row) for row in merged_rows)
    merged_keys = collections.Counter((r['location_id'], r['sensors_id'], r['datetime'], r['parameter']) for r in merged_rows)
    raw_only = sum((raw_counter - merged_counter).values())
    merged_only = sum((merged_counter - raw_counter).values())
    if raw_only or merged_only:
        issues.append(f'Không khớp nội dung: chỉ nguồn {raw_only}, chỉ CSV {merged_only}')
    raw_dup = sum(count - 1 for count in raw_keys.values() if count > 1)
    merged_dup = sum(count - 1 for count in merged_keys.values() if count > 1)
    baseline = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    result = {
        'baseline_commit': baseline, 'manifest_entries': len(keys), 'manifest_unique_filenames': len(set(names)),
        'raw_files': len(local_names), 'files_read': len(metadata), 'missing': missing, 'extra': extra,
        'duplicate_manifest_names': duplicate_names, 'raw_rows': total, 'merged_rows': len(merged_rows),
        'raw_only_rows': raw_only, 'merged_only_rows': merged_only, 'raw_duplicate_keys': raw_dup,
        'merged_duplicate_keys': merged_dup, 'station_parameter_counts': {f'{a}/{b}': n for (a,b),n in sorted(counts.items())},
        'source_csv_sha256': digest(MERGED), 'sql_sha256': digest(SQL), 'issues': issues,
    }
    print(json.dumps(result, ensure_ascii=True, indent=2))
    if issues:
        raise SystemExit('Đối soát chưa đạt; không tạo hồ sơ chính thức.')
    if args.write:
        destination = ROOT / 'data/source/nguon_du_lieu.csv'
        with destination.open('w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=list(metadata[0]))
            writer.writeheader()
            writer.writerows(metadata)
        paths = sorted(RAW.glob('*.csv.gz')) + [MERGED, SQL]
        (ROOT / 'data/checksums.sha256').write_text(''.join(f"{digest(p)}  {p.relative_to(ROOT).as_posix()}\n" for p in paths), encoding='utf-8')
        (ROOT / 'data/ket_qua_doi_soat.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
