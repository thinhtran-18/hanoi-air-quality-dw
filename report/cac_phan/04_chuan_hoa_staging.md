# Bước 7 — Staging và chuẩn hóa

Ngày kiểm tra: 27/11/2026. Đã cài và chạy `sql/etl/01_chuan_hoa.sql` trên kho hiện tại; tạo view `stg.vAirQualityClassified`, hai procedure trích xuất và phân loại. Chưa nạp dimension/fact.

## Chính sách và kết quả

Trích xuất từ bảng SQL nguồn các chất pm25/pm10 sau trim/lower; CO/NO2 không vào batch. Staging giữ batch, SourceId, thời gian nguồn có offset và trường gốc. View chuẩn hóa mã chất, đơn vị và tên; tính UTC/local độ chính xác 7 chữ số, DateKey/TimeKey từ UTC+07. Không thay đổi giá trị/đơn vị gốc, không làm tròn timestamp để tạo khóa.

| Phân loại | Quy tắc |
| --- | --- |
| ACCEPTED | Đầy đủ trường bắt buộc, đúng phạm vi trạm/chất/năm, đơn vị µg/m³, giá trị không âm, mốc đầu giờ; không xung đột và chỉ giữ dòng đầu theo StageRowId |
| REJECTED | Thiếu mã/thời gian/tên/đơn vị/giá trị, đơn vị lạ, âm, tọa độ ngoài phạm vi, thời điểm khác đầu giờ hoặc có phần giây; lưu RejectRow kèm lý do và payload |
| EXCLUDED | Trạm/chất/năm ngoài phạm vi; giữ ở staging, không ghi RejectRow vì không phải lỗi chất lượng |
| DUPLICATE | Cùng grain và payload chuẩn hóa giống nhau; giữ một dòng, ghi các dòng dư vào RejectRow |
| CONFLICT | Cùng grain nhưng payload khác; không chọn dòng đạt nào trong nhóm xung đột; lưu lý do vào RejectRow |

Grain dùng trạm–cảm biến–UTC chính xác–chất, trong cùng batch. Payload so sánh SHA-256 JSON của tên chuẩn hóa, timestamp nguồn, tọa độ, đơn vị và giá trị; SourceId khác nhau không làm thành hai phép đo. Các dòng sai đơn vị/giá trị âm cùng grain cũng tham gia phát hiện xung đột với dòng đạt; dòng sai vẫn phân loại REJECTED. Dòng thiếu khóa không thể đối chiếu grain. Hash có rủi ro va chạm lý thuyết; khi triển khai nghiệp vụ trọng yếu cần so payload đầy đủ. So sánh FLOAT theo giá trị biểu diễn JSON nguồn, không tự gộp số gần nhau.

Giá trị >= 150 µg/m³ được gắn `ReviewHigh=1` để ưu tiên xem xét, vẫn ACCEPTED nếu đạt các kiểm tra khác. **150 là ngưỡng sàng lọc kỹ thuật tạm thời do dự án đặt cho cả hai chất, không phải quy chuẩn hay ngưỡng sức khỏe.** Không diễn giải là vượt chuẩn. Có 351 dòng trong batch hiện tại được gắn cờ; cần người phụ trách xác minh/điều chỉnh ngưỡng cho mục đích phân tích trước khi sử dụng.

Batch nguồn thực đã chạy: **11.500 nhận, 11.500 ACCEPTED, 0 REJECTED, 0 DUPLICATE, 0 CONFLICT, 0 EXCLUDED**. Có 11.500 SourceId phân biệt. So sánh StationId, SensorId, thời gian nguồn, giá trị, chất và đơn vị giữa staging và SQL nguồn cho 0 sai khác; việc đối chiếu toàn bộ 23.036 dòng SQL/CSV đã thực hiện ở bước 4. Fact vẫn 0 dòng.

`sql/checks/kiem_thu_buoc7.sql` tạo 11 dòng tổng hợp trong transaction, kiểm tra 2 accepted, 5 rejected, 1 duplicate, 2 conflict, 1 excluded; kiểm tra lineage, chuyển ngày nửa đêm và giá trị cao; rollback sau thử. Thao tác thử có thể làm tăng IDENTITY. Những ca này không chứng minh toàn bộ trường hợp đầu vào tương lai.

## Cách chạy

1. Chạy các script bước 6 theo `sql/schema/README.md`; sau đó chạy `sql/etl/01_chuan_hoa.sql` bằng SSMS hoặc `sqlcmd -b -f 65001`.
2. Trong database kho, chạy `DECLARE @b uniqueidentifier; EXEC etl.ExtractAirQualityBatch @BatchId=@b OUTPUT; SELECT @b AS BatchId;` và lưu BatchId trả về.
3. Truy vấn `stg.vAirQualityClassified` theo BatchId để đếm và xem các nhóm; `etl.RejectRow` lưu BatchId, SourceId, StageRowId, reason và JSON của dòng bị từ chối/trùng/xung đột. Tra batch trong `etl.BatchLog`.
4. Kiểm thử tái lập bằng `sql/checks/kiem_thu_buoc7.sql` trên môi trường thử phù hợp; nó rollback nhưng có thể làm tăng IDENTITY.

Mỗi lần Extract tạo một batch mới, không làm rỗng staging. Cùng batch chỉ phân loại một lần; không sửa/thêm staging sau khi phân loại vì view tính lại từ staging và RejectRow/count sẽ không đồng bộ. Đây là **quy tắc vận hành chưa được khóa bằng quyền hoặc trigger**. Chưa có kiểm soát chống hai phiên đồng thời sửa staging trong lúc phân loại; sử dụng một phiên cho mỗi batch. Trước bước 8 cần bổ sung cơ chế khóa/trạng thái và kiểm thử đồng thời.

`BatchLog.Status` cố ý giữ `Running`: bước 7 chỉ chuẩn hóa, chưa ghi fact, nên không gán `InsertedRows` bằng số ACCEPTED hoặc báo ETL Success. Tổng phân loại = ACCEPTED + REJECTED + DUPLICATE + CONFLICT + EXCLUDED; ConflictRows đếm tất cả dòng candidate xung đột, không cộng vào RejectedRows. Nếu trích xuất/phân loại lỗi, toàn bộ transaction rollback kể cả log; chưa có nhật ký batch thất bại bền vững. Việc kết thúc Success/Failed, chống trùng giữa các batch và cân đối fact thuộc bước 8.

## Giới hạn

Staging có kiểu SQL nên không lưu được văn bản không parse thành số/thời gian; phạm vi bước này lấy từ bảng nguồn đã có kiểu, không nạp CSV thô. Thiếu SourceId không thể vào staging vì bảng nguồn SQL chính có id; với SourceId <= 0 RejectRow giữ StageRowId và payload, cột SourceId NULL do CHECK; trường hợp này không thể truy về id hợp lệ trong nguồn. Batch thực không có trường hợp đó. Không có cột tự chứng nhận sensor–trạm–chất đúng metadata: cần kiểm tra ở bước nạp dimension/fact.

SSIS, nạp fact, xử lý rerun/xung đột với fact và nhật ký chạy thất bại chưa hoàn thành. Dữ liệu lịch sử vẫn không liên tục; không biến giờ thiếu thành nồng độ 0 hoặc kết luận đại diện cả năm.
