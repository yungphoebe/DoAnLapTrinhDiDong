# AI GYM — Flutter

Giao diện tiếng Việt theo 12 màn hình tham chiếu, nền tối và điểm nhấn tím. Dùng widget Flutter Material, không thêm thư viện quản lý trạng thái hoặc giao diện.

## Chạy ứng dụng

Yêu cầu Flutter 3.47.5 / Dart 3.13.4 trở lên.

```sh
flutter pub get
flutter run -d chrome
```

Trên máy hiện tại, Flutter nằm ở `C:\Users\Phoebe\flutter` nhưng chưa có trong PATH. Mở PowerShell tại thư mục dự án và chạy:

```powershell
& "$env:USERPROFILE\flutter\bin\flutter.bat" run -d chrome
```

Để chạy ứng dụng Windows desktop (cần Visual Studio với workload **Desktop development with C++**):

```powershell
& "$env:USERPROFILE\flutter\bin\flutter.bat" run -d windows
```

Để chạy trên Android/iOS, chọn thiết bị từ `flutter devices` rồi dùng `flutter run -d <device-id>`. Build iOS cần macOS và Xcode. Bản web ở màn hình lớn được giới hạn chiều rộng 480 px; trên điện thoại giao diện dùng toàn bộ chiều rộng.

Chọn **Khám phá bản giao diện** ở trang đăng nhập để vào nhanh, hoặc nhập email/số điện thoại hợp lệ và mật khẩu bất kỳ. Luồng đăng ký kiểm tra họ tên, email/điện thoại, mật khẩu tối thiểu 8 ký tự, xác nhận mật khẩu và điều khoản, rồi mở ba bước onboarding.

Tài khoản demo có sẵn: **admin123@gmail.com**, mật khẩu **123123123Az!**. Nhập đúng thông tin này ở trang đăng nhập để vào trang chủ. Đây là tài khoản minh họa cục bộ, chưa có xác thực máy chủ hoặc quyền quản trị.

## Màn hình và mã nguồn

| Màn hình | File |
|---|---|
| Đăng nhập, đăng ký, quên mật khẩu | `lib/screens/auth.dart` |
| Mục tiêu, chỉ số cơ thể, lịch tập | `lib/screens/onboarding.dart` |
| Trang chủ | `lib/screens/home.dart` |
| Camera AI minh họa | `lib/screens/camera.dart` |
| AI Coach | `lib/screens/coach.dart` |
| Cộng đồng / PT | `lib/screens/community.dart` |
| Cài đặt hệ thống, AI Coach & Báo cáo | `lib/screens/settings.dart` |
| Thanh điều hướng và nút camera | `lib/screens/shell.dart` |
| Màu, font, các widget dùng chung | `lib/ui.dart` |
| Khởi động và các route | `lib/main.dart` |

Xem [ảnh tổng hợp 12 màn hình](docs/previews/overview.png). Ảnh render 402 × 874 px của từng màn hình nằm trong [docs/previews](docs/previews). Bộ màu chính: nền `#111111`, thẻ `#1E1E1E`, viền `#323232`, tím `#983BFA`.

## Tương tác minh họa

Chuyển tab giữ lại trạng thái chat, lượt thích và bình luận. Có chọn mục tiêu/lịch tập, điều chỉnh chỉ số, xem chi tiết bài tập, chat mẫu, lọc PT, xem hồ sơ, bật tắt cài đặt, và tạm dừng/kết thúc phiên camera mẫu. Cài đặt AI Coach chỉ áp dụng khi bấm **Lưu thay đổi**; quay lại sẽ bỏ thay đổi chưa lưu.

Ứng dụng hiện là phần giao diện: chưa kết nối tài khoản, OTP, mạng xã hội, AI, camera thật, thông báo hệ thống hoặc Apple Health. Ảnh camera và chỉ số là ảnh tĩnh minh họa. Dữ liệu chỉ giữ trong bộ nhớ phiên chạy và mất khi khởi động lại. Ảnh được thay bằng ảnh minh họa vì file ảnh gốc trong thiết kế chưa có riêng.

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
