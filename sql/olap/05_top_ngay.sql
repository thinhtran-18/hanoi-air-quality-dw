USE hanoi_air_dw;
GO
-- Top 10 theo từng trạm/chất: tạm chọn >=18 giờ phân biệt trong ngày; ngưỡng minh họa, không phải chuẩn pháp lý.
WITH days AS (SELECT d.FullDate,s.StationName,p.PollutantCode,p.Unit,AVG(f.Value) MeanValue,COUNT_BIG(*) Samples,COUNT(DISTINCT f.TimeKey) HoursObserved FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY d.FullDate,s.StationName,p.PollutantCode,p.Unit HAVING COUNT(DISTINCT f.TimeKey)>=18), ranked AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY StationName,PollutantCode ORDER BY MeanValue DESC,FullDate) rn FROM days) SELECT * FROM ranked WHERE rn<=10 ORDER BY StationName,PollutantCode,rn;
GO
