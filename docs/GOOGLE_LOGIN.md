# Đăng nhập bằng tài khoản Google trên web

Ứng dụng dùng Google Identity Services để chọn tài khoản Google và gửi ID token
đến backend. Backend xác minh chữ ký Google, issuer, audience (Client ID), hạn
token và email đã xác minh trước khi cấp JWT của AI GYM. Không cần mật khẩu Gmail,
Client Secret, quyền đọc Gmail hay Firebase.

## Tạo Client ID (thực hiện một lần)

1. Mở https://console.cloud.google.com/ và chọn hoặc tạo project của bạn.
2. Mở **Google Auth Platform**. Cấu hình **Branding**, **Audience** và **Data Access**
   cho thông tin đăng nhập cơ bản (openid, email, profile). Nếu ứng dụng ở chế độ
   Testing, thêm Gmail bạn định thử vào danh sách **Test users** khi được yêu cầu.
3. Vào **Clients → Create client**, chọn **Web application**.
4. Trong **Authorized JavaScript origins**, thêm cả hai origin:

   ```text
   http://localhost
   http://localhost:5353
   ```

   Luồng popup JavaScript này không cần Authorized redirect URI cho backend.
5. Lưu và sao chép **Client ID**, dạng `123456-abcdef.apps.googleusercontent.com`.
   Không sao chép Client Secret vào frontend hoặc gửi mật khẩu Gmail.

Hướng dẫn chính thức: https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid

## Cấu hình backend

Mở `backend/AiGym.Api/appsettings.Development.json`, thêm section này ở cấp ngoài
cùng (ngang hàng với `ConnectionStrings`, `Logging`, `LMStudio`):

```json
"GoogleAuth": {
  "ClientId": "CLIENT_ID_CUA_BAN.apps.googleusercontent.com"
}
```

Thay giá trị bằng ID thật, không dùng nguyên ví dụ. Client ID là thông tin công khai.
Hoặc đặt biến môi trường `GoogleAuth__ClientId` trong terminal chạy backend.

Backend cung cấp Client ID công khai tại `GET /api/auth/google/config`; Flutter
không cần cấu hình cùng một ID lần thứ hai. Khi chưa có ID, nút Google giải thích
cấu hình còn thiếu, không đăng nhập giả.

## Chạy và thử

Tại thư mục ngoài `GYM-AI-main`, mở hai terminal PowerShell:

```powershell
.\run-backend.cmd
```

```powershell
.\run-app.cmd
```

Nếu đã chạy, dừng bằng Ctrl+C rồi chạy lại sau khi sửa cấu hình. Mở
http://localhost:5353 trên Chrome, bấm nút Google và chọn Gmail. Google có thể hỏi
chấp thuận lần đầu. Lần đầu app tạo tài khoản role User; những lần sau dùng
Google subject để khôi phục đúng tài khoản và dữ liệu đã có.

Nếu cùng email đã được đăng ký bằng mật khẩu, app báo xung đột và yêu cầu dùng
mật khẩu hiện có hoặc chọn Google khác. Không tự gộp tài khoản chỉ vì trùng email.

Đăng nhập Google ở đợt này hỗ trợ **web**. Nút trên bản native thông báo dùng Chrome;
cấu hình Android/iOS OAuth riêng chưa nằm trong thay đổi này.

## Lỗi thường gặp

- `origin is not allowed`: kiểm tra origin chính xác `http://localhost:5353`,
  rồi chờ Google cập nhật cấu hình và tải lại trang.
- `invalid_client`: kiểm tra ID loại Web application và khởi động lại backend.
- Nút không tải được: kiểm tra mạng và trình chặn nội dung; thử lại bằng Chrome.
- Không mở được tài khoản trong trình duyệt nhúng: mở ứng dụng bằng Chrome ngoài.
- `ERR_CONNECTION_REFUSED`: giữ hai terminal chạy; kiểm tra cổng 5129 và 5353.

## Kiểm tra mã nguồn

```powershell
dotnet test backend/AiGym.Api.Tests --filter FullyQualifiedName~GoogleLoginTests --artifacts-path .artifacts/google-login
node --test test/google_sign_in_bridge_test.cjs
flutter analyze --no-pub
flutter build web --no-pub
```

Các kiểm thử dùng khóa RSA giả lập và verifier giả lập ở HTTP test, không dùng
tài khoản Google thật. Đăng nhập Google hoàn chỉnh chỉ được xác nhận sau khi có
Client ID thật và người dùng hoàn thành màn hình Google.
