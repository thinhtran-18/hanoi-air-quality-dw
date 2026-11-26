"""Tạo script T-SQL từ CSV; không kết nối hoặc sửa SQL Server."""
import sys  # Cấu hình đầu ra hỗ trợ tiếng Việt.
import argparse  # Đọc tham số dòng lệnh.
import csv  # Đọc CSV theo tên cột.
from datetime import datetime  # Kiểm tra timestamp và múi giờ.
from decimal import Decimal  # Kiểm tra và giữ cách biểu diễn số thập phân.
from pathlib import Path  # Làm việc với đường dẫn.

if hasattr(sys.stdout, 'reconfigure'):  # Một số môi trường chuyển hướng không hỗ trợ cấu hình.
    sys.stdout.reconfigure(encoding='utf-8')  # Xuất thông báo tiếng Việt dưới dạng UTF-8.

ROOT = Path(__file__).resolve().parent.parent  # Tìm thư mục gốc repo.


def text(value):
    """Tạo hằng chuỗi Unicode T-SQL, nhân đôi dấu nháy đơn."""
    return 'NULL' if value == '' else "N'" + value.replace("'", "''") + "'"  # Bảo toàn tiếng Việt và NULL.


def number(value):
    """Xác nhận giá trị là số hữu hạn trước khi đưa vào script."""
    if value == '':  # Trường số rỗng được biểu diễn bằng SQL NULL.
        return 'NULL'  # Trả về giá trị NULL.
    parsed = Decimal(value)  # Phân tích số chính xác dạng thập phân.
    if not parsed.is_finite():  # Từ chối NaN và vô cực.
        raise ValueError(f'Số không hợp lệ: {value}')  # Dừng khi dữ liệu sai.
    return format(parsed, 'f')  # Chuyển lại thành chuỗi số SQL.


def main():
    """Đọc CSV và sinh script tạo bảng cùng các lệnh INSERT theo lô."""
    parser = argparse.ArgumentParser(description=__doc__)  # Tạo bộ đọc tham số.
    parser.add_argument('--csv', type=Path, default=ROOT / 'data/source/hanoi_air_quality_vn_monitoring_source.csv')  # CSV ghép.
    parser.add_argument('--output', type=Path, required=True)  # Tệp SQL mới.
    args = parser.parse_args()  # Phân tích tham số.
    if args.output.exists():  # Không ghi đè file hiện có.
        raise FileExistsError(f'Tệp đã tồn tại: {args.output}')  # Yêu cầu tên khác.
    with args.csv.open(encoding='utf-8-sig', newline='') as source:  # Đọc CSV UTF-8.
        rows = list(csv.DictReader(source))  # Mỗi dòng trở thành một từ điển.
    values = []  # Danh sách các dòng VALUES sẽ ghi ra SQL.
    keys = set()  # Tập khóa dùng kiểm tra trùng.
    for row in rows:  # Xử lý từng phép đo.
        observed = datetime.fromisoformat(row['datetime'])  # Phân tích thời gian ISO 8601.
        if observed.utcoffset() is None:  # Kiểm tra offset múi giờ.
            raise ValueError('Thời gian thiếu múi giờ')  # Không âm thầm làm mất múi giờ.
        key = (int(row['location_id']), int(row['sensors_id']), observed, row['parameter'])  # Xác định khóa phép đo.
        if key in keys:  # Trùng khóa có thể gây lỗi khi nạp.
            raise ValueError(f'Trùng phép đo: {key}')  # Dừng để điều tra.
        keys.add(key)  # Ghi nhận khóa đã gặp.
        fields = [str(key[0]), str(key[1]), text(row['location']), text(row['datetime']), number(row['lat']), number(row['lon']), text(row['parameter']), text(row['units']), number(row['value'])]  # Ánh xạ và chuyển từng cột.
        values.append('(' + ','.join(fields) + ')')  # Tạo một bộ giá trị SQL.
    header = """-- T-SQL: nap du lieu nguon OpenAQ, chay bang SSMS hoac sqlcmd.
-- Chi chay tren database dich moi; khong xoa bang da ton tai.
USE [master];
GO
IF DB_ID(N'hanoi_air_vn') IS NULL EXEC(N'CREATE DATABASE [hanoi_air_vn]');
GO
USE [hanoi_air_vn];
GO
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.air_quality_hourly', N'U') IS NOT NULL
    THROW 50001, 'Bang da ton tai; dung de tranh ghi de.', 1;
CREATE TABLE dbo.air_quality_hourly (
 id BIGINT IDENTITY(1,1) PRIMARY KEY,
 location_id INT NOT NULL, sensor_id INT NOT NULL,
 location_name NVARCHAR(160) NOT NULL, observed_at DATETIMEOFFSET(7) NOT NULL,
 latitude DECIMAL(10,6), longitude DECIMAL(10,6),
 parameter NVARCHAR(20) NOT NULL, unit NVARCHAR(40) NOT NULL, value FLOAT(53),
 CONSTRAINT UQ_air_measurement UNIQUE(location_id,sensor_id,observed_at,parameter)
);
"""  # Phần đầu tạo database và bảng trong transaction.
    columns = 'location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value'  # Cột theo thứ tự VALUES.
    args.output.parent.mkdir(parents=True, exist_ok=True)  # Tạo thư mục đích nếu cần.
    with args.output.open('x', encoding='utf-8-sig', newline='\n') as output:  # Tạo file T-SQL mới.
        output.write(header)  # Ghi lệnh tạo bảng.
        for start in range(0, len(values), 500):  # Mỗi INSERT chứa tối đa 500 dòng.
            output.write(f'INSERT INTO dbo.air_quality_hourly ({columns}) VALUES\n')  # Ghi lệnh INSERT.
            output.write(',\n'.join(values[start:start + 500]) + ';\n')  # Ghi các giá trị của lô.
        output.write('COMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\nIF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;\nTHROW;\nEND CATCH;\nGO\n')  # Commit hoặc hoàn tác nếu lỗi.
        output.write('SELECT COUNT_BIG(*) AS total_measurements FROM dbo.air_quality_hourly;\n')  # Đếm kết quả khi import xong.
    print(f'Đã tạo {args.output} từ {len(rows)} phép đo.')  # Thông báo số phép đo.


if __name__ == '__main__':  # Tránh chạy khi import module.
    main()  # Bắt đầu tạo script SQL.
