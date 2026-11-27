-- Nap du lich ngay/gio, khong tao fact cho gio thieu; chay lai khong them trung.
-- Thu ISO tinh tu mot ngay Thu Hai co dinh, khong phu thuoc SET DATEFIRST.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    ;WITH days AS (
        SELECT CONVERT(date,'20240101',112) AS FullDate
        UNION ALL
        SELECT DATEADD(day,1,FullDate) FROM days WHERE FullDate < CONVERT(date,'20241231',112)
    ), calendar AS (
        SELECT FullDate, DATEDIFF(day,CONVERT(date,'19000101',112),FullDate) % 7 + 1 AS DayOfWeekISO
        FROM days
    )
    INSERT dbo.DimDate (DateKey, FullDate, DayOfMonth, MonthNumber, QuarterNumber, YearNumber, DayOfWeekISO, DayName)
    SELECT CONVERT(int,CONVERT(char(8),c.FullDate,112)), c.FullDate,
        DAY(c.FullDate), MONTH(c.FullDate), DATEPART(quarter,c.FullDate), YEAR(c.FullDate), c.DayOfWeekISO,
        CASE c.DayOfWeekISO WHEN 1 THEN N'Thứ Hai' WHEN 2 THEN N'Thứ Ba' WHEN 3 THEN N'Thứ Tư'
            WHEN 4 THEN N'Thứ Năm' WHEN 5 THEN N'Thứ Sáu' WHEN 6 THEN N'Thứ Bảy' WHEN 7 THEN N'Chủ Nhật' END
    FROM calendar c WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate d WHERE d.DateKey = CONVERT(int,CONVERT(char(8),c.FullDate,112)))
    OPTION (MAXRECURSION 366);
    ;WITH hours AS (
        SELECT 0 AS HourNumber UNION ALL SELECT HourNumber + 1 FROM hours WHERE HourNumber < 23
    )
    INSERT dbo.DimTime (TimeKey, FullTime, HourNumber, MinuteNumber, SecondNumber)
    SELECT h.HourNumber * 10000, TIMEFROMPARTS(h.HourNumber,0,0,0,0), h.HourNumber, 0, 0
    FROM hours h WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTime t WHERE t.TimeKey = h.HourNumber * 10000);
    IF (SELECT COUNT(*) FROM dbo.DimDate) <> 366 OR (SELECT COUNT(*) FROM dbo.DimTime) <> 24
        THROW 51001, 'Lich chua du 366 ngay / 24 moc gio.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
SELECT N'DimDate' AS CalendarTable, COUNT_BIG(*) AS RowsLoaded, MIN(FullDate) AS FirstDate, MAX(FullDate) AS LastDate FROM dbo.DimDate;
SELECT N'DimTime' AS CalendarTable, COUNT_BIG(*) AS RowsLoaded, MIN(FullTime) AS FirstTime, MAX(FullTime) AS LastTime FROM dbo.DimTime;
GO
