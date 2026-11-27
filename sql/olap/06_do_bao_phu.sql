USE hanoi_air_dw;
GO
-- Lịch đầy đủ x trạm x chất, đếm giờ local khác nhau; thiếu không là nồng độ 0.
WITH obs AS (SELECT f.DateKey,f.StationKey,f.PollutantKey,COUNT(DISTINCT f.TimeKey) ObservedHours FROM dbo.FactAirQuality f WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY f.DateKey,f.StationKey,f.PollutantKey)
SELECT d.YearNumber,d.MonthNumber,s.StationName,p.PollutantCode,COUNT_BIG(*)*24 ExpectedHours,SUM(COALESCE(o.ObservedHours,0)) ObservedHours,COUNT_BIG(*)*24-SUM(COALESCE(o.ObservedHours,0)) MissingHours,CAST(100.0*SUM(COALESCE(o.ObservedHours,0))/(COUNT_BIG(*)*24) AS decimal(6,2)) CoveragePercent FROM dbo.DimDate d CROSS JOIN dbo.DimStation s CROSS JOIN dbo.DimPollutant p LEFT JOIN obs o ON o.DateKey=d.DateKey AND o.StationKey=s.StationKey AND o.PollutantKey=p.PollutantKey GROUP BY d.YearNumber,d.MonthNumber,s.StationName,p.PollutantCode ORDER BY s.StationName,p.PollutantCode,d.YearNumber,d.MonthNumber;
GO
