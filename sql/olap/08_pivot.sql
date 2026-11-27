USE hanoi_air_dw;
GO
-- Pivot theo chất trong từng trạm/tháng; hai chất là hai cột trung bình riêng, không cộng.
WITH a AS (SELECT s.StationName,d.YearNumber,d.MonthNumber,p.PollutantCode,AVG(f.Value) MeanValue,COUNT_BIG(*) Samples FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY s.StationName,d.YearNumber,d.MonthNumber,p.PollutantCode)
SELECT StationName,YearNumber,MonthNumber,MAX(CASE WHEN PollutantCode=N'pm25' THEN MeanValue END) PM25Mean,MAX(CASE WHEN PollutantCode=N'pm10' THEN MeanValue END) PM10Mean,MAX(CASE WHEN PollutantCode=N'pm25' THEN Samples END) PM25Samples,MAX(CASE WHEN PollutantCode=N'pm10' THEN Samples END) PM10Samples FROM a GROUP BY StationName,YearNumber,MonthNumber ORDER BY StationName,YearNumber,MonthNumber;
GO
