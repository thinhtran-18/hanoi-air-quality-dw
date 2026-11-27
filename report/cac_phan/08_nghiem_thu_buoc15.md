# Bước 15 — Nghiệm thu toàn bộ hệ thống

Ngày kiểm thử: **28/11/2026**. Mục tiêu: kiểm chứng đầu–cuối từ tệp gốc OpenAQ đến bảng SQL nguồn, kho dữ liệu `hanoi_air_dw`, ETL, cube SSAS 5 chiều và báo cáo Power BI 3 trang, bảo đảm số liệu khớp theo cùng bộ lọc, grain và quy tắc hợp lệ.

## 1. Tổng hợp 7 nhóm kiểm thử

| Nhóm kiểm thử | Phạm vi & thao tác đã chạy | Kết quả thực tế | Trạng thái |
| --- | --- | --- | --- |
| Nguồn và SQL | Kiểm tra SHA-256 trên `data/checksums.sha256`; đếm bảng nguồn `hanoi_air_vn.dbo.air_quality_hourly`; truy vấn `SourceId` | `327/327` tệp khớp hash (`0` lỗi); `23.036` dòng nguồn, `11.500` dòng PM2.5/PM10 | **PASS** |
| Kho và ETL | Chạy `sql/checks/kiem_tra_kho.sql`, kiểm tra bảng `FactAirQuality` và các ca ETL Bước 10 (`report/minh_chung/ket_qua_etl.csv`) | `11.500` dòng hợp lệ (`IsValid=1`), `0` khóa ngoại mồ côi, `0` trùng grain, batch cân đối dòng | **PASS** |
| Thời gian | Kiểm tra mẫu ranh ngày nửa đêm (`TimeKey = 0`, ví dụ `SourceId = 17264`) | `2024-02-24 00:00+07` ↔ `2024-02-23 17:00 UTC`; `DateKey = 20240224`, `TimeKey = 0` đúng giờ địa phương | **PASS** |
| Power BI cơ bản | Chạy DAX trực tiếp trên engine Power BI đối chiếu SQL (toàn cục, 1 ngày `2024-01-29`, 1 tháng `10/2024`, theo giờ `08:00`) | Số đếm khớp tuyệt đối; sai lệch FLOAT trước làm tròn `≤ 10⁻¹³ µg/m³` (đạt ngưỡng `≤ 0,000001`) | **PASS** |
| Power BI biên | Bỏ chọn chất (`Nồng độ trung bình`), lọc tháng trống `08/2024`, kiểm tra lọc cảm biến & giờ gián đoạn | Bỏ chọn chất trả `BLANK()`; tháng 8 trả `BLANK` & thông báo `"Không có giờ chung..."`, không tự điền `0` | **PASS** |
| So sánh ghép cặp & độ phủ | Đối chiếu `dbo.vw_StationPairHourly` và `dbo.vw_StationHourly` với các measures trên `StationPairHourly` & `FactAirQuality` | `2.098` giờ chung mỗi chất (`PM2.5`: `42,88` vs `32,47`, lệch `+10,42`; `PM10`: `74,40` vs `43,66`, lệch `+30,73`), độ phủ `28,44%–37,03%` | **PASS** |
| Tái lập | Dựng database thử độc lập `hanoi_air_dw_repro` bằng `sql/schema/01–06` và `sql/etl/01–02`, chạy `usp_RunBatch` 2 lần rồi dọn sạch | Lần 1: `11.500` mới (`Success`); Lần 2: `0` mới / `11.500` đã có; `vw_StationPairHourly`: `2.098` dòng mỗi chất | **PASS** |

Chi tiết 17 ca đối soát lưu tại [dashboard/doi_soat_chi_so.csv](../../dashboard/doi_soat_chi_so.csv).

## 2. Issue nhỏ đã phát hiện, khắc phục và kiểm chứng lại

- **Issue `I15-01` — Dòng tổ hợp ảo trên bảng Trạm–Cảm biến ở Trang 3:**
  - *Cách tái hiện:* Trên Trang 3 (`03_So_sanh_tra_cuu`), bảng tóm tắt nhóm theo `DimStation[StationName]`, `DimSensor[SensorId]` và `DimPollutant[PollutantCode]` hiển thị thêm các cặp Trạm × Cảm biến không có dữ liệu (như Hàng Đậu ghép với cảm biến của Khương Trung) với `Số giờ thiếu = 8.784`, do công thức cũ `COUNTROWS('DimDate') * 24` luôn trả giá trị khác `BLANK()` kể cả khi `[Số giờ trạm-chất]` là `BLANK()`.
  - *Khắc phục:* Cập nhật `Số giờ thiếu` trong [FactAirQuality.tmdl](../../dashboard/HanoiAirOLAP.SemanticModel/definition/tables/FactAirQuality.tmdl) và [measures.dax](../../dashboard/measures.dax) bổ sung điều kiện `NOT ISBLANK([Số giờ trạm-chất])`.
  - *Kiểm chứng lại:* Chạy lại truy vấn DAX `SUMMARIZECOLUMNS(DimStation[StationName], DimSensor[SensorId], DimPollutant[PollutantCode], "Missing", [Số giờ thiếu], "Hours", [Số giờ trạm-chất])` trên engine Power BI trả về đúng **4 dòng cảm biến thực tế** (`3.251 / 5.533`, `3.253 / 5.531`, `2.498 / 6.286`, `2.498 / 6.286`).

## 3. Giới hạn còn lại đã ghi nhận

- Kiểm thử tái lập `T10` đã xác nhận quy trình DDL `01–06` + T-SQL ETL `usp_RunBatch` trên kho trống `hanoi_air_dw_repro`; phần chạy trực tiếp package SSIS `00_RunAll.dtsx` trỏ sang một database thử khác chưa tách tham số hóa `Project.params` nên giữ ghi chú *"PASS có giới hạn"* trong [ket_qua_etl.csv](../minh_chung/ket_qua_etl.csv).
- Khi mở lại [HanoiAirOLAP.pbip](../../dashboard/HanoiAirOLAP.pbip) trên máy người dùng, nên bấm **Lưu / Lưu dưới dạng** một lần nữa nếu cần đồng bộ công thức `Số giờ thiếu` mới sửa vào tệp nhị phân [khong_khi_ha_noi.pbix](../../dashboard/khong_khi_ha_noi.pbix).
