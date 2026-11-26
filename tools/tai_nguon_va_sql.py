"""Tải lại đúng các tệp được liệt kê trong manifest, không tạo SQL."""
import sys  # Cấu hình đầu ra hỗ trợ tiếng Việt.
import argparse  # Đọc các tùy chọn từ dòng lệnh.
import gzip  # Kiểm tra tệp tải về có giải nén được không.
from pathlib import Path  # Xử lý đường dẫn không phụ thuộc thư mục hiện hành.
from urllib.request import urlopen  # Tải tệp qua HTTPS.

if hasattr(sys.stdout, 'reconfigure'):  # Một số môi trường chuyển hướng không hỗ trợ cấu hình.
    sys.stdout.reconfigure(encoding='utf-8')  # Xuất thông báo tiếng Việt dưới dạng UTF-8.

ROOT = Path(__file__).resolve().parent.parent  # Thư mục gốc của repo.
BASE = 'https://openaq-data-archive.s3.amazonaws.com/'  # Gốc kho lưu trữ OpenAQ.


def main():
    """Đọc manifest và tải những tệp chưa có vào thư mục được chỉ định."""
    parser = argparse.ArgumentParser(description=__doc__)  # Khởi tạo bộ đọc tham số.
    parser.add_argument('--manifest', type=Path, default=ROOT / 'data/source/hanoi_air_quality_vn_source_manifest.txt')  # Danh sách đường dẫn gốc.
    parser.add_argument('--out-dir', type=Path, required=True)  # Bắt buộc chỉ định nơi tải.
    args = parser.parse_args()  # Phân tích tham số thực tế.
    keys = args.manifest.read_text(encoding='utf-8-sig').splitlines()  # Mỗi dòng là một đường dẫn trên OpenAQ.
    args.out_dir.mkdir(parents=True, exist_ok=True)  # Tạo thư mục đích nếu cần.
    for key in keys:  # Xử lý lần lượt từng đường dẫn.
        if not key.startswith('records/csv.gz/locationid=') or '..' in key or not key.endswith('.csv.gz'):  # Chỉ chấp nhận đường dẫn dữ liệu hợp lệ.
            raise ValueError(f'Đường dẫn không hợp lệ: {key}')  # Dừng nếu manifest bất thường.
        target = args.out_dir / Path(key).name  # Giữ nguyên tên tệp gốc.
        if target.exists():  # Giữ nguyên tệp đã có.
            print(f'Đã có: {target.name}')  # Thông báo không tải lại.
            continue  # Chuyển sang tệp tiếp theo.
        with urlopen(BASE + key, timeout=30) as response:  # Mở kết nối tới OpenAQ.
            content = response.read()  # Đọc toàn bộ nội dung tệp nén.
        gzip.decompress(content)  # Kiểm tra tệp nén trước khi lưu.
        target.write_bytes(content)  # Lưu nguyên byte tệp tải về.
        print(f'Đã tải: {target.name}')  # Thông báo tệp tải thành công.
    print(f'Đã xử lý {len(keys)} đường dẫn trong manifest.')  # Tổng kết số tệp.


if __name__ == '__main__':  # Chỉ chạy khi gọi trực tiếp file này.
    main()  # Bắt đầu quá trình tải.
