# Môi trường phát triển - kiểm tra ngày 27/11/2026

## Cập nhật sau xử lý lỗi cài SSIS

Trạng thái mới nhất ngày 27/11/2026 thay thế các mô tả lỗi cũ bên dưới: **Visual Studio đã `isComplete=True`; SSIS Projects 2.2 đã cài thành công**. Restart trước đó không giải quyết được do trạng thái Repair lỗi vẫn còn. Trong state.errors của VS, gói Microsoft Analysis Services Projects 4.0.0 bị lỗi tải với URI rỗng, mã 0x80004003. Log SSIS sau Restart không có RebootPending.

Đã dùng VSIX Installer chính thức gỡ riêng Analysis Services Projects 4.0.0 gây lỗi; tiến trình gỡ hoàn tất, VS chuyển sang hoàn tất cài đặt. Sau đó chạy lại trình cài SSIS 2.2, chọn được instance và cài hết luồng với mã `0x0`, không yêu cầu Restart. Không sửa tay state.json/registry hoặc xóa BIShared.

Đã mở Visual Studio, chọn mẫu Integration Services Project, tạo project kiểm tra cục bộ và mở Package.dtsx thành công với Control Flow, Data Flow, Connection Managers và SSIS Toolbox. Project kiểm tra nằm trong `.local/`, được Git bỏ qua. Đây chưa phải package ETL của dự án; chưa kiểm chứng kết nối, chạy/debug package ETL hoặc Script Task. Log VSTA có cảnh báo bước cleanup không trọng yếu; toàn bộ bộ cài vẫn trả mã thành công.

**Analysis Services hiện đã được gỡ**; nếu cần cube SSAS về sau phải cài lại extension từ nguồn Microsoft và kiểm tra riêng. SQL Server, dữ liệu nguồn và kho không bị gỡ trong thao tác này. Các mục lịch sử phía dưới mô tả trạng thái trước khi sửa.

| Thành phần | Kết quả kiểm tra |
| --- | --- |
| Repo | `D:\Kho_dlieu\hanoi-air-quality-dw`, nhánh `main`, remote `https://github.com/thinhtran-18/hanoi-air-quality-dw.git` |
| SQL Server Database Engine | SQL Server 2025 RTM-GDR 17.0.1155.3, Enterprise Developer, dịch vụ MSSQLSERVER đang chạy |
| SQL Server Management Studio | SSMS 22, phiên bản 22.12.1 |
| Visual Studio | Visual Studio Community 2026, phiên bản 18.12.1 |
| Power BI Desktop | Bản Microsoft Store, phiên bản 2.160.1151.0; chưa kiểm tra giao diện connector SQL Server |
| SQL Server Integration Services Projects | Trình cài 2.2 bị lỗi, chưa xác nhận extension cài thành công hoặc tạo được project |
| ODBC Driver 18 for SQL Server | Có bản 32-bit và 64-bit; kết nối tới `localhost`, database `master`, Windows Authentication thành công bằng ODBC |

## Kiểm tra đã thực hiện

- `sqlcmd -S localhost -E -C -Q "SELECT @@VERSION; SELECT 1;"` chạy thành công.
- Kiểm tra ODBC Driver 18 kết nối `localhost`, Windows Authentication và `TrustServerCertificate=Yes`; truy vấn `SELECT 1` trả về 1. Đây là kiểm tra driver độc lập, chưa phải Test Connection trong SSIS.
- Đã chạy truy vấn trên hai bảng tạm để luyện `LEFT JOIN`, `GROUP BY`, `COUNT` và `AVG`; bảng tạm tự mất khi phiên kết nối kết thúc.
- Không tìm thấy database `hanoi_air_vn` trên instance `localhost` khi kiểm tra. Chưa kết luận về các instance khác.

## Lỗi cài SSIS cần xử lý tiếp

Log `%TEMP%\SsdtisSetup\Microsoft.DataTools.IntegrationServices_20261127063109_1_ISVsix.log` ghi gói BI Shared Components phiên bản 7.0.1 không cài được vì `BIShared.manifest` đã tồn tại tại `C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\BIShared`. Quá trình cài SSIS đã rollback. Cùng thư mục chứa manifest của Microsoft BI Shared Components, phụ thuộc dùng chung với Analysis Services/Reporting Services; cần xử lý bằng công cụ cài đặt chính thức, tránh tự xóa bừa thành phần dùng chung.

Chưa kiểm tra được tạo Integration Services Project, TargetServerVersion, SSIS Connection Manager hay Power BI SQL Server connector trong giao diện. ODBC kiểm tra độc lập không chứng minh SSIS đã hoạt động.

## Cập nhật sau Repair Visual Studio

- Đã chạy Repair theo yêu cầu. Visual Studio Installer báo hoàn tất có cảnh báo, không phải thành công hoàn toàn.
- Log `%TEMP%\dd_setup_20261127072308.log` báo không tải được gói Analysis Services `89387616-73c8-4223-a360-f36c90a01f6b` 4.0.0 do `0x80004003`, tham số URI rỗng.
- Đã tải gói Analysis Services 4.0.0 chính thức từ Marketplace; VSIX Installer báo đã cài. Sau Repair, giao diện Visual Studio vẫn hiển thị mẫu Analysis Services Multidimensional Project và Analysis Services Tabular Project.
- `vswhere` báo Visual Studio `isComplete=False`. Trình cài SSIS không cho chọn instance và ghi có thể phải khởi động lại. Chưa cài được SSIS, chưa test tạo project SSIS.
- Bước tiếp: lưu công việc, khởi động lại Windows theo thông báo trình cài; kiểm tra lại trạng thái instance, Analysis Services và cài SSIS. Nếu trạng thái vẫn chưa hoàn tất, chẩn đoán tiếp lỗi gói không có URI thay vì tiếp tục giả định khởi động lại đã sửa lỗi.
