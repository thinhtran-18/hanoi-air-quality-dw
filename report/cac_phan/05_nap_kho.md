# Bước 8 — Nạp dimension và fact

Ngày thực hiện: 27/11/2026. Cài và gọi các procedure bằng sqlcmd trên SQL Server; chưa thao tác gọi trong giao diện SSMS. Cùng T-SQL có thể gọi từ SSMS theo hướng dẫn `sql/etl/README.md`.

| Kiểm tra | Kết quả thực tế |
| --- | --- |
| Lần đầu | Trích xuất 11.500; mới 11.500; đã có 0; từ chối/trùng/ngoài phạm vi/xung đột đều 0; Success |
| Lần hai | Trích xuất 11.500; mới 0; đã có giống payload 11.500; các nhóm còn lại 0; Success |
| Số fact sau chạy lại | 11.500 |
| Dimension trạm / cảm biến / chất | 2 / 4 / 2 |
| Fact đối chiếu SourceId, trạm, cảm biến, chất, thời điểm và giá trị SQL nguồn | 11.500 khớp; 0 không khớp |
| Trùng grain và UNIQUE | 0 nhóm trùng; UNIQUE `(StationKey, SensorKey, ObservedAtUTC, PollutantKey)` đã tồn tại |
| Test xung đột | Cùng grain, giá trị khác: lỗi 51306, rollback, số fact không đổi |
| Test chạy đồng thời | Giữ application lock ở phiên khác: batch mới lỗi 51308, log Failed vẫn tồn tại, fact giữ 11.500 |

Có thêm một lần chạy lặp kiểm tra khi chuẩn bị test khóa: Success, 0 mới, 11.500 đã có. Test xung đột dùng dữ liệu tổng hợp và transaction rollback; không sửa bảng nguồn. Batch cũ của bước 7 vẫn Running do chỉ chuẩn hóa, không phải batch nạp bước 8.

## Quy tắc

`usp_StartBatch` tạo ID/log; `usp_ValidateStage` trích xuất và phân loại, dừng khi xung đột; `usp_LoadDimensions` nạp khóa trạm/cảm biến/chất và cập nhật trạm Type 1 có JSON cũ/mới; `usp_LoadFact` tra khóa, kiểm tra payload với staging gốc của fact và nạp dòng mới; `usp_FinishBatch` ghi Success theo CHECK cân đối. `usp_RunBatch` điều phối và giữ transaction/khóa. Date/Time đã nạp ở bước 6.

Các nhóm thành công loại trừ nhau: trích xuất = mới + đã có giống payload + từ chối + trùng trong batch + ngoài phạm vi. Xung đột gây lỗi, không tính thành công. Chỉ trích xuất pm25/pm10 nên CO/NO2 không tính vào mẫu số. Số FLOAT nguồn được giữ FLOAT(53), so giá trị nạp lại theo giá trị nguồn; đối soát với CSV theo dung sai bước 4.

## Giới hạn

- Chưa thử gọi trực tiếp trên giao diện SSMS; procedure đã được gọi thành công qua sqlcmd trên SQL Server. Chưa kiểm tra lại việc dựng bước 6 trên database trống hoặc bổ sung ảnh SSMS còn thiếu.
- Test Failed đã xác minh lỗi do tranh khóa và log bền vững; test xung đột đã xác minh procedure nạp fact dừng và rollback riêng. Chưa test tích hợp toàn bộ `usp_RunBatch` với nguồn thật bị thay đổi để tạo xung đột vì không sửa nguồn.
- Dòng xung đột trong batch thất bại và RejectRow rollback cùng transaction; ErrorMessage bền vững nhưng chưa lưu chi tiết từng dòng lỗi. Cần bổ sung nhật ký chi tiết ngoài transaction nếu yêu cầu vận hành sau này.
- Chưa thử tình huống cập nhật metadata Type 1 thực tế và kiểm chứng JSON cũ/mới; batch hiện có metadata cố định. Cần test trước khi cho phép cập nhật metadata từ nguồn thay đổi.
- Staging được giữ để so sánh lineage/payload; chưa có quyền hạn tách bạch hoặc chính sách lưu trữ và kiểm soát việc xóa thủ công. Khóa ứng dụng không ngăn các thao tác SQL ngoài quy trình.
- Chưa chứng minh sensor–trạm–chất theo metadata độc lập, mới kiểm tra tính nhất quán trong batch. Không xử lý SSIS, OLAP, dashboard trong bước này.
- Dữ liệu lịch sử không liên tục; giờ thiếu không phải 0 và không suy mẫu hiện có đại diện cả năm.
