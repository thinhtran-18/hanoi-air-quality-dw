# Kho dữ liệu chất lượng không khí Hà Nội

Đồ án môn Kho dữ liệu của nhóm 5 sinh viên. Phạm vi dự kiến: phân tích
PM2.5 và PM10 tại hai trạm Hàng Đậu và Khương Trung ở Hà Nội trong năm 2024,
sử dụng dữ liệu quan trắc từ OpenAQ.

Công nghệ dự kiến: SQL Server, Visual Studio/SSIS và Power BI. 

## Trạng thái

Bước 7–8 đã chuẩn hóa staging và nạp **11.500 fact** bằng T-SQL; chạy lại
không thêm dòng trùng. Xem [báo cáo bước 7](report/cac_phan/04_chuan_hoa_staging.md),
[báo cáo bước 8](report/cac_phan/05_nap_kho.md) và [hướng dẫn ETL](sql/etl/README.md).

Đã hoàn thành bước 1–4: chốt phạm vi, kiểm tra môi trường, đối soát nguồn,
nạp bảng SQL nguồn và khảo sát chất lượng. Đã hoàn thành **bước 5: thiết kế
Star Schema**, gồm sơ đồ chỉnh sửa được, PNG, từ điển 6 bảng / 40 cột và
kiểm chứng grain trên CSV lẫn SQL Server.

- [Thiết kế và điều kiện hoàn thành bước 5](docs/thiet_ke/thiet_ke_star_schema.md)
- [Sơ đồ PNG](docs/thiet_ke/star_schema.png) · [Bản draw.io](docs/thiet_ke/star_schema.drawio)
- [Từ điển dữ liệu](docs/thiet_ke/tu_dien_du_lieu.md)
- [Báo cáo bước 5](report/cac_phan/02_thiet_ke_kho.md)
- [Bước 5 mở rộng: cả ba lược đồ và so sánh](docs/thiet_ke/so_sanh_ba_luoc_do.md)
- Bông tuyết: [PNG](docs/thiet_ke/snowflake_schema.png) · [draw.io](docs/thiet_ke/snowflake_schema.drawio)
- Dải ngân hà: [PNG](docs/thiet_ke/galaxy_schema.png) · [draw.io](docs/thiet_ke/galaxy_schema.drawio)

Theo yêu cầu giảng viên, đã vẽ đủ **hình sao, bông tuyết và dải ngân hà**.
**Chọn hình sao để triển khai chính**; hai mô hình còn lại là phương án
thiết kế để so sánh, có từ điển riêng. Galaxy minh họa thêm fact độ phủ ngày,
đã tính thử và đối chiếu kết quả với khảo sát bước 4.

Đã thực thi **bước 6: tạo cấu trúc kho Star** trong SSMS: database
`hanoi_air_dw`, 6 bảng Star đúng 40 cột, staging/log/reject và các ràng buộc.
Lịch đã nạp đủ 366 ngày / 24 giờ; kiểm tra metadata khớp từ điển và 30 ca
thử ràng buộc đạt. Xem [DDL và cách chạy](sql/schema/README.md),
[báo cáo bước 6](report/cac_phan/03_trien_khai_cau_truc_kho.md).

Bộ nguồn có 23.036 phép đo; phạm vi kho PM2.5/PM10 có 11.500 phép đo.
Đây là dữ liệu lịch sử không liên tục, chỉ phủ khoảng 28–37% giờ năm 2024
theo từng trạm/chất; giờ thiếu không phải 0. Package SSIS bước 9 đã chạy
thành công hai lần; mỗi batch xử lý 11.500 dòng đã có, fact giữ 11.500 dòng.
Xem [báo cáo bước 9](report/cac_phan/06_ssis_buoc9.md) và
[hướng dẫn thao tác](docs/huong_dan_buoc_9_ssis.md).

Bước 10–15 đã kiểm thử ETL (`report/minh_chung/ket_qua_etl.csv`), chạy
8 truy vấn SQL OLAP (`sql/olap/`), dựng và deploy cube SSAS 5 chiều
(`HanoiAirOLAP`, gồm `DimSensor`), chạy 3 truy vấn MDX khớp SQL, chuẩn hóa
mô hình Power BI với 19 DAX measures (`dashboard/measures.dax`), bổ sung
views ghép cặp giờ đồng thời (`sql/schema/06_tao_views_buoc14.sql`), hoàn
thiện báo cáo 3 trang (`dashboard/khong_khi_ha_noi.pbix`) và nghiệm thu
đối soát đầu–cuối 17 ca (`dashboard/doi_soat_chi_so.csv`, xem
[báo cáo bước 15](report/cac_phan/08_nghiem_thu_buoc15.md)). Bước 16
(hoàn thiện báo cáo tổng hợp, `docs/huong_dan_chay.md`, slide và demo) là
chặng đóng gói cuối cùng.

## Cấu trúc

```text
hanoi-air-quality-dw/
├── README.md                                  # Tổng quan dự án, trạng thái và cấu trúc repo
├── AGENTS.md                                  # Quy tắc làm việc, quyết định kỹ thuật và tiến độ
├── LICENSE                                    # Giấy phép mã nguồn
├── .gitignore                                 # Loại trừ tệp tạm (.local, bin, obj, .vs)
├── docs/                                      # Tài liệu dự án & thiết kế mô hình
│   ├── pham_vi.md                             # Chốt phạm vi trạm, năm 2024, PM2.5/PM10
│   ├── moi_truong.md                          # Phiên bản công cụ & kiểm tra môi trường
│   ├── huong_dan_buoc_9_ssis.md               # Hướng dẫn cấu hình & chạy package SSIS
│   ├── De_xuat_de_tai_*.docx                  # Tài liệu đề xuất đề tài
│   ├── Phan_cong_nhom_*.docx                  # Bảng phân công nhóm
│   └── thiet_ke/                              # Sơ đồ Star, Snowflake, Galaxy & từ điển
│       ├── thiet_ke_star_schema.md            # Đặc tả grain, khóa, thời gian Star Schema
│       ├── so_sanh_ba_luoc_do.md              # So sánh Star, Snowflake và Galaxy
│       ├── tu_dien_du_lieu.md / .csv          # Từ điển 6 bảng / 40 cột Star Schema
│       ├── star_schema.drawio / .png          # Sơ đồ Star Schema (mô hình triển khai chính)
│       ├── snowflake_schema.drawio / .png     # Sơ đồ Snowflake (phương án tham khảo)
│       └── galaxy_schema.drawio / .png        # Sơ đồ Galaxy (phương án mở rộng độ phủ)
├── data/                                      # Dữ liệu nguồn OpenAQ & kiểm chứng toàn vẹn
│   ├── README.md                              # Hướng dẫn nguồn và cách tạo CSV ghép
│   ├── checksums.sha256                       # Mã băm SHA-256 đối chiếu 325 tệp gốc, CSV, SQL
│   ├── source/                                # Danh mục nguồn, manifest và CSV ghép
│   └── raw/                                   # 325 tệp .csv.gz gốc (giữ nguyên tên)
├── sql/                                       # Toàn bộ script T-SQL (nguồn, kho, ETL, OLAP, test)
│   ├── source/                                # Script tạo database nguồn hanoi_air_vn (23.036 dòng)
│   ├── schema/                                # DDL kho hanoi_air_dw (01–05, 00_chay_buoc6_ssms.sql)
│   ├── etl/                                   # Stored procedures chuẩn hóa & nạp kho (01–03)
│   ├── olap/                                  # 8 truy vấn SQL OLAP Bước 11 (01–08) & README.md
│   └── checks/                                # Script kiểm tra nguồn, cấu trúc, grain, ETL, kho
├── etl/                                       # Project SSIS (Visual Studio)
│   └── HanoiAirETL/                           # Solution & project HanoiAirETL (00_RunAll.dtsx)
├── olap/                                      # Cube SSAS Multidimensional & truy vấn MDX
│   ├── README.md                              # Mô tả cube HanoiAirOLAP và cách triển khai
│   ├── tao_cube.ps1                           # Script AMO dựng & process cube 5 chiều
│   ├── cap_quyen_doc_ssas.sql                 # Cấp quyền SELECT cho dịch vụ SSAS
│   ├── HanoiAirOLAP.xmla                      # Định nghĩa XMLA xuất từ server SSAS
│   ├── 01_chat.mdx / 02_tram_chat.mdx / 03_thang_chat.mdx  # 3 truy vấn MDX đối soát SQL
│   ├── HanoiAirCube/                          # Solution & project khung rỗng ban đầu
│   └── HanoiAirCubeImported/                  # Project nhập từ SSAS (5 chiều gồm DimSensor)
├── dashboard/                                 # Mô hình & báo cáo Power BI
│   ├── HanoiAirOLAP.pbip                      # Project Power BI (PBIP) bước 11
│   ├── HanoiAirOLAP.pbix                      # Tệp Power BI Desktop nhị phân
│   ├── HanoiAirOLAP.SemanticModel/            # Định nghĩa TMDL 6 bảng, 5 quan hệ, DAX measures
│   └── HanoiAirOLAP.Report/                   # Định nghĩa PBIR trang báo cáo & visual
├── tools/                                     # Script Python đối soát dữ liệu, kiểm tra & vẽ sơ đồ
└── report/                                    # Báo cáo tiến độ từng bước & minh chứng kiểm chứng
    ├── cac_phan/                              # Báo cáo chi tiết Bước 4–11 (01_du_lieu..07_olap_buoc11.md)
    └── minh_chung/                            # Kết quả CSV, JSON, RPT, ảnh chụp SSMS/SSIS/SSAS/Power BI
```

## Nội dung từng thư mục

| Thư mục | Nội dung chính |
| --- | --- |
| `docs/` | Đề xuất đề tài, phân công, phạm vi, môi trường và hướng dẫn chạy |
| `docs/thiet_ke/` | Sơ đồ Star/Snowflake/Galaxy, đặc tả grain và từ điển dữ liệu |
| `data/source/` | CSV ghép và manifest ghi đường dẫn dữ liệu nguồn |
| `data/raw/` | Các tệp CSV nén gốc; giữ nguyên tên để đối chiếu manifest |
| `sql/source/` | Script T-SQL tạo và nạp dữ liệu nguồn `hanoi_air_vn` |
| `sql/schema/` | Script tạo database kho `hanoi_air_dw`, staging, dimensions và fact |
| `sql/etl/` | Stored procedures chuẩn hóa staging và nạp kho |
| `sql/olap/` | 8 truy vấn phân tích OLAP và mô tả kết quả |
| `sql/checks/` | Kiểm tra dữ liệu nguồn, kho dữ liệu và đối soát ETL |
| `etl/` | Solution, project và package SSIS `00_RunAll.dtsx` |
| `olap/` | Cube SSAS 5 chiều (`HanoiAirOLAP`), script AMO, XMLA và truy vấn MDX |
| `dashboard/` | Power BI PBIP/PBIX, mô hình TMDL, công thức DAX và báo cáo |
| `tools/` | Công cụ Python kiểm tra dữ liệu, cấu trúc kho và tạo sơ đồ |
| `report/cac_phan/` | Nội dung báo cáo theo từng bước triển khai |
| `report/minh_chung/` | Ảnh chụp và kết quả kiểm chứng dùng trong báo cáo |

## Phối hợp trên GitHub

1. Lấy phiên bản mới nhất từ nhánh `main` trước khi bắt đầu nhiệm vụ.
2. Tạo nhánh theo công việc, ví dụ `schema/thiet-ke-kho`, `etl/nap-staging`,
   `olap/so-sanh-tram` hoặc `dashboard/measures`.
3. Commit và push sản phẩm vào đúng thư mục.
4. Mở Pull Request vào `main`, ghi nội dung thay đổi, cách chạy và kết quả kiểm tra.
5. Nhóm trưởng hoặc người phụ trách liên quan rà soát trước khi merge.

Thống nhất tên bảng, khóa, grain và quy tắc thời gian trước khi tích hợp.
Dùng đường dẫn tương đối hoặc tham số cấu hình thay cho đường dẫn riêng của
một máy. Không commit mật khẩu, token hoặc thông tin đăng nhập.

Các file Word, PowerPoint và PBIX nên có một người chỉnh tại một thời điểm
để tránh xung đột khó hợp nhất.
