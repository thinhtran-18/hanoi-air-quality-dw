-- Buoc 6: tao kho rieng; khong thay doi database nguon hanoi_air_vn.
-- Chay 01 -> 05. Ket noi bang Windows Authentication / cau hinh cuc bo.
USE [master];
GO
IF DB_ID(N'hanoi_air_dw') IS NULL
    EXEC(N'CREATE DATABASE [hanoi_air_dw]');
GO
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
    IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl AUTHORIZATION dbo;');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'01: hanoi_air_dw, stg, etl san sang.';
GO
