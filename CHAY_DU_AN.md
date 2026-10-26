# Chạy AI GYM trên Windows

Yêu cầu Flutter SDK, .NET SDK 9 trở lên và SQL Server LocalDB MSSQLLocalDB.
Mở hai terminal PowerShell tại thư mục repo chứa pubspec.yaml.

Terminal 1 — backend:

```powershell
.\run-backend.cmd
```

Terminal 2 — ứng dụng web:

```powershell
.\run-app.cmd
```

Giữ hai terminal chạy. Mở Chrome tại http://localhost:5353.
Swagger: http://localhost:5129/swagger.
Script Flutter dùng SDK từ PATH hoặc E:\flutter.

Đăng nhập Google: xem [GOOGLE_LOGIN.md](docs/GOOGLE_LOGIN.md).
Google OAuth Web Client ID là thông tin công khai; không cần Client Secret.

Camera cần quyền truy cập trong Chrome. Hướng dẫn tiếng Việt bật mặc định,
có nút Nghe thử tiếng Việt và tùy chọn tắt. Giọng đọc phụ thuộc các giọng
được trình duyệt hoặc hệ điều hành cung cấp.

SMTP không chứa thông tin đăng nhập cá nhân trong repo. Nếu cần gửi email,
đặt Smtp__UserName, Smtp__Password, Smtp__FromEmail bằng biến môi trường
hoặc secret manager cho backend. Không commit mật khẩu vào JSON.

Để dùng AI Coach/phân tích ảnh, mở LM Studio, nạp model theo cấu hình
backend/AiGym.Api/appsettings.Development.json và bật server cổng 1234.

## Kiểm tra

```powershell
node --test tool/pose_voice.test.mjs tool/pose_session.test.mjs test/google_sign_in_bridge_test.cjs
dotnet test backend/AiGym.Api.Tests
flutter analyze
flutter build web
```

Kiểm thử SQL thực dùng database tạm, bật bằng AIGYM_TEST_SQLSERVER.
Kiểm thử Google dùng token giả lập; đăng nhập thật cần Client ID,
Authorized JavaScript origins và tài khoản Google của người sử dụng.
