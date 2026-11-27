# Mô tả 3 trang báo cáo và visual Power BI (Bước 13)

Tệp báo cáo: [HanoiAirOLAP.pbip](HanoiAirOLAP.pbip) (và tệp `.pbix` tại [khong_khi_ha_noi.pbix](khong_khi_ha_noi.pbix) sau khi lưu từ Power BI Desktop). Nguồn dữ liệu lấy trực tiếp từ kho `hanoi_air_dw` (chế độ Import).

## Quy ước chung trên cả 3 trang

- **Kích thước trang:** `1920 × 1080` (`FitToPage`), nền nhạt `#F1F5F9`, khung thẻ nền trắng `#FFFFFF`.
- **Màu sắc nhất quán theo trạm:**
  - `Hàng Đậu-2131275`: Xanh dương đậm (`#1D4ED8`).
  - `Khương Trung-2131277`: Cam ấm (`#D97706`).
- **Quy tắc thời gian & dữ liệu thiếu:**
  - Dùng ngày và giờ Việt Nam (`UTC+07:00`).
  - Không tự điền `0` vào giờ thiếu; sử dụng biểu đồ cột để không nối đường liên tục qua các khoảng ngày/tháng trống (như tháng 8/2024).
  - Không gộp chung PM2.5 và PM10; measure `Nồng độ trung bình`, `Cực đại (µg/m³)`, `Cực tiểu (µg/m³)` trả về `BLANK()` khi chưa chọn đúng một chất.
- **Đồng bộ bộ lọc:** Slicer Trạm (`StationSync`) và Khoảng ngày (`DateSync`) đồng bộ giữa cả 3 trang.

---

## Trang 1: `01_Tong_quan`

Trả lời nhóm câu hỏi tổng quan: khoảng thời gian thực có, mức nồng độ trung bình từng chất, số phép đo/giờ và độ phủ dữ liệu theo trạm–chất.

| Visual | Loại | Trường & Measure sử dụng | Mục đích & lưu ý |
| --- | --- | --- | --- |
| Tiêu đề & phạm vi | `textbox` | Văn bản tĩnh | Nêu phạm vi 29/01–11/12/2024, UTC+07:00 và cảnh báo dữ liệu gián đoạn. |
| Bộ lọc Trạm | `slicer` (Dropdown) | `DimStation[StationName]` | Lọc theo trạm, đồng bộ với trang 02 và 03. |
| Bộ lọc Ngày | `slicer` (Between) | `DimDate[FullDate]` | Lọc khoảng ngày theo lịch 366 ngày, đồng bộ cả 3 trang. |
| Hàng thẻ KPI (5 thẻ) | `cardVisual` | `PM2.5 trung bình (µg/m³)`, `PM10 trung bình (µg/m³)`, `Số phép đo hợp lệ`, `Số giờ quan sát`, `Số ngày có dữ liệu` | Tách riêng PM2.5 TB và PM10 TB; ghi rõ nhãn số phép đo khác số giờ quan sát. |
| Độ phủ theo tháng | `clusteredColumnChart` | X: `DimDate[MonthNumber]`, Legend: `DimStation[StationName]`, Y: `Số giờ trạm-chất`, Tooltip: `Số phép đo hợp lệ`, `Số ngày có dữ liệu` | Cho thấy tháng 8/2024 không có phép đo nào để tránh hiểu nhầm đủ 12 tháng liên tục. |
| Bảng độ phủ & thống kê | `tableEx` | `StationName`, `PollutantCode`, `Số phép đo hợp lệ`, `Số giờ trạm-chất`, `Số ngày có dữ liệu`, `Nồng độ trung bình`, `Cực tiểu (µg/m³)`, `Cực đại (µg/m³)` | Đối chiếu chi tiết từng trạm–chất trên nền kỳ vọng 8.784 giờ/năm. |
| So sánh trạm–chất | `clusteredBarChart` | Y: `PollutantCode`, Legend: `StationName`, X: `Nồng độ trung bình`, Tooltip: `Số phép đo hợp lệ`, Min/Max | Hiển thị nồng độ TB (µg/m³) trên tập giờ hiện có của từng trạm. |
| Hộp quy tắc diễn giải | `textbox` | Văn bản tĩnh | Tóm tắt nguyên tắc không trộn chất, không coi giờ thiếu là 0, chưa kết luận AQI. |

---

## Trang 2: `02_Xu_huong`

Trả lời nhóm câu hỏi xu hướng biến thiên theo ngày, giờ trong ngày và tháng theo giờ địa phương.

| Visual | Loại | Trường & Measure sử dụng | Mục đích & lưu ý |
| --- | --- | --- | --- |
| Tiêu đề trang | `textbox` | Văn bản tĩnh | Nêu rõ đơn vị `µg/m³`, múi giờ `UTC+07:00` và quy tắc bỏ chọn chất trả `BLANK()`. |
| Bộ lọc Chất | `slicer` (Dropdown) | `DimPollutant[PollutantCode]` (mặc định `pm25`) | Chọn từng chất (`pm25` hoặc `pm10`); khi bỏ chọn, các biểu đồ dùng `Nồng độ trung bình` sẽ trống (`BLANK()`). |
| Bộ lọc Trạm & Ngày | `slicer` | `DimStation[StationName]`, `DimDate[FullDate]` | Đồng bộ với trang 01 và 03. |
| Chuỗi trung bình ngày | `clusteredColumnChart` | X: `DimDate[FullDate]`, Legend: `StationName`, Y: `Nồng độ trung bình`, Tooltip: `Số phép đo hợp lệ`, Min/Max | Biểu đồ cột theo ngày, nhìn rõ các khoảng ngày và tháng bị gián đoạn. |
| Phân tích theo giờ | `clusteredColumnChart` | X: `DimTime[HourNumber]` (0–23h), Legend: `StationName`, Y: `Nồng độ trung bình`, Tooltip: `Số phép đo hợp lệ`, `Số ngày có dữ liệu` | Quan sát biến thiên nồng độ theo từng giờ trong ngày tại Hà Nội. |
| Phân tích theo tháng | `clusteredColumnChart` | X: `DimDate[MonthNumber]`, Legend: `StationName`, Y: `Nồng độ trung bình`, Tooltip: `Số phép đo hợp lệ`, `Số giờ trạm-chất` | Theo dõi mức trung bình từng tháng và khoảng trống tháng 8. |

---

## Trang 3: `03_So_sanh_tra_cuu`

Trả lời nhóm câu hỏi đối chiếu chi tiết theo trạm–cảm biến–chất, truy vết về nguồn và chuẩn bị khung cho phép so sánh ghép cặp ở Bước 14.

| Visual | Loại | Trường & Measure sử dụng | Mục đích & lưu ý |
| --- | --- | --- | --- |
| Tiêu đề trang | `textbox` | Văn bản tĩnh | Giới thiệu bảng truy vết nguồn và phạm vi so sánh giờ chung (Bước 14). |
| Bộ lọc Chất / Trạm / Cảm biến / Ngày | `slicer` | `PollutantCode`, `StationName`, `SensorId`, `FullDate` | Lọc sâu đến từng cảm biến (`7771996`, `7772005`, `7772039`, `7772073`) và khoảng ngày. |
| Bảng tóm tắt Trạm – Cảm biến | `tableEx` | `StationName`, `SensorId`, `PollutantCode`, `Số phép đo hợp lệ`, `Số giờ trạm-chất`, `Nồng độ trung bình`, Min, Max | Kiểm tra phân tách theo từng cảm biến đúng grain kho dữ liệu. |
| Khung so sánh giờ ghép cặp | `textbox` | Văn bản tĩnh (chờ Bước 14) | Ghi chú quy tắc ghép cặp `vw_StationHourly` và `vw_StationPairHourly` sẽ nối ở Bước 14. |
| Bảng tra cứu phép đo chi tiết | `tableEx` | `ObservedAtLocal`, `StationName`, `PollutantCode`, `SensorId`, `Value`, `IsValid`, `SourceId`, `BatchId` | Tra cứu từng phép đo cụ thể kèm `Value` gốc (µg/m³), `SourceId` nguồn và `BatchId` ETL. |
