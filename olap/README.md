# Cube HanoiAirOLAP

Cube `Air Quality` đã triển khai trực tiếp tới SSAS Multidimensional trên `localhost` bằng AMO; project Visual Studio `HanoiAirCube` vẫn là khung riêng và không phản ánh cube đã triển khai. Bản định nghĩa đã xuất từ SSAS nằm ở `HanoiAirOLAP.xmla`, mã dựng ở `tao_cube.ps1`. Script dựng từ chối ghi đè database đã có dimension hoặc cube.

Khi cài lại trên máy khác, cần điều chỉnh server, đường dẫn AMO, tài khoản dịch vụ và cấp quyền đọc tối thiểu tương ứng bằng `cap_quyen_doc_ssas.sql`; xử lý database sau khi tạo. Phần mềm Power BI đang dùng mô hình riêng từ kho SQL, không kết nối tới cube.

Ba tệp MDX 01–03 truy vấn từng chất, trạm–chất và năm–tháng–chất. Kết quả CSV nằm tại `report/minh_chung/*_mdx.csv`. Measure đếm dòng hợp lệ, measure trung bình chia tổng nội bộ cho số dòng và bỏ trống tại mức tổng nhiều chất. Mọi thống kê phải đọc cùng số quan sát; dữ liệu không liên tục.

## Cập nhật ngày 28/11/2026

Đã dùng wizard Import from Server (Multidimensional) nhập database `HanoiAirOLAP` vào project Visual Studio `HanoiAirCubeImported`, sau đó bổ sung `DimSensor`, 5 quan hệ DSV, user hierarchies cho các chiều và cấu hình `KeyDuplicate = ReportAndStop` (còn 1 cảnh báo provider SSDT đối với `MSOLEDBSQL19.1`, 0 lỗi build). Đã deploy đồng bộ và `ProcessFull` lại database `HanoiAirOLAP` trên `localhost` (5 chiều: `Date`, `Time`, `Station`, `Pollutant`, `Sensor`), xuất lại `HanoiAirOLAP.xmla` và cập nhật `tao_cube.ps1` cùng `cap_quyen_doc_ssas.sql`. Project `HanoiAirCube` ban đầu vẫn là khung trống. Không deploy đè lên server khác khi chưa kiểm tra đích.
