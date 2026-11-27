# Rà soát bước 1–15 trước bàn giao

Ngày 28/11/2026. Đối chiếu kế hoạch tự làm trang 2–16 với sản phẩm trong repo. Đây là kiểm kê bằng chứng đã có; không tự nhận các lượt chạy lịch sử là kiểm thử mới.

| Bước | Kết quả có bằng chứng | Đánh giá và giới hạn |
|---|---|---|
| 1. Phạm vi | `docs/pham_vi.md`: 2 trạm, 2024, PM2.5/PM10 | Đạt phạm vi; một số câu “sẽ triển khai” là lịch sử cần đọc cùng trạng thái mới |
| 2. Môi trường | `docs/moi_truong.md`, project SSIS/SSAS và PBIP | Đã sử dụng thực tế theo biên bản; máy mới phải kiểm tra driver và phiên bản |
| 3. Nguồn | `data/checksums.sha256`, `data/README.md`, biên bản nguồn | Bước 15 ghi 327/327 hash: 325 gốc + CSV + SQL |
| 4. Nạp và chất lượng | `report/cac_phan/01_du_lieu.md`, `report/minh_chung/buoc4_*` | 23.036 nguồn, 11.500 PM; nguồn gián đoạn |
| 5. Thiết kế | `docs/thiet_ke/`: Star, Snowflake, Galaxy và từ điển | Star triển khai; hai phương án kia chỉ thiết kế; grain đủ cảm biến/timestamp |
| 6. DDL | `sql/schema/01`–`06`, metadata JSON và kiểm thử ràng buộc | 6 bảng/40 cột Star; lịch 366/24; tái lập T-SQL bước 15 bổ sung bằng chứng kho trống |
| 7. Chuẩn hóa | `sql/etl/01_chuan_hoa.sql`, `sql/checks/kiem_thu_buoc7.sql` | 11.500 accepted; thử lỗi/trùng/xung đột rollback theo biên bản |
| 8. Nạp kho | `sql/etl/02_nap_kho.sql`, báo cáo `05_nap_kho.md` | Lần hai không tăng fact; transaction, lock, không tự ghi đè xung đột |
| 9. SSIS | `etl/HanoiAirETL`, 4 ảnh `buoc9_*`, `06_ssis_buoc9.md` | Hai lần thành công trên kho đã nạp; còn cấu hình connection thủ công và batch cũ Running chưa xác nhận xử lý |
| 10. Kiểm thử ETL | `report/minh_chung/ket_qua_etl.csv` | 13 ca; có PASS lịch sử/PASS có giới hạn; chưa coi SSIS kho trống là đã thử |
| 11. OLAP | 8 SQL, 3 MDX, CSV kết quả, `HanoiAirCubeImported` | Cube 5 chiều theo cập nhật cuối; 1 cảnh báo provider SSDT; project cube cũ là khung |
| 12. Mô hình/DAX | 7 TMDL bảng, 8 quan hệ, `dashboard/measures.dax` | 19 measures; Date Table, tắt Auto Date/Time; kiểm chứng engine trong bước 15 |
| 13. Ba trang | PBIR và ảnh `buoc13_*`, `buoc14_*` | Có tổng quan/xu hướng/tra cứu; mô tả bước 13 còn đoạn lịch sử trước giờ ghép cặp |
| 14. So sánh | `sql/schema/06_tao_views_buoc14.sql`, `doi_soat_buoc14.sql` | 2.098 giờ chung/chất; độ phủ riêng 28,44–37,03%; không suy nguyên nhân |
| 15. Nghiệm thu | `report/cac_phan/08_nghiem_thu_buoc15.md`, `dashboard/doi_soat_chi_so.csv` | 17 ca đối soát; sai lệch FLOAT ≤10⁻¹³; tái lập T-SQL 11.500 rồi 0 mới; giới hạn SSIS còn ghi rõ |

## Những điểm không được nâng thành tuyên bố đã hoàn tất

- Tái lập bằng T-SQL trên database riêng không thay cho clone mới chạy package SSIS đầy đủ. `Project.params` vẫn rỗng, connection cần sửa trong designer.
- Khóa SSIS chỉ bao trùm ProcessStagedBatch; Data Flow/crash có thể để staging dở hoặc Running. Chi tiết reject/xung đột trong transaction thất bại rollback; ErrorMessage còn nhưng chưa có nhật ký từng dòng bền vững đầy đủ.
- PBIR dùng schema mới từng chưa có schema công khai tương ứng; kiểm tra schema cũ chỉ là kiểm tra tương thích, không chứng minh schema mới hoàn toàn.
- PBIP là bản làm việc. PBIX có thể cần lưu lại từ Desktop sau sửa measure; không suy từ ngày tệp hoặc ảnh cũ rằng đã đồng bộ.
- Ảnh và biên bản chứng minh trạng thái tại thời điểm ghi; không xác nhận dịch vụ đang chạy tại thời điểm người khác mở.

## Kiểm tra trực tiếp trong lượt bàn giao

Lượt bàn giao 28/11/2026 đã kiểm tra đọc bằng T-SQL qua dòng lệnh và mô hình đang mở qua MCP Power BI. Không mô tả các truy vấn này là đã bấm Execute trong SSMS. Minh chứng tổng hợp: `report/minh_chung/buoc16_kiem_tra_hien_tai.json`, `report/minh_chung/buoc16_sql_hien_tai.txt`.

- SQL hiện tại: 23.036 dòng nguồn, 11.500 fact hợp lệ, 366 ngày/24 giờ; 0 khóa ngoại mồ côi, 0 nhóm trùng grain, 40 cột trong 6 bảng Star. Hai chất đều có 2.098 giờ ghép cặp; các trung bình khớp mốc bước 15.
- Chạy đọc `tools/doi_soat_nguon.py`: 325 tệp gốc, 23.036 dòng, đối chiếu nội dung bằng nhau, 0 vấn đề; không dùng `--write` để ghi lại checksum.
- Kiểm tra riêng 327 checksum: 0 sai lệch. Thực hành ghép lại CSV từ 325 tệp và sinh SQL mới trong `.local/buoc16/`: 23.036 dòng, đa tập phép đo khớp CSV chốt; SQL sinh mới chưa thực thi lên database. Đã xem trực tiếp đủ ba trang Power BI, lưu ảnh `report/minh_chung/buoc16_01_tong_quan.png`, `buoc16_02_xu_huong.png`, `buoc16_03_so_sanh.png`.
- BatchLog hiện có 7 Success, 6 Failed và 2 Running. Running chưa được tự sửa: trạng thái này cần xác minh vận hành, không suy là ETL hiện đang chạy và không xóa lịch sử.
- MCP mô hình Power BI phát hiện 7 bảng, 8 quan hệ, 20 đối tượng measure gồm 19 chỉ số nghiệp vụ và một measure rỗng tên `Đo lường`. Measure rỗng là chi tiết dọn giao diện còn lại, không phải chỉ số nghiệp vụ thứ 20.
- Tái lập T-SQL kho riêng vẫn là bằng chứng lịch sử bước 15, chưa chạy lại trong lượt bàn giao. Chưa xác nhận clone mới chạy SSIS kho trống hoặc đã đồng bộ PBIX bằng lưu/refresh mới.

Theo yêu cầu đã chốt, ba lược đồ dùng để vẽ và học so sánh; chỉ Star cần thực thi SQL. Không coi Snowflake/Galaxy chưa dựng database là thiếu yêu cầu.

Tài liệu tiến độ cũ trong README và nhật ký môi trường đã được bổ sung trạng thái cuối; `tools/HUONG_DAN.txt` đã sửa đường dẫn `.work` cũ và phân biệt SQL chốt với SQL thực hành. Việc bỏ theo dõi `AGENTS.md` và bốn tệp `.pbi` chỉ thay đổi chỉ mục Git; các tệp vẫn còn trên máy, `.gitignore` đã bảo vệ cho lần commit tiếp theo. Chưa commit/push trong lượt bàn giao.
