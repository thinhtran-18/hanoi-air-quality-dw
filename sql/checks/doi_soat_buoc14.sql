-- Bước 14: Kiểm chứng ghép cặp giờ đồng thời và độ phủ trạm-chất.
USE hanoi_air_dw;
GO

-- 1. Tổng hợp ghép cặp theo chất từ dbo.vw_StationPairHourly
SELECT
    p.PollutantCode,
    COUNT_BIG(*) AS PairedHours,
    AVG(v.ValueHangDau) AS HangDauPairedMean,
    AVG(v.ValueKhuongTrung) AS KhuongTrungPairedMean,
    AVG(v.Difference) AS MeanDifference_ugm3
FROM dbo.vw_StationPairHourly v
JOIN dbo.DimPollutant p ON p.PollutantKey = v.PollutantKey
GROUP BY p.PollutantCode
ORDER BY p.PollutantCode;

-- 2. Ví dụ kiểm tra 1 ngày cụ thể (2024-01-29, pm25): so sánh giờ riêng từng trạm với giờ ghép cặp
SELECT
    s.StationName,
    COUNT(DISTINCT h.TimeKey) AS ObservedHours_20240129,
    AVG(h.HourMean) AS StationOnlyMean_20240129
FROM dbo.vw_StationHourly h
JOIN dbo.DimStation s ON s.StationKey = h.StationKey
JOIN dbo.DimPollutant p ON p.PollutantKey = h.PollutantKey
WHERE h.DateKey = 20240129 AND p.PollutantCode = N'pm25'
GROUP BY s.StationName
ORDER BY s.StationName;

SELECT
    COUNT_BIG(*) AS PairedHours_20240129,
    AVG(v.ValueHangDau) AS HangDauPairedMean_20240129,
    AVG(v.ValueKhuongTrung) AS KhuongTrungPairedMean_20240129,
    AVG(v.Difference) AS MeanDiff_20240129
FROM dbo.vw_StationPairHourly v
JOIN dbo.DimPollutant p ON p.PollutantKey = v.PollutantKey
WHERE v.DateKey = 20240129 AND p.PollutantCode = N'pm25';

-- 3. Ví dụ ngày không có giờ chung giữa hai trạm (tháng 8/2024)
SELECT COUNT_BIG(*) AS PairedHours_Aug2024
FROM dbo.vw_StationPairHourly v
JOIN dbo.DimDate d ON d.DateKey = v.DateKey
WHERE d.YearNumber = 2024 AND d.MonthNumber = 8;

-- 4. Độ phủ và số giờ thiếu cả năm 2024 (8.784 giờ/trạm/chất)
SELECT
    s.StationName,
    p.PollutantCode,
    8784 AS ExpectedHours,
    COUNT_BIG(*) AS ObservedHours,
    8784 - COUNT_BIG(*) AS MissingHours,
    CAST(100.0 * COUNT_BIG(*) / 8784 AS decimal(6,2)) AS CoveragePercent
FROM dbo.vw_StationHourly h
JOIN dbo.DimStation s ON s.StationKey = h.StationKey
JOIN dbo.DimPollutant p ON p.PollutantKey = h.PollutantKey
GROUP BY s.StationName, p.PollutantCode
ORDER BY s.StationName, p.PollutantCode;
GO
