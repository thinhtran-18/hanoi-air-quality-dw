# Hướng dẫn làm việc và trạng thái dự án

Cập nhật gần nhất: **27/11/2026**. Bước 9 đã chạy SSIS thành công hai lần và đối soát fact; còn kiểm tra tham số kết nối và xử lý batch cũ Running. Xem `docs/huong_dan_buoc_9_ssis.md`.

## 1. Mục tiêu và phạm vi

Dự án đồ án kho dữ liệu phục vụ phân tích đa chiều nồng độ **PM2.5 và PM10 tại hai trạm Hàng Đậu và Khương Trung ở Hà Nội trong năm 2024**. Mục tiêu là xây dựng quy trình có thể kiểm chứng từ dữ liệu nguồn đến kho, ETL, truy vấn OLAP và dashboard Power BI.

- Nguồn: dữ liệu lịch sử OpenAQ; giữ dữ liệu gốc và minh chứng đối soát.
- Bản nguồn hiện tại: **325 tệp gốc, 23.036 phép đo**; phạm vi hai chất bụi có **11.500 phép đo**, 2 trạm, 4 cảm biến. Nguồn còn có CO và NO2, không thuộc phạm vi phân tích chính.
- Phạm vi năm được xác định theo giờ Việt Nam **UTC+07:00**.
- Dữ liệu không liên tục: độ phủ theo từng trạm/chất khoảng **28–37%** số giờ năm 2024. Hai mã địa điểm nguồn không còn cập nhật gần đây theo đối soát đã ghi nhận; không suy ra tình trạng hoạt động của trạm vật lý.
- Số lượng trên là mốc đã kiểm chứng của bộ nguồn hiện tại, không phải số fact đã nạp. Khi nguồn đổi, phải chạy lại đối soát và cập nhật các mốc liên quan.

## 2. Công nghệ và vai trò

| Thành phần | Vai trò / trạng thái |
| --- | --- |
| SQL Server, T-SQL | Nguồn đã đối soát; kho Star đã nạp 11.500 fact; nạp lại không tăng số dòng |
| SSMS / sqlcmd | Thực thi script và kiểm tra dữ liệu, ràng buộc, kết quả ETL |
| Visual Studio / SSIS | SSIS Projects 2.2 đã cài; package ETL chạy thành công hai lần, còn giới hạn và minh chứng như hướng dẫn bước 9 |
| Analysis Services / OLAP | Hướng triển khai phân tích đa chiều; chưa dựng mô hình/cube |
| Power BI Desktop | Mô hình phân tích, measure và dashboard; chưa triển khai |
| Python / Pillow | Công cụ đối soát, tạo tài liệu và sơ đồ; các script vẽ hiện dùng Arial trên Windows |
| draw.io / PNG | Sơ đồ chỉnh sửa được và bản hình đưa vào báo cáo |
| Git / GitHub | Quản lý phiên bản mã nguồn, tài liệu và minh chứng đã rà soát |

Không mặc định công cụ đã hoạt động chỉ vì đã cài hoặc thấy mẫu project. Chỉ ghi đã kiểm tra khi có kết quả thực tế; không ghi thông tin riêng của máy phát triển vào tài liệu công khai.

## 3. Các quyết định kỹ thuật đã chốt

- Vẽ đủ **Star, Snowflake và Galaxy** theo yêu cầu giảng viên. **Chỉ chọn Star làm mô hình triển khai chính**; hai mô hình còn lại là phương án thiết kế, so sánh và mở rộng.
- Star có `dbo.FactAirQuality` và 5 chiều: `DimDate`, `DimTime`, `DimStation`, `DimPollutant`, `DimSensor`; 6 bảng, 40 cột theo từ điển hiện tại.
- **Grain:** một phép đo của một chất, tại một trạm, một cảm biến, một thời điểm chính xác. Không gộp cảm biến hoặc cắt timestamp về giờ để tạo khóa phép đo.
- **Khóa chống trùng:** `UNIQUE (StationKey, SensorKey, ObservedAtUTC, PollutantKey)`. Khóa kỹ thuật dòng fact không thay thế khóa này; không đưa Value hoặc BatchId vào khóa chống trùng.
- Giữ `ObservedAtSource` có offset; chuyển sang UTC để nhận diện thời điểm; `ObservedAtLocal` luôn UTC+07. **DateKey/TimeKey lấy từ local**, không lấy từ UTC.
- Lịch dự kiến đủ 366 ngày năm 2024 và 24 mốc đầu giờ. Không tự tạo phép đo cho giờ thiếu. Nếu có phút/giây hoặc độ chính xác thời gian mới, điều chỉnh thiết kế trước khi nạp.
- Dimension mô tả dùng **SCD Type 1**, có nguồn xác minh và nhật ký cập nhật; không suy đoán metadata còn thiếu.
- Mỗi dimension nối trực tiếp 1–n vào fact; Power BI lọc một chiều từ dimension vào fact. Không thêm quan hệ Station–Sensor hoặc Sensor–Pollutant gây đường lọc bổ sung.
- `SourceId` truy về id bảng SQL nguồn; CSV không có id này. `BatchId` truy về lần chạy ETL. Không lấy số dòng CSV thay ID nguồn.
- Cùng grain và cùng payload: nạp một lần. Cùng grain nhưng khác giá trị/metadata: ghi nhận xung đột để đối soát, không tự ghi đè hoặc chọn ngẫu nhiên.
- `IsValid` phản ánh quy tắc kỹ thuật đã chốt, không chứng nhận hiệu chuẩn. Không tự loại giá trị cao nếu chưa có căn cứ.
- Snowflake tách thêm `DimCity` và `DimUnit`. Galaxy thêm `FactCoverageDaily` có grain ngày local–trạm–chất, dùng chung 3 chiều với fact phép đo. Không đưa các bảng phương án này vào kho chính khi chưa có thay đổi phạm vi được thống nhất.

## 4. Quy tắc diễn giải dữ liệu

- **Giờ thiếu không phải nồng độ 0**; không điền 0 vào giá trị đo để lấp thiếu.
- Không cộng PM2.5 và PM10 thành tổng nồng độ; không SUM nồng độ theo thời gian. Tính trung bình/cực trị theo chất, đơn vị và phạm vi rõ ràng, công bố số mẫu.
- Độ phủ đếm giờ phân biệt theo trạm–chất, không lấy số dòng phép đo thay số giờ. So sánh hai trạm cần cùng chất và tập giờ ghép cặp.
- Một giờ có nhiều dòng vẫn hợp lệ khi khác trạm, cảm biến, chất hoặc thời điểm chính xác. Chỉ xác định trùng theo đầy đủ grain.
- Không mặc định mẫu hiện có đại diện cả năm hoặc toàn Hà Nội. Không suy nguyên nhân ô nhiễm khi thiếu dữ liệu hỗ trợ.
- Không gọi nồng độ là AQI hoặc kết luận vượt chuẩn khi chưa chốt phương pháp, nguồn ngưỡng và chu kỳ trung bình phù hợp.

## 5. Tiến độ và công việc tiếp theo

| Bước | Trạng thái | Kết quả / việc còn lại |
| --- | --- | --- |
| 1–3: phạm vi, môi trường, đối soát nguồn | Hoàn thành | Có tài liệu phạm vi, môi trường, nguồn và checksum |
| 4: nạp nguồn và khảo sát chất lượng | Hoàn thành | SQL/CSV khớp 23.036 dòng; 11.500 dòng bụi, không trùng grain; đã ghi nhận khoảng thiếu |
| 5: thiết kế mô hình | Hoàn thành, gồm yêu cầu bổ sung | Đủ 3 sơ đồ draw.io/PNG, từ điển, so sánh và quyết định chọn Star |
| 6: triển khai cấu trúc kho | Đã triển khai; còn thiếu bằng chứng bàn giao | 40/40 cột, lịch 366/24 và ràng buộc đã kiểm tra; chưa xác nhận lại dựng kho trống độc lập; hai ảnh SSMS được báo cáo dẫn đến chưa có trong repo |
| 7: chuẩn hóa staging | Đã triển khai và kiểm thử theo phạm vi hiện tại | Batch 11.500 accepted; thử lỗi/trùng/xung đột rollback; giới hạn khóa batch và nhật ký lỗi trong `report/cac_phan/04_chuan_hoa_staging.md` |
| 8: logic nạp | Đã triển khai và kiểm chứng hai lần qua sqlcmd | 11.500 fact; chạy lại 0 mới; còn các giới hạn về test SSMS, metadata Type 1 và chi tiết xung đột trong báo cáo |
| 9: SSIS | Luồng chính đã kiểm chứng; còn việc bàn giao | Hai batch Success: mỗi batch trích 11.500, 0 mới, 11.500 đã có; fact 11.500. Đã có ảnh cấu hình; còn kiểm tra tham số kết nối và batch Running cũ; xem hướng dẫn bước 9 |
| 10: Kiểm thử ETL và kho | Đang thực hiện | Đã đối soát nguồn/kho và chạy các ca trùng, xung đột, thiếu dimension, thời gian trong SSMS; xem `report/minh_chung/ket_qua_etl.csv`. Chưa chạy SSIS trên kho trống độc lập và chưa giả lập lỗi giữa luồng hoàn chỉnh. |
| ETL | T-SQL và package SSIS đã chạy | Nguồn → staging → dimension/fact; có nhánh lỗi và log, còn giới hạn vận hành được ghi trong hướng dẫn bước 9 |
| OLAP / Power BI / báo cáo tổng hợp | Chưa thực hiện | Triển khai sau khi kho và ETL đã kiểm chứng |

Môi trường SSIS đã sửa: gỡ Analysis Services Projects 4.0.0 bằng VSIX Installer vì gói Repair có URI rỗng; Visual Studio chuyển `isComplete=True`; SSIS 2.2 cài thành công, tạo được project và mở package designer. Package ETL đã chạy thành công hai lần. Analysis Services đã gỡ, cần cài lại nếu dùng cube SSAS. Không tự sửa/xóa thành phần dùng chung của môi trường phát triển.

Bước 6: `sql/schema/01`–`05` đã chạy trong SSMS và chạy lại không trùng lịch. Ba bảng hỗ trợ không đổi 6 bảng/40 cột Star; FK BatchId → etl.BatchLog chỉ phục vụ lineage. Staging giữ `datetimeoffset(7)` để phát hiện phần giây trước khi nạp fact `(0)`. IDENTITY có thể có khoảng trống do kiểm thử. Chi tiết: `report/cac_phan/03_trien_khai_cau_truc_kho.md`.

Database Diagram `Star_Buoc6` được lưu trong kho. `dbo.sysdiagrams` do SSMS tạo để lưu sơ đồ, không tính vào 9 bảng nghiệp vụ/hỗ trợ hay các mốc PK/UQ. Script tổng hợp `sql/schema/00_chay_buoc6_ssms.sql` sinh bằng `tools/tao_script_buoc6_ssms.py`. Kế hoạch OLAP ưu tiên SQL/Power BI; cube SSAS/MDX chỉ bổ sung khi yêu cầu giảng viên được xác nhận.

Bước 7: `sql/etl/01_chuan_hoa.sql` cài view/procedure, đã trích xuất 11.500 dòng và phân loại; `sql/checks/kiem_thu_buoc7.sql` kiểm thử với rollback. Batch thử bước 7 giữ Running; batch nạp bước 8 có log riêng. Không sửa staging sau phân loại. `ReviewHigh` >=150 là ngưỡng sàng lọc tạm thời không phải quy chuẩn.

Bước 8: chạy `etl.usp_RunBatch` theo `sql/etl/README.md`; lần đầu 11.500 mới, lần hai 0 mới/11.500 đã có. Khóa application lock và transaction, kiểm tra xung đột, thử Failed khi khóa bận. Giữ staging của batch nạp để đối soát payload; không xóa/sửa khi chưa có cơ chế lineage thay thế. Chi tiết và các test còn thiếu: `report/cac_phan/05_nap_kho.md`.

Bổ sung bước 8 cho SSIS: `sql/etl/03_ssis_staging.sql` tạo procedure nhận staging đã nạp, không tự trích xuất; nạp dimension/fact trong một transaction và application lock. Đã thử mô phỏng trong SSMS: 11.500 staging, Success, 0 mới/11.500 đã có; thử xung đột Failed và ghi lỗi Data Flow; fact vẫn 11.500. Đã test mapping BatchId, Data Flow và nhánh lỗi trong package SSIS; khóa không bao trùm Data Flow. Không chạy đồng thời package hoặc sửa staging bằng tay. Xem `sql/etl/README.md`.

Bước 9: package SSIS đã chạy thành công hai lần; 11.500 dòng staging mỗi lần, 0 fact mới và 11.500 fact đã có. Đã có ảnh Control Flow, Data Flow và ánh xạ BatchId; còn batch cũ Running và chưa tham số hóa kết nối trong Project.params. Xem `report/cac_phan/06_ssis_buoc9.md`.

## 6. Tài liệu và cách kiểm tra

- Đọc `README.md`, `docs/pham_vi.md` trước khi thay đổi phạm vi.
- Thiết kế triển khai chính: `docs/thiet_ke/thiet_ke_star_schema.md`, `docs/thiet_ke/tu_dien_du_lieu.md`.
- Ba phương án và lý do chọn: `docs/thiet_ke/so_sanh_ba_luoc_do.md`.
- Báo cáo bước 4–5: `report/cac_phan/01_du_lieu.md`, `report/cac_phan/02_thiet_ke_kho.md`; minh chứng tại `report/minh_chung/`.
- DDL/cách chạy: `sql/schema/README.md`; bước 6: `report/cac_phan/03_trien_khai_cau_truc_kho.md`. `python tools/kiem_tra_buoc6.py` đối chiếu metadata/mốc kho trống; `--write` ghi JSON/PNG, `--test-constraints` chỉ dùng trước ETL, chạy dữ liệu thử trong transaction rồi rollback.
- `python tools/tao_thiet_ke_buoc5.py`: tạo lại sơ đồ/từ điển Star và kiểm tra CSV. Lệnh ghi lại các sản phẩm sinh tự động; đọc script trước khi chạy nếu các sản phẩm đã được chỉnh tay.
- `python tools/tao_luoc_do_bo_sung.py`: tạo lại Snowflake/Galaxy, từ điển và minh chứng độ phủ thử. Không tạo bảng SQL.
- Truy vấn kiểm tra tại `sql/checks/`; kết nối dùng cấu hình cục bộ, không hard-code tài khoản hay mật khẩu. Chỉ chạy các script tạo/nạp kho sau khi đã đọc nội dung và xác định đúng database đích.
- Giữ nguồn gốc để tái lập; không sửa tệp dữ liệu gốc để làm khớp kết quả. Đối soát số thực theo dung sai đã ghi ở báo cáo bước 4.
- Kiểm tra phù hợp từng thay đổi: cấu trúc/grain, số dòng, tính duy nhất, tham chiếu, thời gian, nạp lại và đối soát. Với sơ đồ, kiểm tra cả cấu trúc lẫn ảnh kết xuất. Không ghi một kiểm tra là đạt nếu chưa chạy.

## 7. Cập nhật file này sau từng bước

Đây là hồ sơ trạng thái duy trì trong repo. Khi thực hiện công việc ở bước tiếp theo, **cập nhật AGENTS.md trong cùng đợt thay đổi**:

1. Đổi ngày cập nhật, bước vừa hoàn thành và bảng tiến độ theo kết quả đã kiểm chứng.
2. Ghi ngắn gọn quyết định kỹ thuật mới, sản phẩm, kiểm tra đã chạy, giới hạn và vấn đề còn mở; dẫn đến báo cáo chi tiết thay vì chép toàn bộ log.
3. Phân biệt rõ **đã thiết kế**, **đã viết script**, **đã thực thi** và **đã kiểm chứng**. Chỉ đánh dấu hoàn thành khi đủ điều kiện của bước đó.
4. Cập nhật việc tiếp theo và các thay đổi phạm vi đã được thống nhất; bỏ thông tin trạng thái đã lỗi thời. Giữ README, thiết kế và báo cáo nhất quán.
5. Không tự đổi lựa chọn Star, grain hoặc cách xử lý dữ liệu chỉ để thuận tiện triển khai; nếu cần đổi, nêu lý do và cập nhật các đặc tả liên quan.

Quy tắc này áp dụng khi có công việc mới được thực hiện trong repo, không phải tác vụ tự chạy nền hoặc lịch cập nhật tự động.

## 8. Bảo vệ thông tin khi lưu và công khai

- File này chỉ chứa thông tin kỹ thuật cần thiết và dữ liệu quan trắc công khai. Không ghi tên/thông tin liên hệ thành viên, mã sinh viên, tài khoản cá nhân hoặc thông tin nội bộ không phục vụ mô tả công khai.
- Không đưa token, API key, mật khẩu, cookie, chuỗi kết nối chứa bí mật, khóa riêng, tên máy/instance riêng, IP nội bộ, đường dẫn tuyệt đối của máy hoặc bản sao hội thoại vào repo. Dùng đường dẫn tương đối, biến cấu hình và giá trị mẫu không chứa bí mật.
- Giữ cấu hình riêng trong file cục bộ được `.gitignore` loại trừ; `.env.example` chỉ chứa tên biến và giá trị mẫu. Không coi `.gitignore` là biện pháp bảo vệ file đã được Git theo dõi.
- Rà soát đúng các file chuẩn bị commit, kể cả ảnh, log, manifest và metadata tài liệu. Cắt/che phần nhận diện, thông tin kết nối hoặc dữ liệu riêng trước khi công khai; không chỉ kiểm tra văn bản AGENTS.md.
- Chỉ commit/push phần thuộc công việc đã được người dùng cho phép. Không ghi thông tin nhạy cảm để giải thích lỗi; mô tả lỗi ở mức thành phần và dẫn đến log cục bộ khi cần.
- Nếu phát hiện bí mật đã lộ, không chép lại vào báo cáo hay đầu ra. Báo loại thông tin và vị trí ở mức cần thiết; xử lý thu hồi/đổi bí mật và lịch sử Git theo thẩm quyền được cấp, không tự force-push hoặc xóa lịch sử.
