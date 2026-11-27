# Dữ liệu nguồn OpenAQ

Bộ dữ liệu lịch sử từ hai mã địa điểm OpenAQ tại Hà Nội trong năm 2024. Phạm vi phân tích chính là PM2.5 và PM10; bộ nguồn còn có CO và NO2. Hai địa điểm không có cập nhật gần đây trên OpenAQ; không suy luận từ đó rằng trạm thực tế đã ngừng hoạt động.

## Các file

- `raw/`: 325 file CSV nén `.csv.gz` tải từ kho OpenAQ, giữ nguyên tên.
- `source/hanoi_air_quality_vn_source_manifest.txt`: 325 đường dẫn tương đối trong kho OpenAQ. URL đầy đủ là `https://openaq-data-archive.s3.amazonaws.com/` + từng dòng.
- `source/nguon_du_lieu.csv`: danh mục 325 file: URL, trạm, cảm biến:chất, khoảng timestamp thực có, đơn vị, số dòng, dung lượng và SHA-256. Cột `ngay_tai_goc` ghi `chưa xác định` vì chưa có bằng chứng thời điểm tải ban đầu; không suy đoán từ thời gian file.
- `source/hanoi_air_quality_vn_monitoring_source.csv`: CSV đã ghép, gồm 23.036 phép đo của bốn chất; không chỉ gồm hai chất bụi.
- `../sql/source/hanoi_air_quality_vn_monitoring_real.sql`: file T-SQL nạp dữ liệu nguồn vào SQL Server. Đây là bảng nguồn, chưa phải kho Star Schema.
- `checksums.sha256`: SHA-256 của 325 file gốc, CSV ghép và SQL nguồn; đường dẫn tương đối từ gốc repo. Không chứa hash của chính nó.
- `ket_qua_doi_soat.json`: số liệu kiểm tra và mã commit dữ liệu đầu vào.
- `../report/minh_chung/bien_ban_doi_soat_nguon.md`: cách kiểm tra, kết quả, giới hạn và nguồn.

Trang OpenAQ xác định provider là **Hanoi Air Quality Monitoring Network**, owner được ghi là **Unknown Governmental Organization**. OpenAQ là nền tảng phân phối; không tự khẳng định đơn vị vận hành thực tế khi chưa có bằng chứng khác.

## Tạo CSV ghép mới

Chạy trong PowerShell ở thư mục gốc repo:

```powershell
python tools/kiem_tra_csv.py --output "$env:TEMP/hanoi_air_ghep_kiem_tra.csv"
```

Lệnh đọc từng `.gz` trực tiếp qua Python `gzip`, ghi tiêu đề một lần và nối từng dòng bằng thư viện `csv`. Chương trình từ chối ghi đè tệp đích đã tồn tại. CSV mới có thể khác thứ tự dòng hoặc cách biểu diễn số như `107.0`/`107`, nên không dùng hash để khẳng định hai CSV có cùng các phép đo; cần so nội dung từng dòng như biên bản. Các file `.gz` không bị thay đổi.

## Kiểm tra lại nguồn và checksum

```powershell
python tools/doi_soat_nguon.py
```

Lệnh đọc toàn bộ 325 file nén, so manifest, cấu trúc cột, khóa đo và toàn bộ giá trị với CSV ghép. Không dùng `--write` khi chỉ muốn kiểm tra; `--write` tạo lại danh mục, checksum và JSON, nên chỉ dùng sau khi có thay đổi dữ liệu chủ đích và ghi lý do. Kiểm tra SHA-256 riêng bằng PowerShell từ gốc repo:

```powershell
$bad = @()
foreach ($line in Get-Content 'data/checksums.sha256') {
    $parts = $line -split '  ', 2
    $actual = (Get-FileHash -LiteralPath $parts[1] -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $parts[0]) { $bad += $parts[1] }
}
if ($bad.Count -eq 0) { 'Tất cả checksum khớp' } else { $bad }
```

SHA-256 chỉ xác nhận byte không thay đổi so với danh sách đã lập; không tự chứng minh phép đo chính xác hoặc chất lượng dữ liệu. CSV hoặc SQL thay đổi có chủ đích phải được xem lại, đối soát và ghi rõ lý do trong commit trước khi tạo checksum mới.
