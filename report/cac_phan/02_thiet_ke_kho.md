# Bước 5 — Báo cáo thiết kế kho dữ liệu

Ngày thực hiện: 27/11/2026. Trạng thái: **đã đạt toàn bộ điều kiện bước 5 ở mức thiết kế**. Chưa triển khai bảng kho và ETL; việc đó thuộc các bước tiếp theo. SSIS không phải điều kiện cần để hoàn thành thiết kế này.

## Bổ sung theo yêu cầu giảng viên: đủ ba loại lược đồ

Đã bổ sung Snowflake và Galaxy dưới dạng **draw.io + PNG**, từ điển riêng và tài liệu so sánh tại `docs/thiet_ke/so_sanh_ba_luoc_do.md`. Star vẫn là mô hình triển khai chính theo lựa chọn người dùng; hai mô hình bổ sung chưa được tạo bảng trong SQL Server.

| Phương án | Sản phẩm / cấu trúc | Kiểm tra |
| --- | --- | --- |
| Star | star_schema.drawio/.png; 1 fact + 5 dimension | Đã kiểm chứng tại bước 5 ban đầu |
| Snowflake | snowflake_schema.drawio/.png; thêm DimCity và DimUnit; 8 bảng / 46 cột / 7 quan hệ | Có FK phù hợp từng quan hệ; từ điển cùng đặc tả; PNG đã kiểm tra trực quan |
| Galaxy | galaxy_schema.drawio/.png; thêm FactCoverageDaily, dùng chung 3 chiều; 7 bảng / 49 cột / 8 quan hệ | Hai grain và unique riêng; không nối hai fact; PNG đã kiểm tra trực quan |

FactCoverageDaily có grain ngày local–trạm–chất. Đã tính thử đủ **1.464 tổ hợp** từ lịch và CSV nguồn, tổng số giờ có dữ liệu của từng trạm/chất khớp bước 4. Giờ có dữ liệu đếm giờ phân biệt; giờ thiếu không phải nồng độ 0. Tệp tính thử dùng natural key để đối soát, chưa phải fact đã nạp.

Minh chứng bổ sung: `report/minh_chung/buoc5_kiem_tra_ba_luoc_do.json`, `buoc5_galaxy_do_phu_ngay.csv`; tái lập bằng `python tools/tao_luoc_do_bo_sung.py`. **Yêu cầu mở rộng bước 5 đã hoàn thành:** đủ ba sơ đồ, grain/khóa/quan hệ, từ điển, bảng so sánh và quyết định chọn Star. Phần dưới ghi nhận kiểm chứng mô hình Star ban đầu.

## Sản phẩm đã thực hiện

1. Chốt grain: một phép đo của một chất, tại một trạm, một cảm biến, một thời điểm; giữ đầy đủ sensor và thời điểm UTC chính xác.
2. Thiết kế `dbo.FactAirQuality` và 5 dimension: DimDate, DimTime, DimStation, DimPollutant, DimSensor. Tất cả dimension nối trực tiếp 1–n vào fact, lọc một chiều; không nối thêm Station–Sensor.
3. Tạo `docs/thiet_ke/star_schema.drawio` và `star_schema.png`. PNG được kết xuất từ cùng cột/bố cục bằng Pillow, đã mở kiểm tra trực quan; bản draw.io được kiểm tra XML và số cạnh/cột, chưa kiểm tra tương tác bằng ứng dụng diagrams.net.
4. Lập từ điển Markdown và CSV cho **6 bảng, 40 cột**, có kiểu SQL Server, NULL, khóa, ý nghĩa và cột nguồn/quy tắc sinh.
5. Đặc tả unique fact `(StationKey, SensorKey, ObservedAtUTC, PollutantKey)`; phân biệt với PK kỹ thuật AirQualityKey, ID nguồn SourceId và mã lô BatchId.
6. Chốt timestamp nguồn có offset, UTC dùng nhận diện thời điểm, local UTC+07 dùng lấy DateKey/TimeKey. Quy định SCD Type 1, chất lượng IsValid, xử lý trùng/xung đột, NULL và truy vết nguồn.
7. Tạo script tái lập sản phẩm và truy vấn SQL chỉ đọc, lưu minh chứng kiểm tra. Cập nhật README để truy cập sản phẩm.

## Kiểm chứng

| Kiểm tra | Kết quả |
| --- | --- |
| CSV nguồn | 23.036 dòng |
| Phạm vi PM2.5/PM10 năm địa phương 2024 | 11.500 dòng; khớp SQL Server |
| Số trạm / chất / cảm biến trong phạm vi | 2 / 2 / 4; khớp SQL Server |
| Dòng dư do trùng khóa trạm–cảm biến–UTC–chất | 0 trên CSV và SQL Server |
| Số dòng tối đa cùng mốc giờ ở cả hai trạm, chỉ tính hai chất bụi | 4 |
| Ca nửa đêm thực tế | 24/02/2024 00:00+07 = 23/02/2024 17:00Z; DateKey=20240224, TimeKey=0 |
| Sơ đồ và từ điển | Cùng đặc tả; đủ 40 cột và 5 quan hệ vào fact |

Minh chứng: `report/minh_chung/buoc5_kiem_tra_grain.json` và `buoc5_sql_grain.txt`. Nguồn không bị sửa. Các giá trị float trong kết quả sqlcmd có thể hiển thị phần lẻ nhị phân; bảng ví dụ dưới đây dùng cách hiển thị thập phân của CSV, không làm tròn dữ liệu khi nạp.

## Điều kiện hoàn thành

| Yêu cầu | Đã xong? |
| --- | --- |
| Grain chốt, giữ cảm biến | Có |
| File draw.io và PNG; dimension nối 1–n trực tiếp | Có |
| Từ điển đầy đủ, thống nhất sơ đồ | Có |
| Quy tắc timestamp nguồn/UTC/local, khóa ngày giờ theo local | Có |
| Unique gồm StationKey, SensorKey, ObservedAtUTC, PollutantKey | Có, đã đặc tả; tạo constraint ở bước triển khai |
| Giải thích một giờ nhiều dòng không phải trùng | Có, kèm ví dụ thực tế và kiểm tra khóa |

## Giải thích grain bằng dữ liệu thật

Lúc **29/01/2024 14:00+07:00**, Hàng Đậu có PM2.5 (sensor 7771996, 57,8 µg/m³) và PM10 (sensor 7772005, 145,7 µg/m³); Khương Trung có PM2.5 (sensor 7772073, 40,6 µg/m³) và PM10 (sensor 7772039, 53,0 µg/m³). Bốn dòng cùng giờ nhưng khác trạm/cảm biến/chất, nên có bốn khóa grain khác nhau.

Chỉ khi cả trạm, cảm biến, thời điểm UTC và chất đều giống nhau mới trùng khóa phép đo. Nếu cùng khóa nhưng Value khác, phải đối soát xung đột, không xem là hai phép đo độc lập. Không dùng riêng cột giờ để xóa trùng.

## Giới hạn và việc tiếp theo

Không coi giờ thiếu là 0 hoặc suy các trung bình trên mẫu thành đại diện cả năm. Không cộng PM2.5 với PM10. DistrictName chưa có nguồn xác minh nên để NULL. Chưa xác nhận metadata hiệu chuẩn cảm biến.

Bước tiếp theo: chuyển đặc tả thành DDL tạo kho và staging, các PK/FK/UQ/CHECK, nạp lịch đủ 366 ngày/24 giờ và kiểm tra cấu trúc. Sau đó triển khai ETL và xử lý SSIS khi cần. Xem toàn bộ quyết định tại `docs/thiet_ke/thiet_ke_star_schema.md`.
