# Bước 9: Hướng dẫn đóng gói ETL bằng SSIS

Tài liệu hướng dẫn làm lại package bằng giao diện Visual Studio và kiểm tra bằng SSMS. Với project đã hoàn thiện một phần, chỉ kiểm tra hoặc thực hiện mục còn thiếu; không tạo thêm bản sao task khi đã có sẵn.

## 1. Vai trò từng phần

| Thành phần | Vai trò |
|---|---|
| SQL Server nguồn `hanoi_air_vn` | Chứa bảng `dbo.air_quality_hourly` đã đối soát với nguồn. |
| SQL Server kho `hanoi_air_dw` | Chứa staging, nhật ký batch, dimension và fact. |
| Connection Manager | Lưu cấu hình kết nối nguồn và kho; dùng Windows Authentication khi phù hợp. |
| `User::BatchId` | Giữ mã duy nhất của lần chạy, giúp truy vết từng dòng staging về batch. |
| Control Flow | Điều khiển thứ tự task và nhánh khi xảy ra lỗi. |
| `StartBatch` | Tạo batch `Running` và trả mã cho biến SSIS. |
| Data Flow `Extract PM to Stage` | Đọc dữ liệu PM từ nguồn, thêm mã batch, ghi vào staging. |
| `ProcessStagedBatch` | Trong một transaction: phân loại staging, nạp dimension và fact, hoàn thành batch; nếu lỗi thì rollback và ghi `Failed`. |
| `FailStagedBatch` | Ghi `Failed` khi Data Flow thất bại sau khi đã có BatchId. |
| `etl.BatchLog` | Ghi tình trạng và số dòng từng batch để đối chiếu. |

`ProcessStagedBatch` gọi các procedure con trong cùng transaction và application lock. Không nối trực tiếp `usp_ValidateStage` cũ sau Data Flow: procedure cũ tự trích xuất nguồn, và các procedure nạp con yêu cầu transaction/lock do procedure điều phối quản lý.

## 2. Chuẩn bị

1. Mở SSMS, kết nối SQL Server có hai database `hanoi_air_vn` và `hanoi_air_dw`. Bước 6–8 cần được cài trước.
2. Trong SSMS chọn **File → Open → File**, mở lần lượt `sql/etl/01_chuan_hoa.sql`, `02_nap_kho.sql` và `03_ssis_staging.sql` nếu chưa cài. Kiểm tra đúng máy và nội dung, sau đó nhấn **Execute** theo đúng thứ tự. Nếu đã cài thì không cần chạy lại chỉ để xem hướng dẫn này.
3. Mở Visual Studio có extension SQL Server Integration Services Projects. Không chạy đồng thời hai package ETL hoặc tự sửa staging trong khi ETL đang chạy: khóa hiện tại chỉ bảo vệ giai đoạn xử lý staging.
4. Nguồn là dữ liệu lịch sử không liên tục. Thiếu giờ không phải giá trị 0 và không suy ra dữ liệu đại diện cả năm.

## 3. Tạo project và package

1. Visual Studio → **Create a new project** → tìm **Integration Services Project** → **Next**.
2. Đặt tên project `HanoiAirETL`, chọn thư mục `etl` của repo → **Create**. Với project đã có, chọn **Open a project or solution** và mở solution hiện hữu.
3. Trong **Solution Explorer → SSIS Packages**, nhấp phải `Package.dtsx` → **Rename** → `00_RunAll.dtsx`. Mở package bằng cách nhấp đúp.
4. Chọn **File → Save All**. Hai tab chính là **Control Flow** và **Data Flow**.

## 4. Tạo kết nối

1. Ở đáy màn hình package, trong vùng **Connection Managers**, nhấp phải vùng trống → **New OLE DB Connection** → **New**.
2. Chọn OLE DB provider cho SQL Server có trên máy; nhập server/instance đang dùng; chọn **Windows Authentication**; chọn database nguồn `hanoi_air_vn`.
3. Nhấn **Test Connection**; khi thành công nhấn **OK**. Nhấp phải connection mới → **Rename** thành `CN_Nguon`.
4. Lặp lại, chọn database `hanoi_air_dw`, kiểm tra kết nối và đổi tên `CN_Kho`.
5. Kiểm tra lại server và database trên máy của mình. Không lưu mật khẩu vào package hay đưa thông tin kết nối cá nhân lên GitHub. Cấu hình hiện tại dùng các connection manager cục bộ; chưa xác nhận đã tham số hóa server/database trong `Project.params`.

## 5. Tạo biến BatchId

1. Chọn **Control Flow** và nhấp vào vùng nền trống để chọn phạm vi package.
2. Nhấp phải nền → **Variables**; nếu menu này không hiện, tìm **Variables** trong menu **SSIS** khi designer đang được chọn.
3. Trong cửa sổ Variables nhấn biểu tượng **Add Variable**. Điền `Name = BatchId`, `Scope = 00_RunAll`, `Data type = String`; giá trị ban đầu để trống. Namespace là `User`, tên đầy đủ `User::BatchId`.

## 6. Tạo StartBatch

1. Trong **Control Flow**, kéo **Execute SQL Task** từ SSIS Toolbox vào nền → nhấp phải → **Rename** thành `StartBatch`.
2. Nhấp đúp task → **General**: `ResultSet = Single row`, `ConnectionType = OLE DB`, `Connection = CN_Kho`, `SQLSourceType = Direct input`.
3. Tại **SQLStatement**, nhập:

```sql
EXEC etl.usp_StartSSISBatch;
```

4. Chọn **Result Set** bên trái → **Add** → nhập `Result Name = 0` và chọn `Variable Name = User::BatchId` → **OK**. Số 0 là cột đầu tiên của result set OLE DB; không để `NewResultName`.

## 7. Tạo Data Flow đọc và ghi staging

### 7.1. Data Flow Task và nguồn

1. Tại **Control Flow**, kéo **Data Flow Task** vào nền, đổi tên `Extract PM to Stage`.
2. Nhấp `StartBatch`, kéo mũi tên xanh sang `Extract PM to Stage`: task sau chạy khi task trước thành công.
3. Nhấp đúp `Extract PM to Stage` để mở **Data Flow**. Kéo **OLE DB Source** vào nền, đổi tên `Doc du lieu PM tu nguon`.
4. Nhấp đúp nguồn: chọn `OLE DB connection manager = CN_Nguon`, `Data access mode = SQL command`, rồi nhập:

```sql
SELECT id AS SourceId, location_id AS StationId, sensor_id AS SensorId,
       location_name AS StationName, observed_at AS ObservedAtSource,
       latitude AS Latitude, longitude AS Longitude,
       parameter AS PollutantCode, unit AS Unit, value AS Value
FROM dbo.air_quality_hourly
WHERE LOWER(LTRIM(RTRIM(parameter))) IN (N'pm25', N'pm10');
```

5. Chọn **Columns** để kiểm tra cột đầu ra → **OK**. Câu lệnh chỉ chọn hai chất, không chỉnh sửa nguồn.

### 7.2. Thêm BatchId

1. Kéo **Derived Column** vào nền → đổi tên `Them BatchId`.
2. Nhấp nguồn và kéo mũi tên xanh dương sang `Them BatchId`.
3. Nhấp đúp `Them BatchId`, tạo dòng: `Derived Column Name = BatchId`, `Derived Column = <add as new column>`, `Expression`:

```text
(DT_GUID)("{" + @[User::BatchId] + "}")
```

4. Kiểu kết quả phải là `DT_GUID`; nhấn **OK**. Procedure hiện trả GUID dạng 36 ký tự không có ngoặc; biểu thức thêm ngoặc trước khi chuyển kiểu. Đây là cấu hình đã chạy với package hiện tại.

### 7.3. Ghi staging

1. Kéo **OLE DB Destination** vào nền → đổi tên `Ghi du lieu vao staging`.
2. Nhấp `Them BatchId`, kéo đầu ra xanh dương sang destination. Nếu destination có dấu lỗi trước khi nối, hoàn tất kết nối và cấu hình rồi kiểm tra lại.
3. Nhấp đúp destination → chọn `OLE DB connection manager = CN_Kho`; `Data access mode = Table or view - fast load`; `Name of the table or the view = [stg].[AirQuality]`.
4. Chọn **Mappings**; đối chiếu cùng tên: `BatchId`, `SourceId`, `StationId`, `SensorId`, `StationName`, `ObservedAtSource`, `Latitude`, `Longitude`, `PollutantCode`, `Unit`, `Value`. `StageRowId` là IDENTITY và `ExtractedAtUTC` có DEFAULT: không ánh xạ hai cột này từ nguồn. Nếu một cột không tự nối, chọn đúng cột nguồn trong danh sách của dòng đích.
5. Nhấn **OK**, sau đó **File → Save All**. Nếu metadata/cột đổi, mở lại Mappings để kiểm tra và sửa.

## 8. Tạo task xử lý staging

1. Trở lại **Control Flow**, kéo **Execute SQL Task** vào nền, đổi tên `ProcessStagedBatch`.
2. Nhấp đúp task → **General**: `ResultSet = None`, `ConnectionType = OLE DB`, `Connection = CN_Kho`, `SQLSourceType = Direct input`.
3. Nhập **SQLStatement**:

```sql
DECLARE @BatchId uniqueidentifier = CONVERT(uniqueidentifier, ?);
EXEC etl.usp_ProcessStagedBatch @BatchId = @BatchId;
```

4. Chọn **Parameter Mapping → Add**: `Variable Name = User::BatchId`, `Direction = Input`, `Data Type = VARCHAR`, `Parameter Name = 0`, `Parameter Size = 36` → **OK**.
5. Chọn `Extract PM to Stage` và kéo mũi tên xanh sang `ProcessStagedBatch`. Dấu `?` nhận tham số OLE DB theo vị trí, tính từ 0.

## 9. Tạo nhánh ghi lỗi Data Flow

1. Kéo thêm **Execute SQL Task** trong Control Flow → đổi tên `FailStagedBatch`.
2. Nhấp đúp → **General**: `ResultSet = None`, `ConnectionType = OLE DB`, `Connection = CN_Kho`, `SQLSourceType = Direct input`.
3. Điền **SQLStatement**:

```sql
DECLARE @BatchId uniqueidentifier = CONVERT(uniqueidentifier, ?);
EXEC etl.usp_FailStagedBatch
    @BatchId = @BatchId,
    @Reason = N'SSIS Data Flow failed. Xem Progress de biet chi tiet.';
```

4. Trong **Parameter Mapping → Add**, điền cùng các giá trị `User::BatchId`, `Input`, `VARCHAR`, `0`, `36` như task xử lý; nhấn **OK**.
5. Kéo một mũi tên khác từ `Extract PM to Stage` đến `FailStagedBatch` → nhấp đúp đường nối → **Value = Failure** → **OK**. Đường nối chuyển đỏ.

Khi Data Flow lỗi, batch được ghi Failed qua nhánh này. Khi `ProcessStagedBatch` lỗi, chính procedure xử lý rollback và ghi Failed. Lỗi ở thời điểm tạo batch hoặc crash có thể để batch Running; cần kiểm tra và xử lý riêng, không xóa log tùy tiện.

## 10. Chạy và kiểm tra trong SSMS

1. **File → Save All**, sau đó nhấn nút **Start** trong Visual Studio.
2. Xem **Progress** và Control Flow. Luồng thành công có dấu xanh tại StartBatch, Extract PM to Stage và ProcessStagedBatch. Nhánh lỗi không chạy nếu Data Flow thành công.
3. Ở Data Flow, kiểm tra số dòng đi từ nguồn qua Derived Column đến destination; bộ dữ liệu hiện tại có 11.500 dòng PM.
4. Mở SSMS → kết nối đúng server → **New Query** → dán và nhấn **Execute**:

```sql
USE hanoi_air_dw;
GO
SELECT TOP (10) BatchId, StartedAtUTC, FinishedAtUTC, Status,
       ExtractedRows, InsertedRows, ExistingRows, RejectedRows,
       DuplicateRows, ExcludedRows, ConflictRows, ErrorMessage
FROM etl.BatchLog
ORDER BY StartedAtUTC DESC;

SELECT COUNT_BIG(*) AS SoDongFact FROM dbo.FactAirQuality;
```

5. Đối chiếu: batch `Success`, `ConflictRows = 0`, và `ExtractedRows = InsertedRows + ExistingRows + RejectedRows + DuplicateRows + ExcludedRows`.
6. Trong Visual Studio nhấn **Shift + F5** để thoát debug → **Start** chạy lại; trở lại SSMS nhấn **Execute** lần nữa. Với nguồn hiện tại và fact đã nạp, hai batch gần nhất đã được ghi nhận mỗi batch 11.500 dòng trích xuất, 0 dòng mới, 11.500 dòng đã có; fact giữ 11.500 dòng. Khi nguồn thay đổi phải đối chiếu số thực tế, không mặc định các số này.
7. Các câu SQL trên chỉ đọc dữ liệu. Lưu tab query thành `.sql` nếu muốn mở lại thuận tiện; không lưu tab cũng không xóa database hay BatchLog. Lưu file SQL không tự lưu bảng kết quả: cần chụp ảnh hoặc xuất riêng kết quả nếu dùng làm minh chứng.

## 11. Minh chứng và trạng thái

- Đã có ảnh hai batch SSIS thành công, Data Flow 11.500 dòng và số fact 11.500 sau chạy lại; trước đó cũng đã thấy lỗi Data Flow đi vào nhánh `Failed`.
- Đã lưu ảnh **Parameter Mapping** và **StartBatch → Result Set**; các ảnh công khai được chọn để không lộ tên máy hoặc tài khoản.
- Có một batch cũ còn `Running` sau lần lỗi ánh xạ StartBatch. Cần xác nhận đúng batch, xác nhận không còn chạy rồi ghi `Failed` cùng lý do; không sửa hàng loạt, không xóa lịch sử. Chưa xác nhận đã xử lý.
- Chưa có bằng chứng đã cấu hình tham số server/database trong `Project.params`; cấu hình connection hiện dùng Connection Manager. Khóa không bao trùm toàn bộ quá trình Data Flow, và lỗi đột ngột có thể để batch dở.
- Ảnh Data Flow, Control Flow, kết quả và cấu hình cần được lưu trong vị trí minh chứng phù hợp. Chỉ kết luận đầy đủ khi các điểm còn thiếu được kiểm tra.

## 12. Một số lỗi đã gặp

- `Unable to find column NewResultName`: vào `StartBatch → Result Set`, đổi Result Name thành `0`, ánh xạ `User::BatchId`.
- Lỗi chuyển `DT_WSTR` sang `DT_GUID`: kiểm tra mã trả về và biểu thức có ngoặc nhọn ở mục 7.2; không khẳng định mọi lỗi GUID đều cùng nguyên nhân.
- `0xC0047041` khi cấu hình destination: xem chi tiết lỗi, kiểm tra đường nối Data Flow, bảng đích và Mappings; mã lỗi không đủ để xác định mọi nguyên nhân.
- Cảnh báo performance counters không khả dụng không đồng nghĩa package thất bại; xem dòng Error và trạng thái batch thực tế.
