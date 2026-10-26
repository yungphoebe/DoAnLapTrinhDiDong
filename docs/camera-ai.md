# Camera AI trên Android, Chrome và Windows

Nút **Mở camera AI** và **Nhận diện Form** đều mở camera thật. Cho phép quyền
camera, đặt thiết bị sao cho thấy rõ toàn thân, rồi chọn **Bắt đầu phân tích**.
Ứng dụng không bật microphone. Có thể đổi camera nếu máy có nhiều camera.

## Cách xử lý

Camera hiển thị trực tiếp. Khi bắt đầu, ứng dụng lấy một ảnh JPEG và gửi tới
LM Studio; cứ 3 giây sẽ lấy ảnh tiếp theo nếu yêu cầu trước đã hoàn tất.
Ảnh tạm được xóa sau khi đọc (trên web thu hồi blob URL). Phản hồi là nhận xét
theo từng ảnh, không phải theo dõi khung xương theo video, đếm lần tập hay đo
góc khớp. Không còn ảnh nền, khung xương hoặc số liệu tập luyện giả.

**Tạm dừng** ngừng gửi ảnh mới, vẫn cho xem camera. Yêu cầu đã gửi có thể tiếp
tục chạy trên máy chủ nhưng kết quả bị bỏ qua. Khi app chuyển nền, kết thúc
hoặc thoát màn hình, camera được giải phóng. Phiên chưa lưu vào lịch sử.

## LM Studio

1. Tải model hỗ trợ đầu vào hình ảnh (vision) và bật API server trong LM Studio.
   Camera dùng API native `/api/v1/chat`, tắt reasoning cho phản hồi ngắn và
   đặt `store: false`. Cần phiên bản LM Studio có API này và model cho phép tắt
   reasoning; đã thử với `qwen/qwen3.5-9b`. Luồng chat văn bản hiện có giữ nguyên.
2. Nhập đúng ID model ở ô **Model hình ảnh (LM Studio)**; nếu để trống, dùng model
   đầu tiên server trả về. Model chỉ xử lý văn bản sẽ không phân tích được ảnh.
3. URL mặc định là `http://127.0.0.1:1234/v1`. Đổi qua `LM_STUDIO_URL` khi chạy.
   Có thể đặt sẵn ID qua `LM_STUDIO_VISION_MODEL`.

```powershell
# Chrome hoặc Windows trên máy đang chạy LM Studio
& "$env:USERPROFILE\flutter\bin\flutter.bat" run -d chrome
& "$env:USERPROFILE\flutter\bin\flutter.bat" run -d windows

# Android thật: dùng IP LAN của máy chạy LM Studio, cùng mạng Wi-Fi
& "$env:USERPROFILE\flutter\bin\flutter.bat" run -d <android-device-id> --dart-define=LM_STUDIO_URL=http://192.168.1.10:1234/v1
```

Android: bật quyền camera; bật phục vụ trên mạng LAN của LM Studio và cho phép
cổng server qua tường lửa. `127.0.0.1` trên điện thoại không phải máy tính.
Android emulator dùng `http://10.0.2.2:1234/v1` để truy cập máy chủ trên máy tính.

Chrome: camera cần `localhost` hoặc HTTPS. Khi truy cập LM Studio từ web, bật
CORS cho origin ứng dụng. Web HTTPS cần API HTTPS tương thích, tránh mixed
content. Windows: bật quyền camera cho desktop apps trong Privacy & security.

Tốc độ và chất lượng góp ý phụ thuộc model, GPU và mạng. Chưa thể suy ra diễn
biến cả động tác từ một ảnh; nhận xét không thay thế đánh giá của huấn luyện viên.

## Phạm vi triển khai và kiểm tra

- `lib/screens/camera.dart`: camera, vòng đời, điều khiển phiên, kết quả thật.
- `lib/services/workout_analysis.dart`: chặn yêu cầu trùng và kết quả lỗi thời.
- `lib/services/camera_capture*.dart`: đọc ảnh và giải phóng ảnh tạm đa nền tảng.
- `pubspec.yaml`, Android manifest: plugin và quyền camera.
- `test/home_camera_test.dart`, `test/workout_analysis_test.dart`: kiểm tra
  mở/đóng, thiếu quyền/thiết bị, chuyển nền, xử lý lỗi, tạm dừng và yêu cầu chồng.
- `test/workout_vision_test.dart`: kiểm tra truyền JPEG qua HTTP và đọc phản hồi
  cuối cùng, không dùng nội dung reasoning làm lời khuyên tập luyện.

Chạy `flutter analyze`, `flutter test`, `flutter build web`,
`flutter build windows`, `flutter build apk --debug`. Test dùng camera giả;
cần kiểm tra thực tế camera và model vision trên từng thiết bị để xác nhận
chất lượng hình ảnh, quyền truy cập và phản hồi AI.

## Kết quả kiểm tra ngày 13/10/2026

- `flutter analyze`: không có lỗi hoặc cảnh báo.
- Bộ kiểm tra camera/analysis/vision: 20/20 đạt, bao gồm luồng ảnh → HTTP →
  phản hồi, dừng trong lúc chụp và xóa ảnh tạm.
- `flutter build web` và `flutter build windows`: thành công. Web có cảnh báo
  font CupertinoIcons của dự án.
- Thử `LMStudioService.analyzeImage` với JPEG `assets/images/workout.jpg` và
  `qwen/qwen3.5-9b` trên server thật: nhận phản hồi tiếng Việt sau khoảng 10 giây.
  Đây là ảnh mẫu của dự án, chưa phải buổi tập qua webcam thực tế.
- `flutter build apk --debug`: bị chặn bởi NDK `28.2.13676358` cài chưa đủ,
  thiếu `source.properties`; cần cài lại phiên bản này qua Android SDK Manager.
- Chưa kiểm tra camera vật lý trên cả ba nền tảng; không có thiết bị Android
  kết nối tại thời điểm kiểm tra.
- Toàn bộ `flutter test`: 30 đạt, 15 thất bại ở phần auth/cộng đồng/backend,
  không có lỗi trong 20 kiểm tra camera/analysis/vision. Các test cộng đồng gọi
  API thật `10.0.2.2:5129` bị HTTP 400 hoặc timeout trong môi trường test.

Các test ngoài phạm vi camera còn thất bại:

| File | Test |
|---|---|
| `auth_flow_test.dart` | registration validates confirmation then completes onboarding |
| `auth_flow_test.dart` | demo account signs in with the updated email and password |
| `auth_flow_test.dart` | email login still opens the demo |
| `auth_flow_test.dart` | password reset requires contact and shows demo outcome |
| `app_flow_test.dart` | shell preserves community state across tabs at 320px |
| `social_test.dart` | community like can be added and removed |
| `social_test.dart` | community keeps a submitted local comment |
| `social_test.dart` | community can create, edit and delete a post |
| `social_test.dart` | trainer tab, connection and filters update visible state |
| `post_controller_test.dart` | loadPosts exposes seeded posts from the API |
| `post_controller_test.dart` | createPost trims content and inserts the newest post first |
| `post_controller_test.dart` | createPost ignores blank content |
| `post_controller_test.dart` | updatePost replaces content and keeps the same post id |
| `post_controller_test.dart` | deletePost removes only the matching post |
| `post_controller_test.dart` | toggleLike updates the liked state and like count |

Tham chiếu API: [camera Windows](https://pub.dev/packages/camera_windows),
[LM Studio native chat](https://lmstudio.ai/docs/developer/rest/chat).
