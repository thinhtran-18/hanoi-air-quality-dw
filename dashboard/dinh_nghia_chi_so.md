# Định nghĩa chỉ số và mô hình Power BI (Bước 12)

Tài liệu mô tả cấu trúc mô hình phân tích Power BI lấy trực tiếp từ kho `hanoi_air_dw` (chế độ Import) và định nghĩa các DAX measures trong [measures.dax](measures.dax).

## 1. Cấu trúc mô hình dữ liệu

- **Nguồn dữ liệu:** `Sql.Database("localhost", "hanoi_air_dw")` — chỉ nạp 6 bảng Star Schema (`FactAirQuality`, `DimDate`, `DimTime`, `DimStation`, `DimPollutant`, `DimSensor`); không nạp `stg.AirQuality`, `etl.BatchLog`, `etl.RejectRow`.
- **Quan hệ:** 5 quan hệ `1 → nhiều`, hướng lọc đơn (`Single`) từ 5 bảng chiều vào `FactAirQuality`. Không tạo quan hệ trực tiếp giữa `DimStation` và `DimSensor`.
- **Thời gian:**
  - Tắt Auto Date/Time (`__PBI_TimeIntelligenceEnabled = 0`) để không sinh các bảng `LocalDateTable_*`.
  - `DimDate` được đánh dấu là Date Table (`dataCategory: Time`, khóa ngày `FullDate`).
  - `DimDate[DayName]` sắp xếp theo `DimDate[DayOfWeekISO]`.
  - Dùng `DateKey`/`TimeKey` theo giờ Việt Nam (`UTC+07:00`) để nhóm ngày/giờ; giữ `ObservedAtUTC` và `ObservedAtLocal` phục vụ truy vết.
- **Ẩn khóa kỹ thuật:** Ẩn toàn bộ khóa thay thế và khóa ngoại (`AirQualityKey`, `DateKey`, `TimeKey`, `StationKey`, `PollutantKey`, `SensorKey`) khỏi giao diện báo cáo; đặt `SummarizeBy = None` cho `Value` và `SourceId` để tránh tổng hợp nhầm bằng `SUM`.

## 2. Định nghĩa các DAX measures

| Tên measure | Công thức tóm tắt | Đơn vị | Quy tắc & lưu ý diễn giải |
| --- | --- | --- | --- |
| `Số phép đo hợp lệ` | `COUNTROWS(FactAirQuality)` với `IsValid = TRUE()` | phép đo | Đếm số dòng phép đo hợp lệ trong ngữ cảnh lọc; **không mặc định là số giờ** khi chọn nhiều trạm, nhiều chất hoặc nhiều cảm biến. |
| `Nồng độ trung bình` | `AVERAGE(FactAirQuality[Value])` khi `HASONEVALUE(DimPollutant[PollutantCode])` | µg/m³ | Chỉ tính khi ngữ cảnh lọc xác định đúng **một** chất (`pm25` hoặc `pm10`); nếu bỏ chọn chất hoặc chọn cả hai, trả về `BLANK()` để không trộn hai chất. |
| `PM2.5 trung bình (µg/m³)` | `CALCULATE([Nồng độ trung bình], DimPollutant[PollutantCode] = "pm25")` | µg/m³ | Luôn cố định chất `pm25`; tính trên các phép đo hiện có, không tự điền `0` cho giờ thiếu. |
| `PM10 trung bình (µg/m³)` | `CALCULATE([Nồng độ trung bình], DimPollutant[PollutantCode] = "pm10")` | µg/m³ | Luôn cố định chất `pm10`; tính trên các phép đo hiện có, không tự điền `0` cho giờ thiếu. |
| `Cực đại (µg/m³)` | `MAX(FactAirQuality[Value])` khi `HASONEVALUE(DimPollutant[PollutantCode])` | µg/m³ | Trả về `BLANK()` nếu không chọn đúng một chất. |
| `Cực tiểu (µg/m³)` | `MIN(FactAirQuality[Value])` khi `HASONEVALUE(DimPollutant[PollutantCode])` | µg/m³ | Trả về `BLANK()` nếu không chọn đúng một chất. |
| `PM2.5 cực đại (µg/m³)` | `CALCULATE([Cực đại (µg/m³)], DimPollutant[PollutantCode] = "pm25")` | µg/m³ | Cực đại riêng của PM2.5 trong ngữ cảnh lọc. |
| `PM10 cực đại (µg/m³)` | `CALCULATE([Cực đại (µg/m³)], DimPollutant[PollutantCode] = "pm10")` | µg/m³ | Cực đại riêng của PM10 trong ngữ cảnh lọc. |
| `Số ngày có dữ liệu` | `DISTINCTCOUNT(FactAirQuality[DateKey])` với `IsValid = TRUE()` | ngày | Số ngày địa phương phân biệt có ít nhất 1 phép đo hợp lệ. |
| `Số giờ quan sát` | Đếm tổ hợp `(DateKey, TimeKey)` phân biệt với `IsValid = TRUE()` | giờ | Số mốc giờ địa phương phân biệt có ít nhất 1 phép đo hợp lệ. |
| `Số giờ trạm-chất` | Đếm tổ hợp `(DateKey, TimeKey, StationKey, PollutantKey)` phân biệt | giờ·trạm·chất | Dùng để đánh giá độ phủ theo từng trạm và từng chất (khác với `Số phép đo hợp lệ` nếu sau này một trạm có nhiều cảm biến cùng đo một chất). |

## 3. Lưu ý sử dụng trên báo cáo

- Giờ thiếu không phải nồng độ `0`; không dùng `COALESCE(..., 0)` cho nồng độ trung bình.
- Không gọi nồng độ trung bình là AQI và không kết luận tuân thủ quy chuẩn khi chưa có ngưỡng và chu kỳ trung bình phù hợp.
- So sánh hai trạm phải thực hiện trên cùng chất và tập giờ ghép cặp ở Bước 14 (`vw_StationPairHourly`).
