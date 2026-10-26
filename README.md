# AI GYM — Flutter

Giao diện tiếng Việt theo 12 màn hình tham chiếu, nền tối và điểm nhấn tím. Dùng widget Flutter Material, không thêm thư viện quản lý trạng thái hoặc giao diện.

## Chạy ứng dụng

Đăng nhập bằng Google trên web: xem [cấu hình Client ID](docs/GOOGLE_LOGIN.md).
Nút Google dùng tài khoản thật sau khi cấu hình backend, không cần mật khẩu Gmail.

Trên máy Windows hiện tại, mở hai terminal PowerShell tại thư mục ngoài
`C:\Users\ACER\Documents\HOC FE\GYM-AI-main` và chạy lần lượt:

```powershell
.\run-backend.cmd
```

```powershell
.\run-app.cmd
```

Giữ cả hai terminal chạy. Mở Chrome tại `http://localhost:5353`,
backend tại `http://localhost:5129`. Script tự chọn đúng thư mục con chứa
`pubspec.yaml`; script Flutter dùng PATH hoặc SDK tại `E:\flutter`.

Yêu cầu Flutter 3.47.5 / Dart 3.13.4 trở lên.

```sh
flutter pub get
flutter run -d chrome
```

Trên máy hiện tại, Flutter nằm ở `E:\flutter`. Nếu PATH chưa có Flutter,
mở PowerShell tại thư mục chứa `pubspec.yaml` và chạy:

```powershell
& "E:\flutter\bin\flutter.bat" run -d chrome --web-port=5353 --dart-define=API_BASE_URL=http://localhost:5129
```

Để chạy ứng dụng Windows desktop (cần Visual Studio với workload **Desktop development with C++**):

```powershell
& "E:\flutter\bin\flutter.bat" run -d windows
```

Để chạy trên Android/iOS, chọn thiết bị từ `flutter devices` rồi dùng `flutter run -d <device-id>`. Build iOS cần macOS và Xcode. Bản web ở màn hình lớn được giới hạn chiều rộng 480 px; trên điện thoại giao diện dùng toàn bộ chiều rộng.

Chọn **Đăng nhập tài khoản demo** ở trang đăng nhập để vào nhanh bằng tài khoản demo có kết nối backend, hoặc nhập email/số điện thoại hợp lệ và mật khẩu. Luồng đăng ký kiểm tra họ tên, email/điện thoại, mật khẩu tối thiểu 8 ký tự, xác nhận mật khẩu và điều khoản, rồi mở ba bước onboarding.

Tài khoản demo có sẵn: **admin123@gmail.com**, mật khẩu **123123123Az!**. Nhập đúng thông tin này ở trang đăng nhập hoặc chọn nút đăng nhập demo để vào trang chủ. Đăng nhập qua backend giúp lưu và khôi phục lịch sử AI Coach.

## Màn hình và mã nguồn

| Màn hình | File |
|---|---|
| Đăng nhập, đăng ký, quên mật khẩu | `lib/screens/auth.dart` |
| Mục tiêu, chỉ số cơ thể, lịch tập | `lib/screens/onboarding.dart` |
| Trang chủ | `lib/screens/home.dart` |
| Camera AI ảnh / pose trên web | `lib/screens/camera.dart`, `lib/screens/pose_camera_web.dart`, `web/pose_camera.mjs` |
| Lịch tập AI và kết quả từng bài | `lib/screens/workout_plans.dart`, backend `WorkoutController` |
| Đi bộ / chạy bộ | `lib/screens/activity.dart`, backend `ActivityController` |
| AI Coach | `lib/screens/coach.dart` |
| Cộng đồng / PT | `lib/screens/community.dart` |
| Cài đặt hệ thống, AI Coach & Báo cáo | `lib/screens/settings.dart` |
| Thanh điều hướng và nút camera | `lib/screens/shell.dart` |
| Màu, font, các widget dùng chung | `lib/ui.dart` |
| Khởi động và các route | `lib/main.dart` |

Xem [ảnh tổng hợp 12 màn hình](docs/previews/overview.png). Ảnh render 402 × 874 px của từng màn hình nằm trong [docs/previews](docs/previews). Bộ màu chính: nền `#111111`, thẻ `#1E1E1E`, viền `#323232`, tím `#983BFA`.

## Tương tác minh họa

Chuyển tab giữ lại trạng thái chat, lượt thích và bình luận. Có chọn mục tiêu/lịch tập, điều chỉnh chỉ số, xem chi tiết bài tập, chat mẫu, lọc PT, xem hồ sơ, bật tắt cài đặt, và tạm dừng/kết thúc phiên camera mẫu. Cài đặt AI Coach chỉ áp dụng khi bấm **Lưu thay đổi**; quay lại sẽ bỏ thay đổi chưa lưu.

Đăng nhập, hồ sơ, kế hoạch tập, lịch sử, cộng đồng và AI Coach dùng backend hiện có. Lịch tập AI cần backend ASP.NET Core kết nối LM Studio; bài tập được chọn theo ID trong danh mục, có thể sửa trước/sau khi lưu và kết quả được gắn với đúng bài trong đúng lịch. Pose camera trên web dùng MediaPipe local và hỗ trợ các bài có trong bộ quy tắc; Android/Windows camera hiện chỉ gửi ảnh cho AI nhận xét, chưa đếm reps. Đi bộ/chạy ghi bước từ cảm biến và quãng đường GPS khi thiết bị/quyền hỗ trợ, còn thiếu dữ liệu thì hiển thị rõ thay vì tạo số giả.

Theo dõi đi bộ/chạy và quyền platform được mô tả trong [camera và vận động](docs/camera-ai.md). Dữ liệu kế hoạch, kết quả bài tập và hoạt động được lưu ở SQL Server qua các migration backend.

## Kiểm tra

```sh
flutter analyze
flutter test
flutter build web
flutter test tool/render_previews_test.dart
```

Các widget test kiểm tra validation, đăng ký/onboarding, giữ trạng thái khi quay lại/chuyển tab, chat, bình luận, lượt thích, cài đặt, tạm dừng/kết thúc camera và bố cục ở chiều rộng 320 px với bàn phím.

## Tài nguyên

Font Roboto được đóng gói kèm [giấy phép](assets/fonts/LICENSE.txt). Các ảnh minh họa lấy từ Unsplash, có thể thay file cùng tên trong `assets/images/`:

- [workout.jpg](https://images.unsplash.com/photo-1574680096145-d05b474e2155)
- [community.jpg](https://images.unsplash.com/photo-1517836357463-d25dfeac3438)
- [trainer.jpg](https://images.unsplash.com/photo-1534438327276-14e5300c3a48)
- [avatar.jpg](https://images.unsplash.com/photo-1500648767791-00dcc994a43e)
