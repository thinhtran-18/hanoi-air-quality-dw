# Bước 6 — Triển khai kho hình sao

Đích: `hanoi_air_dw`. Nguồn `hanoi_air_vn` giữ nguyên. Thực thi lần lượt bằng SSMS (Execute từng file) hoặc `sqlcmd`; kết nối lấy từ cấu hình máy, dùng Windows Authentication khi phù hợp.

Có thể mở **`00_chay_buoc6_ssms.sql`** và Execute toàn bộ trong SSMS để chạy DDL 01–05 cùng kiểm tra chỉ đọc. File tổng hợp nằm trong project, không cần SQLCMD mode; sinh lại bằng `python tools/tao_script_buoc6_ssms.py` sau khi chỉnh file gốc. Không chạy đồng thời file tổng hợp với vòng lặp 01–05.

1. `01_tao_kho.sql`: database và schema `stg`, `etl`.
2. `02_tao_staging.sql`: `stg.AirQuality`, `etl.BatchLog`, `etl.RejectRow`.
3. `03_tao_dimensions.sql`: 5 dimension, chưa nạp metadata trạm/chất/cảm biến.
4. `04_tao_fact.sql`: fact, unique grain, 5 FK chiều và FK lô, CHECK và chỉ mục.
5. `05_nap_lich.sql`: 366 ngày năm 2024 và 24 mốc đầu giờ. Không tạo phép đo cho giờ thiếu.
6. `06_tao_views_buoc14.sql`: tạo `dbo.vw_StationHourly` và `dbo.vw_StationPairHourly` phục vụ so sánh ghép cặp công bằng ở Bước 14.

Ví dụ PowerShell tại gốc repo:

```powershell
$dwServer = 'localhost' # Thay bằng cấu hình cục bộ.
Get-ChildItem sql/schema/0[1-5]_*.sql | Sort-Object Name | ForEach-Object {
    sqlcmd -S $dwServer -E -C -b -f 65001 -i $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "DDL thất bại: $($_.Name)" }
}
sqlcmd -S $dwServer -E -C -b -f 65001 -i sql/checks/kiem_tra_cau_truc_buoc6.sql
```

Các script bỏ qua bảng đã tồn tại, không DROP/TRUNCATE hoặc tự sửa bảng cũ. Đây không phải công cụ migration: luôn chạy kiểm tra sau DDL để phát hiện cấu trúc không khớp. Mỗi file DDL bảng có transaction; database tạo riêng trước transaction.

Kiểm tra đầy đủ tên/kiểu/NULL/IDENTITY của 40 cột với từ điển:

```powershell
$env:HANOI_SQL_SERVER = $dwServer
python tools/kiem_tra_buoc6.py
```

`--write` ghi JSON và PNG metadata vào `report/minh_chung/`. `--test-constraints` chạy 30 ca thử có transaction/ROLLBACK; chỉ dùng trên kho chưa nạp ETL. Dữ liệu thử không được lưu lại, nhưng IDENTITY có thể có khoảng trống sau rollback; không reseed để che điều này. Sau khi kho có dữ liệu, kiểm tra metadata/số dòng bằng SQL; bộ kiểm tra mốc bước 6 hiện kỳ vọng fact/metadata mô tả còn trống.

## Quyết định triển khai hỗ trợ ETL

- Star giữ đúng 6 bảng/40 cột ở bước 5. Ba bảng hỗ trợ không phải dimension và không thêm vào mô hình phân tích chính.
- `BatchId` dùng `uniqueidentifier` thống nhất ở staging/log/reject/fact. FK từ fact tới BatchLog chỉ bảo vệ truy vết lô, không tạo chiều phân tích thứ sáu. Không có FK liên database tới bảng nguồn.
- Staging dùng `datetimeoffset(7)` để giữ phần giây nếu đầu vào thay đổi; ETL phải phát hiện nguồn không phù hợp fact `(0)`/lịch đầu giờ trước chuyển kiểu. Staging cho phép mã/thời gian/giá trị NULL và lặp SourceId, để bước 7 ghi rõ lỗi và trùng; không ép CHECK chất lượng của fact vào staging.
- BatchLog lưu trạng thái, các nhóm đếm, hash nguồn và JSON thay đổi metadata Type 1. `Success` phải cân đối: trích xuất = mới + đã có + từ chối + trùng + ngoài phạm vi; xung đột bằng 0. Đây mới là cấu trúc, chưa có procedure ghi log.
- RejectRow lưu SourceId, StageRowId, lý do và bản chụp JSON. Không FK tới staging để giữ minh chứng khi dọn vùng đệm. SourceId có thể NULL nếu chưa xác định được nguồn, nhưng luồng SQL chính phải cung cấp được ID.
- CHECK fact bảo vệ UTC/local cùng thời điểm, offset +07, DateKey/TimeKey theo local, cờ hợp lệ và ID nguồn. NULL/âm giữ với `IsValid=0`; giá trị dương cao không tự bị loại. Đơn vị và phạm vi do dimension bảo vệ; tổ hợp trạm–cảm biến–chất kiểm tra ở ETL.

Chưa có ETL, nạp fact, OLAP hoặc Power BI trong bước 6. Dữ liệu nguồn lịch sử vẫn gián đoạn; lịch đủ không đồng nghĩa đủ quan sát.
