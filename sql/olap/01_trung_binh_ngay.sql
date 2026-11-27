USE hanoi_air_dw;
GO
-- Câu hỏi: trung bình theo ngày local, trạm, chất. Chỉ giờ có dữ liệu; Samples là số phép đo.
SELECT d.FullDate,s.StationName,p.PollutantCode,p.Unit,AVG(f.Value) MeanValue,COUNT_BIG(*) Samples,COUNT(DISTINCT f.TimeKey) HoursObserved
FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY d.FullDate,s.StationName,p.PollutantCode,p.Unit ORDER BY d.FullDate,s.StationName,p.PollutantCode;
GO
