-- BƯỚC 4: khảo sát bảng nguồn; chỉ đọc dữ liệu, tạo bảng tạm trong phiên.
-- Chạy bằng SSMS trên SQL Server. Giờ địa phương dùng offset +07:00.
USE [hanoi_air_vn];
GO
SET NOCOUNT ON;

-- 1. Số dòng tổng và phạm vi chính PM2.5/PM10.
SELECT COUNT_BIG(*) AS tong_phep_do,
       SUM(CASE WHEN parameter IN (N'pm25', N'pm10') THEN CONVERT(BIGINT,1) ELSE 0 END) AS phep_do_pm
FROM dbo.air_quality_hourly;

-- 2. Số đo, thời gian và cực trị theo trạm/chất/đơn vị; không cộng các chất.
SELECT location_id, location_name, parameter, unit, COUNT_BIG(*) AS so_phep_do,
       MIN(observed_at) AS dau, MAX(observed_at) AS cuoi,
       MIN(value) AS gia_tri_nho_nhat, MAX(value) AS gia_tri_lon_nhat, AVG(value) AS trung_binh
FROM dbo.air_quality_hourly
GROUP BY location_id, location_name, parameter, unit
ORDER BY location_id, parameter, unit;

-- 3. Số đo theo cảm biến và tháng địa phương.
SELECT location_id, sensor_id, parameter,
       YEAR(SWITCHOFFSET(observed_at, '+07:00')) AS nam,
       MONTH(SWITCHOFFSET(observed_at, '+07:00')) AS thang,
       COUNT_BIG(*) AS so_phep_do
FROM dbo.air_quality_hourly
GROUP BY location_id, sensor_id, parameter,
         YEAR(SWITCHOFFSET(observed_at, '+07:00')), MONTH(SWITCHOFFSET(observed_at, '+07:00'))
ORDER BY location_id, parameter, sensor_id, nam, thang;

-- 4. NULL/rỗng, giá trị âm, timestamp ngoài năm và offset khác +07:00.
SELECT COUNT_BIG(*) AS tong,
       COUNT_BIG(*)-COUNT_BIG(location_id) AS null_ma_tram,
       COUNT_BIG(*)-COUNT_BIG(sensor_id) AS null_cam_bien,
       COUNT_BIG(*)-COUNT_BIG(location_name) AS null_ten_tram,
       COUNT_BIG(*)-COUNT_BIG(observed_at) AS null_thoi_gian,
       COUNT_BIG(*)-COUNT_BIG(latitude) AS null_vi_do,
       COUNT_BIG(*)-COUNT_BIG(longitude) AS null_kinh_do,
       COUNT_BIG(*)-COUNT_BIG(parameter) AS null_chat,
       COUNT_BIG(*)-COUNT_BIG(unit) AS null_don_vi,
       COUNT_BIG(*)-COUNT_BIG(value) AS null_gia_tri,
       SUM(CASE WHEN LTRIM(RTRIM(location_name))=N'' THEN 1 ELSE 0 END) AS rong_ten_tram,
       SUM(CASE WHEN LTRIM(RTRIM(parameter))=N'' THEN 1 ELSE 0 END) AS rong_chat,
       SUM(CASE WHEN LTRIM(RTRIM(unit))=N'' THEN 1 ELSE 0 END) AS rong_don_vi,
       SUM(CASE WHEN value < 0 THEN 1 ELSE 0 END) AS gia_tri_am,
       SUM(CASE WHEN DATEPART(TZOFFSET,observed_at) <> 420 THEN 1 ELSE 0 END) AS offset_khac_420,
       SUM(CASE WHEN YEAR(SWITCHOFFSET(observed_at,'+07:00')) <> 2024 THEN 1 ELSE 0 END) AS ngoai_nam_2024,
       SUM(CASE WHEN DATEPART(MINUTE,observed_at) <> 0 OR DATEPART(SECOND,observed_at) <> 0 THEN 1 ELSE 0 END) AS khong_dau_gio
FROM dbo.air_quality_hourly;

-- 5. Khóa lặp: cùng trạm, cảm biến, thời điểm và chất mới coi là trùng.
SELECT location_id,sensor_id,observed_at,parameter,COUNT_BIG(*) AS so_dong
FROM dbo.air_quality_hourly
GROUP BY location_id,sensor_id,observed_at,parameter
HAVING COUNT_BIG(*)>1;

-- 6. Phân bố đơn vị, timestamp lệch offset và 10 giá trị lớn nhất theo từng chất.
SELECT parameter,unit,COUNT_BIG(*) AS so_dong FROM dbo.air_quality_hourly GROUP BY parameter,unit ORDER BY parameter,unit;
SELECT DATEPART(TZOFFSET,observed_at) AS offset_phut,COUNT_BIG(*) AS so_dong FROM dbo.air_quality_hourly GROUP BY DATEPART(TZOFFSET,observed_at);
WITH ranked AS (
 SELECT location_id,sensor_id,observed_at,parameter,unit,value,
        ROW_NUMBER() OVER (PARTITION BY parameter ORDER BY value DESC,location_id,sensor_id,observed_at) AS stt
 FROM dbo.air_quality_hourly WHERE value IS NOT NULL
)
SELECT * FROM ranked WHERE stt<=10 ORDER BY parameter,stt;

-- 7. Tạo lịch đủ 8.784 giờ của năm 2024 (năm nhuận).
DROP TABLE IF EXISTS #LichGio;
DROP TABLE IF EXISTS #GioCoDo;
WITH n AS (
 SELECT TOP (8784) ROW_NUMBER() OVER (ORDER BY (SELECT NULL))-1 AS n
 FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT DATEADD(HOUR,CONVERT(INT,n),CONVERT(DATETIME2(0),'2024-01-01T00:00:00')) AS gio
INTO #LichGio FROM n;
CREATE UNIQUE CLUSTERED INDEX IX_LichGio ON #LichGio(gio);

-- Một giờ có đo khi có ít nhất một phép đo không NULL, không âm, đúng đơn vị.
-- Có nhiều cảm biến cùng giờ vẫn chỉ đếm một giờ; không thay thế giờ thiếu bằng 0.
SELECT DISTINCT location_id, parameter,
       DATEADD(HOUR,DATEDIFF(HOUR,CONVERT(DATETIME2(0),'2024-01-01T00:00:00'),
       CAST(SWITCHOFFSET(observed_at,'+07:00') AS DATETIME2(0))),CONVERT(DATETIME2(0),'2024-01-01T00:00:00')) AS gio
INTO #GioCoDo
FROM dbo.air_quality_hourly
WHERE location_id IN (2161299,2161301) AND parameter IN (N'pm25',N'pm10')
  AND unit=N'µg/m³' AND value IS NOT NULL AND value>=0
  AND SWITCHOFFSET(observed_at,'+07:00') >= '2024-01-01T00:00:00+07:00'
  AND SWITCHOFFSET(observed_at,'+07:00') < '2025-01-01T00:00:00+07:00';
CREATE UNIQUE CLUSTERED INDEX IX_GioCoDo ON #GioCoDo(location_id,parameter,gio);

-- 8. Độ phủ cả năm và từng tháng: mẫu số là số giờ lịch, không khẳng định trạm hoạt động suốt năm.
WITH nhom AS (SELECT station.location_id,p.parameter FROM (VALUES(2161299),(2161301)) station(location_id) CROSS JOIN (VALUES(N'pm25'),(N'pm10')) p(parameter))
SELECT n.location_id,n.parameter,COUNT(*) AS gio_ky_vong,COUNT(g.gio) AS gio_co_do,
       COUNT(*)-COUNT(g.gio) AS gio_khong_co_do,
       CAST(100.0*COUNT(g.gio)/COUNT(*) AS DECIMAL(6,2)) AS ty_le_phan_tram
FROM nhom n CROSS JOIN #LichGio l LEFT JOIN #GioCoDo g ON g.location_id=n.location_id AND g.parameter=n.parameter AND g.gio=l.gio
GROUP BY n.location_id,n.parameter ORDER BY n.location_id,n.parameter;

WITH nhom AS (SELECT station.location_id,p.parameter FROM (VALUES(2161299),(2161301)) station(location_id) CROSS JOIN (VALUES(N'pm25'),(N'pm10')) p(parameter))
SELECT n.location_id,n.parameter,MONTH(l.gio) AS thang,COUNT(*) AS gio_ky_vong,
       COUNT(g.gio) AS gio_co_do,COUNT(*)-COUNT(g.gio) AS gio_khong_co_do,
       CAST(100.0*COUNT(g.gio)/COUNT(*) AS DECIMAL(6,2)) AS ty_le_phan_tram
FROM nhom n CROSS JOIN #LichGio l LEFT JOIN #GioCoDo g ON g.location_id=n.location_id AND g.parameter=n.parameter AND g.gio=l.gio
GROUP BY n.location_id,n.parameter,MONTH(l.gio) ORDER BY n.location_id,n.parameter,thang;

-- 9. Đếm giờ chung của hai trạm theo từng chất.
SELECT a.parameter,COUNT(*) AS gio_ca_hai_tram_co_do
FROM #GioCoDo a JOIN #GioCoDo b ON a.gio=b.gio AND a.parameter=b.parameter
WHERE a.location_id=2161299 AND b.location_id=2161301 GROUP BY a.parameter ORDER BY a.parameter;

-- 10. Liệt kê các khoảng giờ thiếu liên tiếp; bao gồm cả biên năm.
WITH nhom AS (SELECT station.location_id,p.parameter FROM (VALUES(2161299),(2161301)) station(location_id) CROSS JOIN (VALUES(N'pm25'),(N'pm10')) p(parameter)),
thieu AS (
 SELECT n.location_id,n.parameter,l.gio,
        DATEADD(HOUR,-CONVERT(INT,ROW_NUMBER() OVER (PARTITION BY n.location_id,n.parameter ORDER BY l.gio)),l.gio) AS nhom_lien_tiep
 FROM nhom n CROSS JOIN #LichGio l LEFT JOIN #GioCoDo g ON g.location_id=n.location_id AND g.parameter=n.parameter AND g.gio=l.gio
 WHERE g.gio IS NULL
)
SELECT location_id,parameter,MIN(gio) AS gio_dau_thieu,MAX(gio) AS gio_cuoi_thieu,COUNT(*) AS so_gio_lien_tiep
FROM thieu GROUP BY location_id,parameter,nhom_lien_tiep ORDER BY so_gio_lien_tiep DESC,location_id,parameter;
GO
