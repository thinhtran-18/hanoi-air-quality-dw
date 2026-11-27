USE hanoi_air_dw;
GO
-- Ghép cùng ngày-giờ local và chất; nếu nhiều sensor thì trung bình từng trạm/giờ trước khi ghép.
WITH h AS (SELECT s.StationId,d.DateKey,t.TimeKey,p.PollutantCode,AVG(f.Value) HourMean,COUNT_BIG(*) Samples FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL GROUP BY s.StationId,d.DateKey,t.TimeKey,p.PollutantCode)
SELECT a.PollutantCode,COUNT_BIG(*) PairedHours,AVG(a.HourMean) HangDauMean,AVG(b.HourMean) KhuongTrungMean,AVG(a.HourMean-b.HourMean) MeanDifference FROM h a JOIN h b ON a.DateKey=b.DateKey AND a.TimeKey=b.TimeKey AND a.PollutantCode=b.PollutantCode WHERE a.StationId=2161299 AND b.StationId=2161301 GROUP BY a.PollutantCode ORDER BY a.PollutantCode;
GO
