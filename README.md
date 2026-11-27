# Kho dữ liệu chất lượng không khí Hà Nội

Đồ án môn Kho dữ liệu của nhóm 5 sinh viên. Phạm vi dự kiến: phân tích
PM2.5 và PM10 tại hai trạm Hàng Đậu và Khương Trung ở Hà Nội trong năm 2024,
sử dụng dữ liệu quan trắc từ OpenAQ.

Công nghệ dự kiến: SQL Server, Visual Studio/SSIS và Power BI. 

## Trạng thái

Đã hoàn thành bước 1–4: chốt phạm vi, kiểm tra môi trường, đối soát nguồn,
nạp bảng SQL nguồn và khảo sát chất lượng. Đã hoàn thành **bước 5: thiết kế
Star Schema**, gồm sơ đồ chỉnh sửa được, PNG, từ điển 6 bảng / 40 cột và
kiểm chứng grain trên CSV lẫn SQL Server.

- [Thiết kế và điều kiện hoàn thành bước 5](docs/thiet_ke/thiet_ke_star_schema.md)
- [Sơ đồ PNG](docs/thiet_ke/star_schema.png) · [Bản draw.io](docs/thiet_ke/star_schema.drawio)
- [Từ điển dữ liệu](docs/thiet_ke/tu_dien_du_lieu.md)
- [Báo cáo bước 5](report/cac_phan/02_thiet_ke_kho.md)

Bộ nguồn có 23.036 phép đo; phạm vi kho PM2.5/PM10 có 11.500 phép đo.
Đây là dữ liệu lịch sử không liên tục, chỉ phủ khoảng 28–37% giờ năm 2024
theo từng trạm/chất; giờ thiếu không phải 0. Chưa triển khai bảng kho, ETL,
OLAP hoặc dashboard. SSIS chưa xác nhận cài thành công; xử lý khi đến bước
cần dùng. Repo chưa có quy trình chạy đồ án hoàn chỉnh.

## Cấu trúc

```text
hanoi-air-quality-dw/
├── README.md
├── .gitignore
├── docs/
│   └── thiet_ke/
├── data/
│   ├── source/
│   └── raw/
├── sql/
│   ├── source/
│   ├── schema/
│   ├── olap/
│   └── checks/
├── etl/
├── dashboard/
├── tools/
└── report/
    ├── cac_phan/
    └── minh_chung/
```

## Nội dung từng thư mục

| Thư mục | Nội dung thành viên sẽ bổ sung |
| --- | --- |
| `docs/` | Đề xuất đề tài, phân công, hướng dẫn chạy và quy ước dữ liệu |
| `docs/thiet_ke/` | Sơ đồ Star Schema, đặc tả grain và từ điển dữ liệu |
| `data/source/` | CSV ghép và manifest ghi đường dẫn dữ liệu nguồn |
| `data/raw/` | Các tệp CSV nén gốc; giữ nguyên tên để đối chiếu manifest |
| `sql/source/` | Script T-SQL tạo và nạp dữ liệu nguồn |
| `sql/schema/` | Script tạo database kho, staging, dimensions và fact |
| `sql/olap/` | Truy vấn phân tích và mô tả kết quả |
| `sql/checks/` | Kiểm tra dữ liệu nguồn, kho dữ liệu và đối soát ETL |
| `etl/` | Solution, project, packages SSIS và hướng dẫn thực thi |
| `dashboard/` | Power BI, công thức DAX và đối soát chỉ số |
| `tools/` | Công cụ tải, kiểm tra dữ liệu và tạo T-SQL |
| `report/cac_phan/` | Nội dung báo cáo theo từng phần việc |
| `report/minh_chung/` | Ảnh và kết quả kiểm chứng dùng trong báo cáo |
| `report/` | Báo cáo và slide tổng hợp |

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
