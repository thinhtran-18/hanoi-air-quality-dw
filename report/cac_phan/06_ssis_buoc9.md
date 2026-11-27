# Bước 9 — Đóng gói ETL bằng SSIS

Ngày ghi nhận: 27/11/2026. Package `00_RunAll.dtsx` chạy trong Visual Studio theo luồng StartBatch → Data Flow → ProcessStagedBatch; Data Flow thất bại đi vào nhánh FailStagedBatch. Procedure xử lý staging thực hiện phân loại, nạp dimension/fact và kết thúc batch trong cùng transaction và application lock.

## Kết quả đã quan sát

- Hai lần chạy SSIS Success, mỗi lần 11.500 dòng trích xuất, 0 dòng mới, 11.500 dòng đã có; số fact sau chạy lại: 11.500.
- Ảnh Data Flow cho thấy 11.500 dòng đi vào staging; Control Flow thể hiện task thành công.
- Một lần Data Flow trước đó lỗi chuyển GUID, nhánh lỗi chạy và BatchLog ghi Failed.
- Ảnh minh chứng ánh xạ BatchId ở Result Set và Parameter Mapping đã được lưu tại `report/minh_chung/`.

## Giới hạn và việc còn lại

- Một batch cũ còn Running sau lỗi ánh xạ StartBatch. Cần xác nhận đúng batch, xác nhận không còn chạy và ghi Failed có lý do; chưa sửa lịch sử.
- `Project.params` chưa cấu hình server/database; connection managers dùng Windows Authentication và cấu hình trên máy. Cần cấu hình lại khi chuyển môi trường; không chạy đồng thời hai package.
- Application lock chỉ bao trùm xử lý staging, không bao trùm Data Flow. Lỗi hoặc crash trước khi xử lý thất bại có thể để batch Running hoặc staging dở; log lỗi xung đột chi tiết chưa bền vững qua rollback.
- Bản project công khai đã loại metadata cá nhân và dữ liệu nhạy cảm mã hóa; cần xác nhận mở/build sau khi tải xuống và cấu hình lại kết nối. Việc chạy thành công được ghi nhận trên bản cục bộ ban đầu.
- Dữ liệu là lịch sử không liên tục; không coi giờ thiếu bằng 0 hoặc suy mẫu đại diện cả năm.

Xem hướng dẫn thao tác chi tiết `docs/huong_dan_buoc_9_ssis.md`.
