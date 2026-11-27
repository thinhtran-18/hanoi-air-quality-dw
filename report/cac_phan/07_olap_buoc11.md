# Bước 11 — OLAP và nhận xét

Cập nhật ngày 27/11/2026. Phạm vi: SQL, SSAS Multidimensional/MDX và Power BI.

## SQL

Tám truy vấn `sql/olap/01`–`08` đã chạy độc lập thành công trên `hanoi_air_dw`. Kết quả mẫu lưu tại `report/minh_chung/buoc11_01.csv` đến `buoc11_08.csv`; `buoc11_ket_qua_sql.rpt` là kết quả tổng hợp xuất từ SSMS. Truy vấn top ngày dùng ngưỡng minh họa tối thiểu 18 giờ, không phải quy chuẩn. Trung bình tháng/quý tính trên mọi quan sát, không lấy trung bình đơn giản của các trung bình ngày.

## SSAS và MDX

Đã tạo và xử lý thành công database SSAS Multidimensional `HanoiAirOLAP`, cube `Air Quality`, bốn chiều Date, Time, Station, Pollutant, một nhóm phép đo cho các dòng `IsValid=1`. Cube được tạo trực tiếp bằng AMO qua `olap/tao_cube.ps1`; project Visual Studio có sẵn vẫn chỉ là khung, không phải nguồn triển khai cube này. Script từ chối ghi đè database đã có cube/dimension. Tài khoản dịch vụ SSAS được cấp SELECT trên năm bảng cần thiết theo `olap/cap_quyen_doc_ssas.sql`.

Ba truy vấn `olap/01_chat.mdx`, `02_tram_chat.mdx`, `03_thang_chat.mdx` đã chạy qua ADOMD, với kết quả CSV tương ứng trong `report/minh_chung/`. Tổng 11.500 quan sát; PM10 có 5.751 phép đo, trung bình 63,824; PM2.5 có 5.749 phép đo, trung bình 38,749. Bốn nhóm trạm/chất có số mẫu và trung bình khớp truy vấn SQL; tổng hợp tháng chia theo năm để không gộp nhầm các năm. Nồng độ trung bình trả về rỗng tại tổng nhiều chất; giá trị tổng nội bộ được ẩn, không dùng làm chỉ số tổng ô nhiễm.

## Power BI

PBIP `dashboard/HanoiAirOLAP.pbip` có sáu bảng, năm quan hệ fact–dimension. Measure đếm phép đo hợp lệ và trung bình theo từng chất đã được chạy DAX và đối chiếu SQL. Bản nháp có bộ lọc, biểu đồ và bảng; đã thay biểu đồ đường bằng cột để không nối qua khoảng thời gian thiếu. Đã tải lại và kiểm tra trực quan: biểu đồ cột không nối qua các khoảng ngày thiếu; bộ lọc và bảng hiển thị kết quả. Lần validate PBIR không có lỗi nhưng không tải được schema report 3.4.0 và visualContainer 2.15.0; chưa xác nhận đầy đủ các schema đó.

## Giới hạn và nhận xét

Nguồn không liên tục, hiện có phép đo từ 29/01 đến 11/12/2024; các mẫu không đại diện cho toàn năm hoặc toàn Hà Nội. Không biến giờ thiếu thành nồng độ 0, không gộp trung bình của các chất, không kết luận AQI hay vượt quy chuẩn từ các số này. So sánh hai trạm cần ghép đúng cùng giờ như truy vấn SQL 04.


## Cập nhật ngày 28/11/2026

Đã nhập database SSAS vào project Visual Studio `HanoiAirCubeImported` bằng wizard và build thành công; project `HanoiAirCube` ban đầu vẫn là khung riêng. Đã mở lại PBIP, kết nối mô hình qua MCP và chạy DAX; kết quả PM10 và PM2.5 khớp SQL như trên.

Microsoft chưa công bố schema report 3.4.0 và visualContainer 2.15.0: các URL tương ứng trả 404. Kiểm tra tương thích với schema công khai gần nhất report 3.3.0 và visualContainer 2.13.0: năm visual hợp lệ; `report.json` có thuộc tính `linguisticSchemaSyncVersion` mới không có trong schema cũ. Đây không phải kiểm tra chính xác theo schema mới. Giữ nguyên tệp gốc, không hạ phiên bản schema hay xóa thuộc tính; cần kiểm tra lại khi Microsoft công bố schema chính xác.

## Cập nhật sơ đồ và dashboard 28/11/2026

Project `HanoiAirCubeImported` đã bổ sung quan hệ DSV từ FactAirQuality đến DimDate, DimTime, DimStation, DimPollutant theo các khóa thực của SQL Server. Kiểm tra XML DataSet đọc lại đủ bốn quan hệ; build Visual Studio thành công và file `.asdatabase` chứa cả bốn. Đã mở cửa sổ Visual Studio mới và kiểm tra trực quan sơ đồ có bốn đường nối; thay đổi này ở project, chưa deploy đè database SSAS đang hoạt động. Cube có bốn dimension được ánh xạ riêng trong Dimension Usage. DimSensor có trong kho và Power BI, chưa đưa vào cube/DSV SSAS.

Power BI có năm quan hệ fact–dimension hoạt động, gồm DimSensor. Đã chuyển scorecard rỗng cần đăng nhập thành thẻ số phép đo hợp lệ và PM2.5 trung bình, bổ sung biểu đồ thanh theo trạm/chất, giữ bộ lọc; biểu đồ cột theo ngày thể hiện khoảng dữ liệu thiếu. Với PM2.5 và cả hai trạm, dashboard thể hiện 5.749 phép đo và 38,75 µg/m³; DAX đối chiếu Hàng Đậu 3.251 mẫu, 43,26 và Khương Trung 2.498 mẫu, 32,88. Đếm này là dữ liệu PM trong kho, không phải 23.036 dòng nguồn gồm bốn chất.

Minh chứng: `report/minh_chung/buoc11_ssas_sodo_quanhe.png` và `report/minh_chung/buoc11_powerbi_hoan_thien.png`. Validate PBIR không có lỗi nhưng còn cảnh báo hai schema mới do Microsoft chưa công bố; không coi là đã kiểm tra schema đầy đủ. Không kết luận hơn/kém giữa hai trạm từ hai trung bình này nếu không xét độ bao phủ và giờ đồng thời.

## Cập nhật hoàn thiện Bước 11 (28/11/2026)

- **Bổ sung `DimSensor` vào SSAS:** Đã thêm `dbo.DimSensor` và quan hệ `FK_FactAirQuality_DimSensor` vào `Warehouse.dsv`, tạo `Sensor.dim`, ánh xạ vào cube `Air Quality`, cập nhật `olap/cap_quyen_doc_ssas.sql` và cấp `SELECT` trên `dbo.DimSensor` cho `NT SERVICE\MSSQLServerOLAPService`. Cube SSAS hiện có đủ 5 chiều (`Date`, `Time`, `Station`, `Pollutant`, `Sensor`) khớp Star Schema của kho và Power BI.
- **Xử lý cảnh báo build Visual Studio:** Đã sửa 9/10 cảnh báo build của `HanoiAirCubeImported` (đặt `Date.dim` là `Type = Time` với kiểu thuộc tính thời gian và hierarchy `Calendar`; bổ sung hierarchy cho `Time`, `Station`, `Pollutant`, `Sensor`; đặt `AttributeHierarchyVisible = false` cho các thuộc tính nằm trong hierarchy; đặt `RelationshipType = Rigid` và `KeyDuplicate = ReportAndStop`). Chỉ còn 1 cảnh báo chung của SSDT (`Do not use unsupported OLE DB providers in a DataSource`) dù đã chuyển sang `MSOLEDBSQL19.1` (0 lỗi build).
- **Deploy, Process và đồng bộ:** Đã deploy bản build `HanoiAirCubeImported` lên database `HanoiAirOLAP` trên SSAS `localhost`, chạy `ProcessFull` thành công (5 chiều, 5 quan hệ DSV), xuất lại `olap/HanoiAirOLAP.xmla` và cập nhật `olap/tao_cube.ps1`. Chạy lại 3 truy vấn MDX `01`–`03` (11.500 phép đo: PM10 5.751 / TB 63,82; PM2.5 5.749 / TB 38,75) cùng truy vấn kiểm tra chiều `Sensor` (4 cảm biến: 3.251, 3.253, 2.498, 2.498).
