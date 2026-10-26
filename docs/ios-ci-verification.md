# Kiểm chứng cấu hình unsigned IPA

Ngày: 25/10/2026. Host: Windows; không có Xcode/CocoaPods/macOS build runner cục bộ.

## Kết quả

| Kiểm tra | Kết quả và phạm vi |
|---|---|
| Flutter SDK | 3.47.5 stable, Dart 3.13.4; đáp ứng pubspec `^3.13.4` |
| Resolve packages | `flutter test` đã chạy pub get; không pub upgrade/chỉnh pubspec hoặc lockfile |
| YAML | Parse bằng PyYAML; validate bằng JSON Schema chính thức tải từ `https://static.codemagic.io/codemagic-schema.json`: đạt |
| Workflow | Có đúng `ios-unsigned-ipa`, artifact khớp output script, không có publishing |
| Bash | `bash -n` cho tất cả script trong YAML và `tool/ci/package_unsigned_ipa.sh`: đạt |
| Python trong YAML | Compile thành công; 6 trường hợp URL và cả hai chế độ giữ/tắt HealthKit chạy đúng trong thư mục tạm |
| XML/plist | Đọc tất cả plist và entitlements iOS bằng `plistlib`: đạt |
| IPA validator | `python -m unittest discover -s tool/ci -p test_validate_ipa.py -v`: 4 test đạt, gồm nhiều subcase lỗi |
| Flutter tests | `flutter test --no-pub test/health_service_test.dart test/api_integration_test.dart`: 9 test đạt |
| Dart analysis | `flutter analyze --no-pub lib/services/health_service.dart lib/screens/settings.dart test/health_service_test.dart`: đạt, No issues found |
| Backend | `dotnet build backend/AiGym.Api --artifacts-path .artifacts/ios-setup`: đạt, 0 warning, 0 error; kiểm tra UserSecretsId mới không phá build |
| Review độc lập | Không phát hiện lỗi critical/important; kiểm tra SPM + CocoaPods bằng cả source Flutter local |

Các thư viện kiểm tra Python được cài trong thư mục tạm Windows, không thêm dependencies vào ứng dụng. Schema chỉ xác nhận cấu trúc cấu hình; không chứng minh tool version tồn tại trên image, quota, mạng, signing hoặc build thực tế.

## Test chưa đạt ngoài phạm vi CI

`flutter test --no-pub test/settings_test.dart` lỗi tại dòng 27: không tìm thấy nhãn `Giọng: Nữ nhẹ nhàng` sau thao tác lưu giọng. Đã chạy lại với nhánh thông báo unsupported-health ban đầu và tái hiện cùng lỗi; source sau đó được phục hồi. Luồng test này thao tác cài đặt giọng, không gọi kết nối Health hoặc optional sideload flag. Không thay UI/logic giọng nói để né lỗi. Vì vậy không tuyên bố toàn bộ test suite đạt.

## Chưa kiểm chứng

- Chọn stable/latest và khả năng compile/link toàn bộ native plugin trên image Codemagic thực tế.
- Chạy `pod install`, `xcodebuild`, `lipo`, `ditto`, ZIP bundle thật và build release arm64.
- Có IPA thật, import vào Sideloadly, tạo profile, ký mã và cài trên iPhone.
- Entitlement `com.apple.developer.healthkit` sau ký bằng Sideloadly. Source entitlement không bảo đảm entitlement sau ký.
- Camera, voice, HealthKit, GPS, bước chân, in PDF và networking trên iPhone thật.
- Hoạt động refresh 7 ngày trên thiết bị/tài khoản người dùng.

Không có bước tự động publish, upload certificate hoặc nhập Apple Account vào CI. Chưa tạo/push GitHub repository hoặc chạy Codemagic trong tài khoản người dùng.

## Danh sách file của thay đổi này

Tạo mới:

- `codemagic.yaml`: workflow macOS, unsigned device release và artifacts.
- `IOS_SIDELOAD_GUIDE.md`: hướng dẫn tiếng Việt và kết quả audit.
- `ios/Podfile`: CocoaPods fallback, iOS 15, cấu hình geolocator foreground.
- `tool/ci/package_unsigned_ipa.sh`: copy bundle nguyên vẹn và tạo ZIP IPA.
- `tool/ci/validate_ipa.py`: kiểm tra CRC, layout, plist/platform/executable.
- `tool/ci/test_validate_ipa.py`: ZIP fixtures hợp lệ và không hợp lệ.
- `.gitattributes`: đảm bảo shell script checkout với LF.
- `docs/superpowers/plans/2026-10-25-ios-unsigned-ipa.md`: kế hoạch và ghi nhận thực hiện.
- `docs/ios-ci-verification.md`: tài liệu này.

Chỉnh sửa:

- `ios/Runner/Info.plist`: thêm quyền nhận dạng giọng nói.
- `ios/Flutter/AppFrameworkInfo.plist`: minimum OS 15.0.
- `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`: include tùy chọn cấu hình Pods trước Generated.xcconfig.
- `lib/services/health_service.dart`: tùy chọn `IOS_DISABLE_HEALTHKIT`, mặc định false, chỉ có tác dụng trên iOS.
- `lib/screens/settings.dart`: hiển thị lý do khi người dùng thử kết nối Health trong bản fallback; formatter chuẩn hóa file.
- `test/health_service_test.dart`: kiểm tra iOS mặc định, fallback iOS và Android không bị ảnh hưởng.
- `.gitignore`: loại local credential, signing material và cache Python.
- `backend/AiGym.Api/appsettings.json`: xóa mật khẩu SMTP thực khỏi source.
- `backend/AiGym.Api/AiGym.Api.csproj`: thêm UserSecretsId để giữ SMTP local bên ngoài repo.

Ngoài repository: mật khẩu SMTP hiện có được chuyển vào .NET User Secrets cục bộ của Windows, không đưa vào log hoặc tài liệu. Không thay đổi file Android hoặc dependencies.
