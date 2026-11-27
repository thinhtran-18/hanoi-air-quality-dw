USE hanoi_air_dw;
GO
-- Roll-up tháng/quý; trung bình trực tiếp trên phép đo, không lấy trung bình các trung bình ngày.
SELECT d.YearNumber,d.QuarterNumber,d.MonthNumber,GROUPING(d.MonthNumber) IsQuarter,s.StationName,p.PollutantCode,p.Unit,AVG(f.Value) MeanValue,COUNT_BIG(*) Samples
FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY s.StationName,p.PollutantCode,p.Unit,d.YearNumber,d.QuarterNumber,ROLLUP(d.MonthNumber) ORDER BY s.StationName,p.PollutantCode,d.YearNumber,d.QuarterNumber,IsQuarter,d.MonthNumber;
GO
