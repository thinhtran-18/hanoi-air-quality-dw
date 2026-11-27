# Kịch bản demo 8–10 phút

Chuẩn bị SSMS kết nối đúng kho; Visual Studio mở `00_RunAll.dtsx`; Power BI mở `dashboard/HanoiAirOLAP.pbip`. Giữ kết quả và cửa sổ mở để người xem theo dõi. Dùng bộ dữ liệu chốt, không tải nguồn hoặc dựng lại kho thật giữa buổi trình bày.

| Thời gian | Thao tác trực quan | Điều cần nói và kết quả kiểm tra |
|---|---|---|
| 0:00–0:45 | Slide bài toán | Hai trạm, năm 2024 UTC+07, PM2.5/PM10; phân tích nồng độ và độ phủ |
| 0:45–1:30 | SSMS đếm nguồn theo chất | 23.036 nguồn cả 4 chất; chỉ 11.500 PM vào kho; 325 tệp gốc |
| 1:30–2:15 | Mở sơ đồ Star | 5 chiều nối fact; một dòng là trạm–cảm biến–thời điểm–chất; SourceId/BatchId giúp truy vết |
| 2:15–3:45 | Visual Studio chạy package, xem Data Flow/Progress; SSMS xem BatchLog | 11.500 staging; trên kho hiện có 0 mới/11.500 đã có; fact giữ nguyên. Nếu chưa chạy trực tiếp chỉ trình bày ảnh lịch sử và gọi đúng là minh chứng lịch sử |
| 3:45–4:30 | SSMS truy vấn trung bình theo chất hoặc MDX | PM2.5 5.749 mẫu/TB 38,75; PM10 5.751 mẫu/TB 63,82; không SUM nồng độ |
| 4:30–5:30 | Power BI Trang 1 | Tách hai chất, độ phủ 28,44–37,03%, lịch năm 8.784 giờ/trạm/chất; thiếu không phải 0 |
| 5:30–6:30 | Trang 2 chọn tháng 8; chọn lại khoảng có dữ liệu | Khoảng trống trả BLANK; biểu đồ cột không nối qua khoảng thiếu; thử bỏ chọn chất |
| 6:30–7:45 | Trang 3 chọn pm25, cả năm | 2.098 giờ chung; Hàng Đậu 42,88, Khương Trung 32,47; chênh 10,42 µg/m³. Nói rõ cùng tập giờ |
| 7:45–8:45 | Đối soát SQL với ngày 29/01/2024, pm25 | 2 giờ chung; 62,05 và 47,65; chênh 14,40. Mở CSV 17 ca kiểm chứng |
| 8:45–9:30 | Slide đánh giá/hướng chạy | Không đại diện liên tục cả năm; không suy nguyên nhân/AQI. Còn giới hạn tham số hóa SSIS và tái lập package trên kho trống |

Truy vấn demo chỉ đọc, mở trong SSMS:

```sql
SELECT parameter, COUNT_BIG(*) AS Samples
FROM hanoi_air_vn.dbo.air_quality_hourly GROUP BY parameter;
USE hanoi_air_dw;
SELECT TOP (5) StartedAtUTC,Status,ExtractedRows,InsertedRows,ExistingRows,
       RejectedRows,DuplicateRows,ExcludedRows,ConflictRows
FROM etl.BatchLog ORDER BY StartedAtUTC DESC;
SELECT COUNT_BIG(*) AS FactRows FROM dbo.FactAirQuality;
SELECT * FROM dbo.vw_StationPairHourly WHERE DateKey=20240129;
```

Câu hỏi ôn tập: Vì sao 23.036 khác 11.500? Vì sao không dùng SUM(Value)? Tại sao grain cần SensorKey? Vì sao DateKey theo local? Lần nạp hai có thêm dòng không? Không có dòng khác gì giá trị 0? Trung bình riêng từng trạm khác trung bình giờ chung thế nào? Vì sao chưa kết luận mức ô nhiễm đại diện toàn năm? Máy mới cần sửa kết nối ở đâu?

Nếu mất kết nối: giữ ứng dụng và thông báo lỗi để xem, kiểm tra đúng server/database, driver và quyền; dùng ảnh minh chứng đã lưu để giải thích kết quả lịch sử. Không mô tả ảnh như một lượt thực thi mới thành công.
