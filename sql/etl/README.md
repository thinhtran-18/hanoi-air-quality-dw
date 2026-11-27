# ETL T-SQL bước 7–8

## Bổ sung giao diện cho SSIS

Chạy `03_ssis_staging.sql` trong SSMS sau 01–02. `etl.usp_StartSSISBatch` trả một dòng BatchId dạng varchar(36) để map vào biến String SSIS; Data Flow nạp staging theo BatchId. Sau khi Data Flow hoàn tất, gọi **một** `etl.usp_ProcessStagedBatch @BatchId` để phân loại staging sẵn có rồi nạp dimension/fact trong cùng transaction và application lock; không gọi `usp_ValidateStage` cũ (vì tự trích xuất lại). Nếu Data Flow thất bại trước khi gọi process, nhánh lỗi phải gọi `etl.usp_FailStagedBatch @BatchId, @Reason` trên kết nối ngoài transaction.

Thử trong SSMS: staging mô phỏng 11.500 dòng được xử lý Success, 0 mới / 11.500 đã có; dòng cùng grain khác giá trị tạo Failed và fact không đổi; gọi FailStagedBatch ghi Failed. Sau đó package SSIS đã chạy thành công hai lần trong Visual Studio: mỗi batch trích 11.500, 0 mới / 11.500 đã có, fact giữ 11.500. Còn bổ sung ảnh cấu hình tham số và xử lý batch cũ Running.

Lock hiện chỉ bao trùm giai đoạn `ProcessStagedBatch`, không bao trùm Data Flow trước đó: không chạy hai package đồng thời hoặc sửa staging bằng tay. Nhánh Failure cho Data Flow đã được cấu hình; lỗi/crash trước khi handler chạy có thể để batch Running hoặc staging dở. Lỗi xử lý fact lưu ErrorMessage, nhưng RejectRow bị rollback; chưa có chi tiết xung đột bền vững. Chưa giải quyết triệt để khóa staging sau khi xử lý hoặc logging Type 1 với dữ liệu thay đổi; xem báo cáo bước 8.

Thư mục `sql/etl/` chứa T-SQL; thư mục `etl/` ở gốc dành cho project SSIS. Chạy sau khi tạo cấu trúc bước 6:

1. Chạy `sql/etl/01_chuan_hoa.sql` để cài view và procedure phân loại bước 7.
2. Chạy `sql/etl/02_nap_kho.sql` để cài 5 procedure bước 8 và procedure điều phối.
3. Trong SSMS, chọn database kho và chạy:

```sql
DECLARE @BatchId uniqueidentifier;
EXEC etl.usp_RunBatch @BatchId OUTPUT;
SELECT @BatchId AS BatchId;
```

`usp_RunBatch` gọi theo thứ tự StartBatch, ValidateStage (bao gồm trích xuất), LoadDimensions, LoadFact, FinishBatch. Bốn procedure từ Validate đến Finish chỉ được gọi bên trong transaction đã giữ application lock; gọi qua `usp_RunBatch` để bảo đảm rollback/log. StartBatch ghi log trước transaction, procedure điều phối khóa toàn bộ staging trong lúc chạy, chỉ cho một ETL dùng cùng application lock. Không gọi từ transaction bên ngoài. Không can thiệp thủ công vào staging, dimension, fact trong khi chạy; khóa ứng dụng chỉ ràng buộc những tiến trình tuân theo khóa này.

Nếu lỗi, transaction nạp rollback, BatchLog chuyển Failed với ErrorMessage sau rollback. Do SQL Server không bảo đảm truyền tham số OUTPUT khi procedure THROW, tìm batch thất bại theo StartedAtUTC trong BatchLog. Dữ liệu staging/RejectRow của batch thất bại cũng rollback, nên lỗi được lưu ở ErrorMessage nhưng chưa lưu chi tiết từng dòng xung đột bền vững. Bản chạy thành công giữ staging để đối soát payload các lần nạp sau; không xóa hoặc sửa staging được fact tham chiếu. Chưa có chính sách dọn staging.

Thành công: `ExtractedRows = InsertedRows + ExistingRows + RejectedRows + DuplicateRows + ExcludedRows`, ConflictRows=0; bảng log CHECK cưỡng chế cân đối. Source chỉ lọc 2 chất trước trích xuất, ExcludedRows gồm các dòng ngoài phạm vi khác nếu có. Fact không tự đổi giá trị khi cùng khóa khác payload, batch bị Failed. Metadata trạm cập nhật Type 1 trong transaction; thay đổi cũ/mới ghi JSON trong BatchLog; dữ liệu nguồn có metadata không nhất quán bị dừng. Sensor chỉ chấp nhận một trạm và một chất trong batch; cần xác minh metadata độc lập khi nguồn mở rộng.

Kiểm thử xung đột `sql/checks/kiem_thu_buoc8.sql` chỉ dùng sau khi có fact nguồn hiện tại; chạy test trong transaction rồi rollback, có thể tăng IDENTITY. Không chạy bộ thử bước 6 vốn yêu cầu kho trống trên kho đã nạp. Chi tiết số liệu và giới hạn xem `report/cac_phan/05_nap_kho.md`.
