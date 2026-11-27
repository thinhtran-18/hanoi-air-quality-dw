# Bước 4 - Nạp nguồn và khảo sát chất lượng dữ liệu

Ngày kiểm tra: 27/11/2026. Phiên bản tệp đầu vào trong repo: commit `36514e16abea774bf8cb9a170422af8184f55b74`. SQL Server: `localhost`, cơ sở `hanoi_air_vn`, bảng `dbo.air_quality_hourly`.

## 1. Nguồn và phạm vi

Nguồn phân phối là kho OpenAQ trên AWS; provider được OpenAQ ghi nhận là Hanoi Air Quality Monitoring Network. Hai địa điểm lịch sử là Hàng Đậu `2161299` và Khương Trung `2161301`. Danh mục URL, file gốc, SHA-256 và ngày tải chưa xác định được ghi tại `data/source/nguon_du_lieu.csv` và `data/checksums.sha256`. Xem `data/README.md` và biên bản bước 3 để truy xuất nguồn.

Bảng SQL nguồn đã được nạp trước đó thông qua SSMS bằng `sql/source/hanoi_air_quality_vn_monitoring_real.sql`. Trong bước 4 chỉ đọc và kiểm tra, không nạp thêm CSV hoặc thay đổi bảng. Bảng lưu cả bốn chất CO, NO2, PM10 và PM2.5; phân tích chính của đề tài là hai chỉ tiêu bụi năm 2024. Một dòng là một phép đo của một cảm biến, tại một trạm, một thời điểm và một chất.

## 2. Kết quả đối soát và chất lượng

| Hạng mục | Kết quả |
| --- | ---: |
| Bản ghi trong SQL Server / CSV | 23.036 / 23.036 |
| Bản ghi PM2.5 và PM10 | 11.500 |
| Bản ghi SQL được đối chiếu đầy đủ với CSV | 23.036; khớp khóa, tên trạm, đơn vị, tọa độ và giá trị |
| Dòng trùng khóa trạm-cảm biến-thời điểm-chất | 0 |
| NULL trong các cột dữ liệu nguồn | 0 |
| Tên trạm, chất hoặc đơn vị là chuỗi rỗng | 0 |
| Giá trị đo âm | 0 |
| Offset khác UTC+07:00 / ngoài năm địa phương 2024 | 0 / 0 |
| Timestamp không ở đầu giờ | 0 |

Kiểu SQL của giá trị là `FLOAT(53)`. Khi so SQL với CSV, so khóa và chuỗi theo giá trị, số theo dung sai tuyệt đối `1e-10` hoặc tương đối `1e-14`; sai khác lớn nhất tính trên các số được xuất để kiểm tra là 0. So sánh này không chứng minh số thực lưu trong SQL hoàn toàn chính xác dạng thập phân tùy ý.

| Trạm | Chất | Cảm biến | Số đo | Nhỏ nhất | Lớn nhất | Trung bình các phép đo hiện có |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Hàng Đậu | PM2.5 | 7771996 | 3.251 | 4,3 | 171,0 | 43,26 |
| Hàng Đậu | PM10 | 7772005 | 3.253 | 4,8 | 428,6 | 79,01 |
| Khương Trung | PM2.5 | 7772073 | 2.498 | 2,2 | 134,9 | 32,88 |
| Khương Trung | PM10 | 7772039 | 2.498 | 2,7 | 160,8 | 44,04 |

Đơn vị: µg/m³. Trung bình được tính trên các phép đo hiện có của từng trạm/chất, không đại diện mặc định cho cả năm và không dùng để kết luận trạm này ô nhiễm hơn trạm kia vì khoảng thời gian đo khác nhau. Giá trị cao nhất PM10 428,6 tại Hàng Đậu là **giá trị cần xem xét**, chưa đủ căn cứ kết luận sai hoặc vượt quy chuẩn. Danh sách 10 giá trị cao nhất cho mỗi chất nằm trong `report/minh_chung/buoc4_gia_tri_cao_nhat.csv`; danh sách này là ưu tiên kiểm tra, không phải kết quả xác nhận bất thường.

## 3. Giờ có dữ liệu và khoảng thiếu

Quy ước mẫu số: **8.784 giờ cho cả năm 2024** ở mỗi tổ hợp trạm-chất, tính theo giờ Việt Nam UTC+07. Đây là phép so với lịch, không khẳng định trạm hoạt động hoặc bắt buộc phải có dữ liệu cả năm. Một giờ được tính là có dữ liệu nếu có ít nhất một phép đo đúng trạm/chất, đơn vị µg/m³, giá trị không NULL và không âm trong giờ đó. Các cảm biến cùng trạm/chất/giờ nếu có chỉ được đếm một giờ. Không tự coi giờ thiếu là giá trị 0.

| Trạm | Chất | Giờ có đo | Giờ không có đo trong bộ nguồn | Tỷ lệ so với 8.784 giờ |
| --- | --- | ---: | ---: | ---: |
| Hàng Đậu | PM2.5 | 3.251 | 5.533 | 37,01% |
| Hàng Đậu | PM10 | 3.253 | 5.531 | 37,03% |
| Khương Trung | PM2.5 | 2.498 | 6.286 | 28,44% |
| Khương Trung | PM10 | 2.498 | 6.286 | 28,44% |

Hàng Đậu không có phép đo bụi trong tháng 8 và tháng 12 trong bộ này. Khương Trung không có phép đo bụi trong các tháng 5, 6, 7 và 8. Các khoảng thiếu dài nhất, bao gồm biên năm: Khương Trung từ 05/04 01:00 đến 26/09 21:00, tổng 4.197 giờ cho mỗi chất bụi; Hàng Đậu từ 01/07 12:00 đến 28/09 09:00, tổng 2.134 giờ cho mỗi chất bụi. Đây là **không có quan sát trong bộ dữ liệu**, không xác định được trạm hay cảm biến thực tế có hoạt động hay không.

Số giờ hai trạm cùng có dữ liệu hợp lệ là **2.098 giờ PM2.5 và 2.098 giờ PM10**. Khi so sánh hai trạm cần chọn cùng chất, cùng tập giờ ghép cặp và công bố số giờ; cách này không tự khắc phục được thiên lệch do các khoảng thời gian thiếu.

## 4. Quy tắc đề xuất cho staging/kho

1. Giữ nguyên bảng nguồn và bản CSV gốc; nạp vào staging kèm khóa nguồn, cảm biến, timestamp có offset và chỉ tiêu.
2. Kiểm tra NULL/rỗng, định dạng, khóa trùng, đơn vị và giá trị âm; ghi nhận bản ghi vi phạm và lý do. Bộ hiện tại không có NULL, số âm hoặc trùng khóa theo các phép kiểm đã chạy.
3. Giữ giá trị cao để đối chiếu với nguồn và metadata cảm biến; chỉ loại nếu có căn cứ và lưu nhật ký quyết định. Không tự thay hay xóa số đo cực trị.
4. Chuyển giờ phân tích sang UTC+07:00 có quy tắc; lưu thêm thời gian gốc/UTC nếu cần. Tạo chiều thời gian đủ để thể hiện thiếu dữ liệu; không điền 0 cho giờ không có phép đo.
5. Mọi tính toán trung bình, so sánh hoặc độ phủ phải ghi chất, đơn vị, phạm vi, số mẫu và quy tắc xử lý. Không tính AQI hoặc kết luận vượt chuẩn khi chưa chốt phương pháp và chu kỳ trung bình tương ứng.

## 5. Minh chứng, tái lập và giới hạn

- `sql/checks/kiem_tra_nguon.sql`: truy vấn kiểm tra SQL Server, bao gồm bảng tạm lịch 8.784 giờ, thống kê theo trạm/chất/cảm biến/tháng, NULL, đơn vị, cực trị, độ phủ và khoảng thiếu. Không thay đổi bảng nguồn.
- `report/minh_chung/buoc4_thong_ke_tram_chat.csv`: thống kê theo trạm/chất; `buoc4_theo_cam_bien_thang.csv`: 72 nhóm có quan sát.
- `report/minh_chung/buoc4_do_phu_theo_thang.csv`: đủ 48 nhóm trạm/chất/tháng, kể cả tháng không có dữ liệu; `buoc4_khoang_gio_thieu.csv`: các khoảng thiếu liên tiếp.
- `report/minh_chung/buoc4_gia_tri_cao_nhat.csv` và `buoc4_ket_qua_kiem_tra.json`: danh sách giá trị cần xem xét và tóm tắt đối soát.
- Truy vấn SQL chạy thành công: 12 tập kết quả. Các số độ phủ năm, 48 nhóm tháng và số giờ ghép cặp được đối chiếu với phép tính độc lập từ CSV; kết quả khớp. Các file CSV thống kê được tạo từ CSV nguồn và đã so với SQL; chúng không được tự động tạo lại bởi file SQL.
- Chưa xác minh từng phép đo với trạm vật lý hay xác nhận chất lượng hiệu chuẩn cảm biến. Bộ dữ liệu không đủ bao phủ cả năm, không dùng làm bằng chứng đại diện toàn bộ Hà Nội hoặc kết luận nguyên nhân ô nhiễm.
