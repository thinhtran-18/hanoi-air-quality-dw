# Biên bản đối soát dữ liệu nguồn

- Ngày kiểm tra: 27/11/2026, theo múi giờ Asia/Saigon.
- Phiên bản dữ liệu đầu vào: commit `6540e47bccd8025a1117b348ae6f91d574084042` trong repo `hanoi-air-quality-dw`. Đây là commit chứa dữ liệu được kiểm tra, không phải commit sẽ chứa biên bản này.
- Tài liệu nguồn: [OpenAQ - Open Data on AWS](https://docs.openaq.org/aws/about); [Hàng Đậu 2161299](https://explore.openaq.org/locations/2161299); [Khương Trung 2161301](https://explore.openaq.org/locations/2161301).
- Provider được OpenAQ ghi nhận: Hanoi Air Quality Monitoring Network. Owner trong OpenAQ: Unknown Governmental Organization. Ngày tải ban đầu: chưa xác định.

## Kết quả

| Hạng mục | Kết quả |
| --- | ---: |
| Dòng manifest / tên file duy nhất | 325 / 325 |
| File nén trong `data/raw/` | 325 |
| File thiếu / file thừa so với manifest | 0 / 0 |
| File giải nén và đọc CSV thành công | 325 |
| Tổng phép đo trong file gốc / CSV ghép | 23.036 / 23.036 |
| Dòng chỉ có ở file gốc / chỉ có ở CSV ghép | 0 / 0 |
| Bản ghi trùng khóa thừa trong file gốc / CSV ghép | 0 / 0 |
| Dòng checksum đã kiểm tra | 327: 325 file gốc + CSV ghép + SQL nguồn |

| Trạm | File gốc | CO | NO2 | PM10 | PM2.5 | Tổng |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hàng Đậu `2161299` | 188 | 3.252 | 3.259 | 3.253 | 3.251 | 13.015 |
| Khương Trung `2161301` | 137 | 2.528 | 2.497 | 2.498 | 2.498 | 10.021 |

Thời điểm thực có ở Hàng Đậu: 29/01/2024 14:00 đến 27/11/2024 00:00; Khương Trung: 29/01/2024 13:00 đến 11/12/2024 22:00, đều theo offset +07:00. Tên file ngày lưu trữ có thể chứa một phép đo ở ngày địa phương kế tiếp; thống kê khoảng thời gian dùng timestamp thực trong file, không suy ra từ tên file.

## Phương pháp và bằng chứng

1. Đối chiếu từng tên file trong manifest với thư mục `data/raw/`; kiểm tra tên trùng, mã trạm và tháng trong đường dẫn.
2. Giải nén và đọc từng file qua `gzip` và `csv`; kiểm tra cấu trúc 9 cột, mã trạm, timestamp có offset. Tổng hợp metadata từng file vào `data/source/nguon_du_lieu.csv`.
3. So từng phép đo bằng khóa `location_id`, `sensors_id`, `datetime`, `parameter` và đối chiếu **toàn bộ 9 trường**, có xét số lần lặp. Các trường `lat`, `lon`, `value` so bằng `Decimal`; `107` bằng `107.0`. Thứ tự dòng không ảnh hưởng so sánh.
4. Tính SHA-256 cho 325 file gốc, CSV ghép và SQL nguồn vào `data/checksums.sha256`; đọc lại và tính lại cả 327 hash, tất cả khớp tại thời điểm kiểm tra.
5. Tải lại một file ngày 29/01/2024 của mỗi trạm từ URL trong manifest và so byte bằng SHA-256 với file trong repo: **cả hai khớp**. Đây là đối chiếu mẫu 2/325, không phải xác nhận trực tuyến toàn bộ 325 file.

Kết quả máy đọc được nằm trong `data/ket_qua_doi_soat.json`; mã lệnh là `tools/doi_soat_nguon.py`. Biên bản này chứng minh sự khớp giữa các bản sao và nguồn mẫu; không xác minh độc lập độ chính xác cảm biến, nguồn phát sinh ban đầu hay sự đầy đủ theo giờ. SQL được tính hash, nhưng bước này không so từng bản ghi SQL với CSV; việc kiểm tra SQL Server và chất lượng dữ liệu nằm ở các bước tiếp theo.
