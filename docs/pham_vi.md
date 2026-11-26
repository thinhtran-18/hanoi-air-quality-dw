# Phạm vi dữ liệu và đề tài

Đề tài: Thiết kế và triển khai kho dữ liệu phục vụ phân tích đa chiều nồng độ PM2.5 và PM10 tại hai trạm quan trắc ở Hà Nội năm 2024.

- Hàng Đậu: OpenAQ location 2161299; Khương Trung: 2161301.
- Phạm vi thời gian: năm 2024 theo giờ Việt Nam UTC+07:00; các phép đo có khoảng thiếu, không đại diện liên tục cả năm.
- Chỉ tiêu chính: pm25, pm10, đơn vị µg/m³. Dữ liệu nguồn còn có CO, NO2.
- Dữ liệu lịch sử: hai mã trạm không còn cập nhật gần đây trên OpenAQ. Không suy ra tình trạng hoạt động hiện tại của trạm thực tế.
- Grain đề xuất: một phép đo theo trạm, cảm biến, thời điểm và chất.
- Không gọi nồng độ là AQI; không suy luận nguyên nhân do giao thông/thời tiết khi thiếu dữ liệu tương ứng. Phân tích mùa và vượt ngưỡng cần quy tắc, nguồn ngưỡng và độ bao phủ phù hợp.
- SQL nguồn và CSV chưa phải kho dữ liệu Star Schema. Các bước kho, ETL, OLAP và Power BI sẽ triển khai sau.
- Mốc bản CSV hiện tại: 23.036 phép đo, gồm 11.500 phép đo pm25/pm10; 325 tệp gốc. Các con số cần đối chiếu lại khi nguồn thay đổi.
