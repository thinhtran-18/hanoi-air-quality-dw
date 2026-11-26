"""Đọc 325 tệp nén và ghép các dòng CSV vào một tệp mới."""
import sys  # Cấu hình đầu ra hỗ trợ tiếng Việt.
import argparse  # Đọc tham số dòng lệnh.
import csv  # Đọc và ghi CSV, xử lý dấu phẩy và dấu nháy.
import gzip  # Đọc CSV trực tiếp từ tệp .gz.
from pathlib import Path  # Thao tác đường dẫn.

if hasattr(sys.stdout, 'reconfigure'):  # Một số môi trường chuyển hướng không hỗ trợ cấu hình.
    sys.stdout.reconfigure(encoding='utf-8')  # Xuất thông báo tiếng Việt dưới dạng UTF-8.

ROOT = Path(__file__).resolve().parent.parent  # Tìm thư mục gốc repo.


def main():
    """Ghép dữ liệu từ tất cả tệp gốc theo đúng cấu trúc cột."""
    parser = argparse.ArgumentParser(description=__doc__)  # Tạo bộ đọc tham số.
    parser.add_argument('--raw-dir', type=Path, default=ROOT / 'data/raw')  # Thư mục tệp gốc.
    parser.add_argument('--output', type=Path, required=True)  # Chỉ định CSV kết quả.
    args = parser.parse_args()  # Lấy giá trị tham số.
    files = sorted(args.raw_dir.glob('*.csv.gz'))  # Tìm và sắp xếp tệp nén.
    if not files:  # Tránh tạo CSV rỗng khi sai đường dẫn.
        raise ValueError('Không tìm thấy tệp .csv.gz')  # Báo lỗi để người dùng kiểm tra.
    if args.output.exists():  # Bảo vệ kết quả hiện có khỏi ghi đè.
        raise FileExistsError(f'Tệp đã tồn tại: {args.output}')  # Yêu cầu chọn đường dẫn mới.
    args.output.parent.mkdir(parents=True, exist_ok=True)  # Tạo thư mục chứa kết quả.
    count = 0  # Khởi tạo bộ đếm phép đo.
    with args.output.open('x', encoding='utf-8-sig', newline='') as output:  # Tạo CSV UTF-8 có BOM.
        writer = None  # Chưa biết tên cột trước khi đọc tệp đầu tiên.
        for path in files:  # Lần lượt đọc từng tệp nén.
            with gzip.open(path, 'rt', encoding='utf-8-sig', newline='') as source:  # Giải nén trong bộ nhớ khi đọc.
                reader = csv.DictReader(source)  # Ánh xạ mỗi dòng thành cặp tên cột và giá trị.
                if writer is None:  # Tệp đầu tiên cung cấp danh sách cột.
                    columns = reader.fieldnames  # Lưu thứ tự cột nguồn.
                    if not columns:  # Từ chối tệp thiếu tiêu đề.
                        raise ValueError(f'Thiếu tiêu đề: {path}')  # Báo lỗi để kiểm tra nguồn.
                    writer = csv.DictWriter(output, fieldnames=columns)  # Tạo bộ ghi theo cột nguồn.
                    writer.writeheader()  # Chỉ ghi tiêu đề một lần.
                if reader.fieldnames != columns:  # Kiểm tra mọi tệp dùng cùng cấu trúc.
                    raise ValueError(f'Cột không khớp: {path}')  # Dừng để tránh ghép sai dữ liệu.
                for row in reader:  # Duyệt từng phép đo.
                    writer.writerow(row)  # Ghi nguyên các trường vào CSV ghép.
                    count += 1  # Tăng số dòng đã ghi.
    print(f'Đã đọc {len(files)} tệp và ghép {count} phép đo: {args.output}')  # In kết quả.


if __name__ == '__main__':  # Tránh chạy khi tệp được import.
    main()  # Bắt đầu ghép CSV.
