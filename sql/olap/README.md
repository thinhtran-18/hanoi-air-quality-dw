# Truy vấn OLAP bước 11

Chạy từng file 01–08 trong SSMS trên `hanoi_air_dw`. Chỉ đọc; kết quả phụ thuộc phiên bản kho và dữ liệu được nạp. Bản tổng hợp đã chạy trong SSMS. `07` có biến lọc đầu file; `05` dùng ngưỡng tạm thời 18 giờ quan sát trên 24, không phải quy chuẩn. Điều chỉnh ngưỡng tùy mục đích và công bố số mẫu.

- `01`: theo ngày local; `Samples` là phép đo, `HoursObserved` là giờ phân biệt.
- `02`: roll-up tháng/quý, trung bình theo mọi phép đo, không bình quân các trung bình ngày.
- `03`: giờ local; có số mẫu và ngày có đo.
- `04`: ghép hai trạm theo cùng ngày, giờ local và chất; trung bình từng trạm/giờ trước ghép nếu nhiều sensor.
- `05`: top ngày theo trạm/chất với số giờ tối thiểu.
- `06`: đủ tháng nhờ lịch x trạm x chất, đếm giờ phân biệt; giờ thiếu không phải nồng độ 0.
- `07`: lọc nhiều chiều, truy về SourceId và BatchId.
- `08`: bảng xoay hai cột chất, mỗi chất có số mẫu riêng; không cộng nồng độ.

Không coi dữ liệu quan trắc không liên tục là đại diện toàn năm hoặc toàn Hà Nội. Không cộng PM2.5 và PM10. Không suy kết luận quy chuẩn từ những giá trị này.
