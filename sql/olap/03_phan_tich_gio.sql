USE hanoi_air_dw;
GO
-- Theo giờ local; mẫu là phép đo sẵn có, không đại diện giờ thiếu.
SELECT s.StationName,p.PollutantCode,p.Unit,t.HourNumber,AVG(f.Value) MeanValue,COUNT_BIG(*) Samples,COUNT(DISTINCT d.DateKey) DaysObserved
FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY s.StationName,p.PollutantCode,p.Unit,t.HourNumber ORDER BY s.StationName,p.PollutantCode,t.HourNumber;
GO
