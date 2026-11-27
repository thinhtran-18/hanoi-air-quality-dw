# Bước 16 — Báo cáo tổng hợp và bàn giao

Ngày 28/11/2026. Sáu phần dưới đây tổng hợp kết quả từ sản phẩm và biên bản bước 1–15. Các con số áp dụng cho bộ nguồn chốt; kiểm tra trực tiếp lượt bàn giao được ghi riêng trong `report/kiem_tra_buoc_1_den_15.md`.

## 1. Bài toán và phạm vi

Thiết kế kho dữ liệu phục vụ phân tích đa chiều PM2.5/PM10 tại Hàng Đậu (2161299) và Khương Trung (2161301), Hà Nội, năm 2024 theo UTC+07. Câu hỏi chính là mức nồng độ theo ngày/tháng/giờ, số mẫu và độ phủ, khác biệt hai trạm trên cùng tập giờ và truy vết từng phép đo. Không chuyển nồng độ thành AQI hoặc kết luận nguyên nhân khi chưa có phương pháp và dữ liệu bổ sung.

## 2. Dữ liệu

OpenAQ phân phối bộ quan trắc lịch sử gồm 325 tệp nén gốc, CSV ghép và SQL nguồn; 327/327 tệp trong danh sách SHA-256 đã khớp tại bước 15. SQL nguồn chứa 23.036 phép đo của 4 chất; chỉ 11.500 PM2.5/PM10 thuộc kho chính. PM2.5 có 5.749 và PM10 có 5.751 phép đo, từ 4 cảm biến. Dữ liệu có từ 29/01 đến 11/12/2024, gián đoạn; tháng 8 không có dữ liệu. Hash kiểm chứng tính toàn vẹn byte, không chứng nhận hiệu chuẩn cảm biến. Minh chứng: `data/README.md`, biên bản nguồn và `report/minh_chung/buoc4_*`.

## 3. Thiết kế kho

Đã thiết kế Star, Snowflake và Galaxy; ba lược đồ dùng để vẽ và học so sánh, chỉ Star được yêu cầu triển khai SQL. Star có 6 bảng/40 cột: FactAirQuality và DimDate, DimTime, DimStation, DimPollutant, DimSensor. Grain một phép đo của một chất, một trạm, một cảm biến và thời điểm chính xác; UNIQUE trên StationKey, SensorKey, ObservedAtUTC, PollutantKey. Giữ timestamp có offset; UTC nhận diện thời điểm, local +07 tạo DateKey/TimeKey. Lịch đủ 366 ngày và 24 giờ; không sinh phép đo để lấp lịch. Khóa dimension dùng surrogate key; mô tả cập nhật SCD Type 1. Staging/log/reject là bảng hỗ trợ, không thay đổi số bảng Star. Sơ đồ và từ điển: `docs/thiet_ke/`.

## 4. ETL

Nguồn SQL → staging → phân loại → dimension → fact, kèm BatchLog và RejectRow. T-SQL dùng transaction/application lock, phát hiện trùng và xung đột; không tự ghi đè cùng grain khác payload. SSIS điều phối StartBatch, Data Flow thêm BatchId, ProcessStagedBatch và nhánh FailStagedBatch. Hai lần SSIS thành công trên kho đã có dữ liệu ghi 11.500 trích, 0 mới, 11.500 đã có. Tái lập T-SQL kho trống bước 15 cho 11.500 mới lần đầu và 0 mới lần hai. Chi tiết tại `sql/etl/README.md`, `docs/huong_dan_buoc_9_ssis.md`. Chưa có xác nhận package chạy trên kho trống khác với tham số hóa đầy đủ; Project.params rỗng, lock chưa bao Data Flow và crash có thể để Running.

## 5. Phân tích và dashboard

Tám truy vấn SQL OLAP và ba truy vấn MDX có kết quả đối chiếu. Cube SSAS Air Quality có 5 chiều; project hoàn chỉnh là HanoiAirCubeImported. Power BI Import trực tiếp từ kho, độc lập với cube, có 7 bảng, 8 quan hệ, 19 measures và 3 trang Tổng quan, Xu hướng, So sánh–tra cứu. Trung bình toàn tập quan sát PM2.5 là 38,75, PM10 là 63,82 µg/m³. Độ phủ năm theo trạm–chất chỉ 28,44–37,03% trên mẫu số 8.784 giờ. Trên 2.098 giờ chung mỗi chất: PM2.5 Hàng Đậu 42,88, Khương Trung 32,47, chênh 10,42; PM10 lần lượt 74,40, 43,66 và 30,73 µg/m³. Các số ghép cặp khác trung bình trên giờ riêng của từng trạm; không tráo hai khái niệm.

## 6. Đánh giá và hướng phát triển

Bước 15 lưu 17 ca đối soát trong `dashboard/doi_soat_chi_so.csv`, 13 ca ETL trong `report/minh_chung/ket_qua_etl.csv`; có phân biệt PASS lịch sử và PASS có giới hạn. Đối soát số đếm tuyệt đối, sai số FLOAT tối đa khoảng 10⁻¹³ µg/m³ so ngưỡng 0,000001. Đã sửa Số giờ thiếu trả kết quả trên tổ hợp trạm–cảm biến không tồn tại và kiểm tra lại đúng 4 nhóm cảm biến. Ca ranh ngày xác nhận DateKey theo +07. Tái lập T-SQL thành công không đồng nghĩa clone mới chạy SSIS/refresh mọi thành phần đã được kiểm chứng.

Hướng phát triển: tham số hóa server/database cho SSIS, kiểm thử package đầu-cuối trên kho thử, xử lý batch treo có kiểm soát, lưu chi tiết xung đột bền vững, chính sách lưu staging và nhật ký Type 1 khi metadata thay đổi. Cube còn 1 cảnh báo provider; schema PBIR mới từng thiếu định nghĩa công khai. Không tăng phạm vi sang AQI hoặc suy luận nguyên nhân chỉ để bổ sung biểu đồ.

Hồ sơ bàn giao đã tạo: `docs/huong_dan_chay.md`, `report/kiem_tra_buoc_1_den_15.md`, `report/kich_ban_demo.md`, Word `report/san_pham/Huong_dan_hoc_hieu_do_an_khong_khi_Ha_Noi.docx` (29 trang, 8 chặng, 42 câu vấn đáp) và PowerPoint `report/san_pham/Quy_trinh_do_an_khong_khi_Ha_Noi.pptx` (9 slide, đối tượng và biểu đồ chỉnh sửa được, có notes). Word đã cập nhật mục lục bằng Microsoft Word, xuất PDF nội bộ và xem toàn bộ 29 ảnh trang; PowerPoint đã mở trực tiếp, xuất và xem đủ 9 slide. Bộ render đóng gói thiếu LibreOffice, đã chẩn đoán log rồi dùng Microsoft Word có trên máy để kiểm tra, không cài công cụ thay thế.

Kiểm tra hiện tại xác nhận 327/327 checksum, 23.036 nguồn, 11.500 fact hợp lệ, 0 khóa mồ côi, 0 trùng grain và các số ghép cặp khớp SQL. Mô hình trực tiếp có 19 measure nghiệp vụ cùng một measure trống phụ. Đã sửa hướng dẫn công cụ cũ; giữ nguyên các tệp cá nhân/cache trên máy và bỏ theo dõi trong Git. Mốc mã đầu vào dùng đối chiếu là `6e0f74f5ff5c83e10fad745c3737777e8ee2d0f4`; sản phẩm bước 16 là thay đổi cục bộ sau mốc này, chưa có commit mới hoặc push.

Đã hoàn tất phần tài liệu và demo chuẩn bị của bước 16 trên máy hiện tại. Giới hạn tái lập SSIS trên kho trống khác và hai batch Running cũ được giữ nguyên để người học hiểu đúng khả năng đã kiểm chứng; không tuyên bố clone mới đã chạy toàn bộ hệ thống hoặc đạt rubric ngoài các yêu cầu đã đối chiếu.
