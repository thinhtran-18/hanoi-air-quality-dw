# Từ điển phương án SNOWFLAKE | LƯỢC ĐỒ BÔNG TUYẾT

Phương án thiết kế để so sánh. Chưa tạo bảng SQL; mô hình triển khai chính vẫn là Star Schema.

## DimDate

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| DateKey | int | Không | PK | Khóa ngày YYYYMMDD | Từ ObservedAtLocal |
| FullDate | date | Không | UQ | Ngày địa phương | CAST(ObservedAtLocal AS date) |
| DayOfMonth | tinyint | Không | — | Ngày trong tháng 1–31 | DAY(FullDate) |
| MonthNumber | tinyint | Không | — | Tháng 1–12 | MONTH(FullDate) |
| QuarterNumber | tinyint | Không | — | Quý 1–4 | DATEPART(quarter, FullDate) |
| YearNumber | smallint | Không | — | Năm địa phương | YEAR(FullDate) |
| DayOfWeekISO | tinyint | Không | — | Thứ Hai=1 đến Chủ Nhật=7 | Tính từ lịch, độc lập SET DATEFIRST |
| DayName | nvarchar(12) | Không | — | Tên thứ tiếng Việt | Ánh xạ DayOfWeekISO |

## DimTime

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| TimeKey | int | Không | PK | Khóa giờ HHMMSS dạng số; 00:00:00 = 0 | Từ ObservedAtLocal; Hour*10000+Minute*100+Second |
| FullTime | time(0) | Không | UQ | Giờ địa phương | CAST(ObservedAtLocal AS time(0)) |
| HourNumber | tinyint | Không | — | Giờ 0–23 | DATEPART(hour, ObservedAtLocal) |
| MinuteNumber | tinyint | Không | — | Phút 0–59; hiện tại 0 | DATEPART(minute, ObservedAtLocal) |
| SecondNumber | tinyint | Không | — | Giây 0–59; hiện tại 0 | DATEPART(second, ObservedAtLocal) |

## DimStation

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| StationKey | int IDENTITY(1,1) | Không | PK | Khóa nội bộ, không phải mã OpenAQ | Sinh tại kho |
| StationId | int | Không | UQ / NK | Mã location OpenAQ | SQL: location_id; CSV: location_id |
| StationName | nvarchar(160) | Không | — | Tên đầy đủ như nguồn, giữ hậu tố | SQL: location_name; CSV: location |
| Latitude | decimal(10,6) | Có | — | Vĩ độ | SQL: latitude; CSV: lat |
| Longitude | decimal(10,6) | Có | — | Kinh độ | SQL: longitude; CSV: lon |
| DistrictName | nvarchar(80) | Có | — | Địa bàn quận/huyện khi có metadata xác minh | Nguồn hiện tại không có: NULL; không suy đoán |
| CityKey | int | Không | FK → DimCity | Thành phố của trạm | Tra CityCode cấu hình HAN |

## DimPollutant

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| PollutantKey | int IDENTITY(1,1) | Không | PK | Khóa chất nội bộ | Sinh tại kho |
| PollutantCode | nvarchar(20) | Không | UQ / NK | Mã chất: pm25 hoặc pm10 | SQL/CSV: parameter; chuẩn hóa chữ thường |
| PollutantName | nvarchar(40) | Không | — | Tên hiển thị PM2.5 hoặc PM10 | Ánh xạ cấu hình từ PollutantCode |
| UnitKey | int | Không | FK → DimUnit | Đơn vị chuẩn của chất | Tra UnitCode UG_M3 sau kiểm tra unit/units |

## DimSensor

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| SensorKey | int IDENTITY(1,1) | Không | PK | Khóa cảm biến nội bộ | Sinh tại kho |
| SensorId | int | Không | UQ / NK | Mã cảm biến OpenAQ | SQL: sensor_id; CSV: sensors_id |
| SensorDescription | nvarchar(255) | Có | — | Mô tả phục vụ truy vết, không suy ra model/hiệu chuẩn | Sinh mô tả từ SensorId; metadata thực tế chưa có |

## FactAirQuality

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| AirQualityKey | bigint IDENTITY(1,1) | Không | PK | Khóa kỹ thuật dòng fact; không thay khóa grain | Sinh tại kho |
| DateKey | int | Không | FK → DimDate | Ngày địa phương của phép đo | Tra DimDate từ ObservedAtLocal |
| TimeKey | int | Không | FK → DimTime | Giờ địa phương của phép đo | Tra DimTime từ ObservedAtLocal |
| StationKey | int | Không | FK → DimStation; UQ grain | Trạm của phép đo | Tra StationId bằng location_id |
| PollutantKey | int | Không | FK → DimPollutant; UQ grain | Chất của phép đo | Tra PollutantCode bằng parameter |
| SensorKey | int | Không | FK → DimSensor; UQ grain | Cảm biến của phép đo | Tra SensorId bằng SQL sensor_id / CSV sensors_id |
| ObservedAtSource | datetimeoffset(0) | Không | — | Thời điểm nguồn giữ nguyên offset | SQL: observed_at; CSV: datetime |
| ObservedAtUTC | datetime2(0) | Không | UQ grain | Thời điểm UTC, quy ước mọi giá trị ở UTC | CAST(SWITCHOFFSET(ObservedAtSource, +00:00) AS datetime2(0)) |
| ObservedAtLocal | datetimeoffset(0) | Không | — | Thời điểm phân tích, luôn có offset +07:00 | SWITCHOFFSET(ObservedAtSource, +07:00) |
| Value | float(53) | Có | Measure | Nồng độ theo Unit của chiều chất; không cộng nồng độ | SQL/CSV: value; giữ độ chính xác kiểu nguồn, không làm tròn khi nạp |
| IsValid | bit | Không | — | Đạt quy tắc kỹ thuật đã chốt; không chứng nhận hiệu chuẩn | ETL sinh theo quy tắc tài liệu; không có DEFAULT 1 |
| SourceId | bigint | Không | Lineage | ID bản ghi trong bảng SQL nguồn hiện hành | SQL: dbo.air_quality_hourly.id; CSV không có, không lấy số dòng CSV |
| BatchId | uniqueidentifier | Không | Lineage | Mã lần nạp ETL | ETL sinh một UUID mỗi lần chạy, dùng chung các dòng của lần nạp |

## DimCity

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| CityKey | int IDENTITY(1,1) | Không | PK | Khóa thành phố nội bộ | Sinh tại kho phương án |
| CityCode | nvarchar(20) | Không | UQ / NK | Mã cấu hình nội bộ HAN, không phải mã hành chính | Cấu hình phạm vi Hà Nội |
| CityName | nvarchar(80) | Không | — | Tên thành phố | Hằng cấu hình Hà Nội |

## DimUnit

| Cột | Kiểu SQL Server | Cho NULL | Khóa | Ý nghĩa | Nguồn / quy tắc |
| --- | --- | --- | --- | --- | --- |
| UnitKey | int IDENTITY(1,1) | Không | PK | Khóa đơn vị nội bộ | Sinh tại kho phương án |
| UnitCode | nvarchar(20) | Không | UQ / NK | Mã đơn vị nội bộ UG_M3 | Cấu hình đơn vị chuẩn |
| UnitSymbol | nvarchar(40) | Không | UQ | Ký hiệu µg/m³ | SQL unit / CSV units sau xác minh |
