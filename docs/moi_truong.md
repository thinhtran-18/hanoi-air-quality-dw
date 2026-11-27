# Môi trường thực hiện

Cập nhật bản bàn giao ngày 28/11/2026. Đây là các phiên bản đã ghi nhận trong quá trình thực hiện, không phải yêu cầu mọi máy phải cài đúng cùng phiên bản.

| Thành phần | Phiên bản hoặc cấu hình đã dùng |
| --- | --- |
| SQL Server Database Engine | SQL Server 2025 RTM-GDR 17.0.1155.3, Enterprise Developer |
| SSMS | 22, phiên bản 22.12.1 |
| Visual Studio | Community 2026, phiên bản 18.12.1 |
| Integration Services Projects | 2.2 |
| Power BI Desktop | 2.160.1151.0, hỗ trợ PBIP/PBIR |
| Driver kiểm tra kết nối độc lập | ODBC Driver 18 for SQL Server, bản 32/64 bit |
| SSIS | OLE DB Connection Managers; chọn provider thực có trên máy và Test Connection |
| SSAS | Multidimensional, cube Air Quality với 5 chiều |

## Trạng thái đã kiểm chứng

- SQL nguồn hanoi_air_vn và kho hanoi_air_dw đã tồn tại; kiểm tra bước 16 xác nhận 23.036 dòng nguồn và 11.500 fact hợp lệ.
- SSIS Projects đã cài và package đã chạy thành công hai lần theo minh chứng bước 9. Việc cài extension hoặc kiểm tra ODBC riêng không tự chứng minh package chạy đúng.
- Cube SSAS đã deploy/process theo hồ sơ bước 11; project nhập lại đầy đủ là olap/HanoiAirCubeImported. Bản build lịch sử còn một cảnh báo provider.
- PBIP đã mở trực tiếp; MCP kết nối mô hình 7 bảng và 8 quan hệ trong bước 16. Kiểm tra mô hình và xem giao diện là hai thao tác được ghi riêng.
- Word và PowerPoint đầu ra đã được mở bằng Office và kiểm tra hình thức toàn bộ trang/slide.

## Kiểm tra trên máy mới

1. SSMS / Connect / Database Engine / chọn server của máy / kiểm tra kết nối. Chạy SELECT @@VERSION và SELECT 1.
2. Visual Studio / Open Project or Solution / etl/HanoiAirETL/HanoiAirETL.slnx / kiểm tra TargetServerVersion và provider. Mở CN_Nguon, CN_Kho / chọn đúng database / Test Connection.
3. Nếu trình diễn cube: kiểm tra dịch vụ SSAS Multidimensional, Analysis Services Projects, quyền đọc nguồn của dịch vụ và đích deploy.
4. Power BI Desktop / mở dashboard/HanoiAirOLAP.pbip / Data source settings / cấu hình nguồn SQL / Refresh. Không có cache .pbi trong bản clone.
5. Python 3 / chạy python tools/doi_soat_nguon.py. Thư viện chuẩn đủ cho kiểm tra nguồn; công cụ vẽ cần Pillow và font Arial trên Windows.

## Giới hạn và lịch sử cần hiểu

Quá trình cài SSIS từng có lỗi thành phần BI dùng chung; đã xử lý qua công cụ cài đặt chính thức và mở được package designer. Các mô tả lỗi cài đặt ban đầu không phản ánh trạng thái cuối. Log cài đặt, đường dẫn riêng và cấu hình máy được giữ cục bộ.

Không tự xóa thành phần dùng chung của Visual Studio để sửa lỗi. Khi chuyển máy, kiểm tra lại driver/extension/quyền thay vì dựa vào việc máy phát triển đã chạy. Project.params chưa tham số hóa đầy đủ nên connection cần cấu hình thủ công. Xem docs/huong_dan_chay.md và report/kiem_tra_buoc_1_den_15.md.
