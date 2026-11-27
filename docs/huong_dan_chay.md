# Hướng dẫn chạy và bàn giao

Cập nhật 28/11/2026. Chạy từ thư mục gốc dự án. Bộ nguồn chốt có 23.036 dòng; kho chỉ lấy 11.500 phép đo PM2.5/PM10. Các số mong đợi bên dưới áp dụng cho bản nguồn có checksum hiện tại.

## 1. Công cụ và cấu hình

Chuẩn bị SQL Server Database Engine, SSMS hoặc sqlcmd, Visual Studio với Integration Services Projects, driver OLE DB tương thích và Power BI Desktop hỗ trợ PBIP/PBIR. SSIS Projects 2.2 đã được dùng trong dự án; xem `docs/moi_truong.md` cho lịch sử phiên bản. SSAS Multidimensional và Analysis Services Projects chỉ cần khi trình diễn cube. Python phục vụ kiểm tra nguồn, không thay thế SSIS.

Trong SSMS kết nối instance của máy, chạy `SELECT @@VERSION; SELECT 1 AS KetNoi;`. Trong Visual Studio mở `etl/HanoiAirETL/HanoiAirETL.slnx`, kiểm tra TargetServerVersion và Test Connection của hai Connection Manager. Dùng Windows Authentication khi phù hợp. Không đưa tên máy, mật khẩu hoặc cấu hình cá nhân vào Git.

`Project.params` hiện rỗng. Phải mở Connection Manager để sửa server/database; chưa có tham số project có thể nhập một lần cho mọi kết nối. Cấu hình nguồn là `hanoi_air_vn`, kho là `hanoi_air_dw`. Không coi việc cài extension hoặc đăng ký MCP là đã kết nối dữ liệu.

## 2. Nguồn và cấu trúc kho

Clone hoặc sao chép bộ dự án sang thư mục khác để thử bàn giao; kiểm tra có `data/raw`, `data/source`, `data/checksums.sha256`, `sql/source` và các project. Giữ nguyên nguồn. Chạy `python tools/doi_soat_nguon.py` sau khi đọc tham số hỗ trợ của script; không tải lại hoặc sinh lại nguồn chỉ để mở báo cáo.

Trong SSMS mở `sql/source/hanoi_air_quality_vn_monitoring_real.sql`, đọc database đích ở đầu file rồi Execute. Script tạo `hanoi_air_vn` nếu chưa có và nạp bảng `dbo.air_quality_hourly`; chạy lại chỉ thêm khóa còn thiếu, dữ liệu cùng khóa khác payload làm lỗi. Không import CSV thêm lần nữa. Kỳ vọng 23.036 dòng, trong đó PM có 11.500.

Mở lần lượt `sql/schema/01_tao_kho.sql`, `02_tao_staging.sql`, `03_tao_dimensions.sql`, `04_tao_fact.sql`, `05_nap_lich.sql`, `06_tao_views_buoc14.sql`. Kỳ vọng năm dimension, một fact, ba bảng hỗ trợ, lịch 366 ngày và 24 giờ. Có thể dùng `00_chay_buoc6_ssms.sql` thay cho 01–05, sau đó chạy riêng 06; không chạy cả hai cách đồng thời.

Các file có `USE` và tên database cố định. `sqlcmd -d ten_kho_thu` không đổi được đích bên trong file. Muốn thử tên database khác, chuẩn bị bản sao script, rà toàn bộ tham chiếu và guard database trước khi thực thi; không sửa tên bằng thay thế mù hoặc xóa kho thật. Thử tái lập lịch sử đã dùng kho riêng và chỉ chứng minh nhánh T-SQL.

Khi thực hành ghép CSV và sinh SQL mới, thứ tự dòng có thể đổi nên các IDENTITY nguồn có thể khác `SourceId` đang được fact tham chiếu. Không thay bảng nguồn bên dưới một kho đang tồn tại bằng bản sinh mới. Dùng SQL nguồn đã chốt khi dựng dự án; nếu thử nguồn được sinh lại thì cô lập cả database nguồn và database kho, rồi đối soát lineage từ đầu.

Ví dụ dòng lệnh tương đương, nếu không dùng giao diện:

```powershell
$dwServer = 'localhost' # thay bằng instance của máy
sqlcmd -S $dwServer -E -C -b -f 65001 -i sql/source/hanoi_air_quality_vn_monitoring_real.sql
Get-ChildItem sql/schema/0[1-6]_*.sql | Sort-Object Name | ForEach-Object {
    sqlcmd -S $dwServer -E -C -b -f 65001 -i $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "DDL thất bại: $($_.Name)" }
}
```

`-C` tin cậy chứng chỉ server trong môi trường thử cục bộ; cấu hình chứng chỉ theo môi trường khi triển khai khác.

## 3. Procedure và ETL

Mở và Execute theo thứ tự `sql/etl/01_chuan_hoa.sql`, `02_nap_kho.sql`, `03_ssis_staging.sql`. Cách kiểm chứng T-SQL độc lập:

```sql
USE hanoi_air_dw;
DECLARE @BatchId uniqueidentifier;
EXEC etl.usp_RunBatch @BatchId OUTPUT;
SELECT @BatchId AS BatchId;
SELECT TOP (5) * FROM etl.BatchLog ORDER BY StartedAtUTC DESC;
SELECT COUNT_BIG(*) AS FactRows FROM dbo.FactAirQuality;
```

Kho mới: lần đầu 11.500 mới; lần hai 0 mới/11.500 đã có; fact giữ 11.500. Batch Success phải cân đối số dòng. Nếu nguồn đổi, đọc log thực tế thay vì áp số chốt. Không gọi các procedure con nạp fact ngoài transaction/application lock của điều phối.

Trong Visual Studio mở `00_RunAll.dtsx`; kiểm tra `CN_Nguon`, `CN_Kho` và ánh xạ BatchId. StartBatch trả cột 0 vào biến String `User::BatchId`; Derived Column chuyển thành DT_GUID; các Execute SQL Task truyền VARCHAR(36), Parameter Name 0. Luồng thành công là StartBatch → Extract PM to Stage → ProcessStagedBatch; nhánh đỏ từ Data Flow gọi FailStagedBatch. Hướng dẫn từng ô nằm trong `docs/huong_dan_buoc_9_ssis.md`.

Nhấn Start, xem Progress và Data Flow 11.500 dòng; sau đó kiểm tra BatchLog trong SSMS. Nhấn Shift+F5 kết thúc debug rồi chạy lần hai. Package trên kho đã có dữ liệu kỳ vọng 0 mới và 11.500 đã có. Không chạy package đồng thời: lock hiện chỉ bảo vệ giai đoạn xử lý staging. Crash có thể để batch Running; xác minh batch không còn chạy trước khi xử lý riêng, không xóa lịch sử. Test package SSIS trỏ kho trống khác và tham số hóa đầy đủ chưa được xác nhận; không gọi đó là tái lập SSIS hoàn chỉnh.

## 4. Kiểm tra và OLAP

Trong SSMS chạy `sql/checks/kiem_tra_nguon.sql`, `kiem_tra_kho.sql`, `doi_soat_buoc10.sql`, `doi_soat_buoc14.sql`. Kỳ vọng 0 trùng grain, 0 khóa ngoại mồ côi, UTC/local/DateKey đúng và 2.098 giờ chung mỗi chất. Bộ thử ràng buộc bước 6 yêu cầu kho trống; không chạy trên kho đã nạp.

Chạy tám file `sql/olap/01_trung_binh_ngay.sql` đến `08_pivot.sql`. Trung bình toàn bộ PM2.5 khoảng 38,74945556; PM10 khoảng 63,82399583 µg/m³. Luôn đọc số mẫu cùng trung bình. Nồng độ không được SUM qua thời gian hoặc trộn hai chất.

SSAS là nhánh phân tích bổ sung. Mở `olap/HanoiAirCubeImported/HanoiAirCubeImported.dwproj`; đây là project hoàn chỉnh, còn `HanoiAirCube` cũ chỉ là khung. Cấu hình Data Source và quyền SELECT tối thiểu theo `olap/cap_quyen_doc_ssas.sql`, kiểm tra đích trước Deploy/Process. Cube `Air Quality` có 5 chiều. Ba file `olap/01_chat.mdx`–`03_thang_chat.mdx` đối chiếu SQL; build lịch sử còn một cảnh báo provider. Power BI lấy trực tiếp SQL, không lấy dữ liệu từ cube.

## 5. Power BI và demo

Mở `dashboard/HanoiAirOLAP.pbip` làm bản làm việc. Trong Data source settings sửa SQL server khi cần, kiểm tra 7 bảng Import và 8 quan hệ; Refresh. `StationPairHourly` phải lấy từ view kho. PBIX `dashboard/khong_khi_ha_noi.pbix` là bản nhị phân; tránh chỉnh đồng thời PBIX và PBIP. Lưu trong Desktop sau khi kiểm tra để đồng bộ bản nhị phân nếu cần.

Ba trang: Tổng quan, Xu hướng, So sánh–tra cứu. Kiểm tra bỏ chọn chất trả BLANK cho trung bình chung; tháng 8/2024 không biến thành nồng độ 0; chọn cùng ngày/chất thì so sánh giờ chung khớp SQL. Cả năm: PM2.5 cặp 42,88 và 32,47, lệch 10,42; PM10 cặp 74,40 và 43,66, lệch 30,73 µg/m³, mỗi chất 2.098 giờ. Dung sai FLOAT tuyệt đối 0,000001 trước làm tròn.

Giữ SSMS, Visual Studio và Power BI đang mở ở kết quả liên quan sau demo. Ghi rõ kiểm tra nào chạy bằng giao diện, MCP hoặc dòng lệnh; không coi ảnh lịch sử là lượt chạy mới. Xem `report/kich_ban_demo.md` và `report/kiem_tra_buoc_1_den_15.md`.
