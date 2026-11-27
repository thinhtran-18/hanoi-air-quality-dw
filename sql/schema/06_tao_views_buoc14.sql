-- Bước 14: Tạo các view phục vụ so sánh công bằng theo tập giờ ghép cặp.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
GO

-- 1. Một dòng / trạm / chất / giờ địa phương (UTC+07:00), trung bình các phép đo hợp lệ.
CREATE OR ALTER VIEW dbo.vw_StationHourly
AS
SELECT
    DATEADD(HOUR, CAST(t.HourNumber AS int), CAST(d.FullDate AS datetime2(0))) AS HourLocal,
    f.DateKey,
    f.TimeKey,
    f.StationKey,
    s.StationId,
    f.PollutantKey,
    AVG(f.Value) AS HourMean,
    COUNT_BIG(*) AS SampleCount
FROM dbo.FactAirQuality f
JOIN dbo.DimDate d ON d.DateKey = f.DateKey
JOIN dbo.DimTime t ON t.TimeKey = f.TimeKey
JOIN dbo.DimStation s ON s.StationKey = f.StationKey
WHERE f.IsValid = 1
  AND f.Value IS NOT NULL
GROUP BY
    d.FullDate,
    t.HourNumber,
    f.DateKey,
    f.TimeKey,
    f.StationKey,
    s.StationId,
    f.PollutantKey;
GO

-- 2. Ghép cặp hai trạm Hàng Đậu (2161299) và Khương Trung (2161301) theo cùng giờ địa phương và cùng chất.
CREATE OR ALTER VIEW dbo.vw_StationPairHourly
AS
SELECT
    a.HourLocal,
    a.DateKey,
    a.TimeKey,
    a.PollutantKey,
    a.HourMean AS ValueHangDau,
    b.HourMean AS ValueKhuongTrung,
    a.HourMean - b.HourMean AS Difference
FROM dbo.vw_StationHourly a
JOIN dbo.vw_StationHourly b
  ON a.DateKey = b.DateKey
 AND a.TimeKey = b.TimeKey
 AND a.PollutantKey = b.PollutantKey
WHERE a.StationId = 2161299
  AND b.StationId = 2161301;
GO
