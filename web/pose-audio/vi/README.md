# Giọng hướng dẫn camera tiếng Việt

Các file MP3 được tạo sẵn bằng giọng `vi-VN-HoaiMyNeural` qua công cụ
[edge-tts](https://github.com/rany2/edge-tts). Nội dung nằm trong `phrases.json`.
Chạy `python tool/generate_pose_audio.py` từ thư mục project để tạo lại file còn thiếu
(cần `pip install edge-tts`; muốn thay nội dung thì xóa riêng file MP3 tương ứng trước).

Camera ưu tiên giọng tiếng Việt do trình duyệt cung cấp. Khi máy không có giọng
Việt, camera phát các file cục bộ này, gồm hướng dẫn tư thế và các đoạn ghép số
lần tập. Không gửi video, thông tin tài khoản hoặc kết quả tập đến dịch vụ giọng nói.
Ứng dụng không cần kết nối dịch vụ tổng hợp giọng nói khi phát các file này.
