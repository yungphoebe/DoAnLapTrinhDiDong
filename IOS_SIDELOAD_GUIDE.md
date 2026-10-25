# Cài AI GYM lên iPhone từ Windows bằng Codemagic và Sideloadly

Ngày kiểm tra source và tài liệu: 25/10/2026.

Repository đích của phiên làm việc: `https://github.com/yungphoebe/DoAnLapTrinhDiDong`. Chọn nhánh **`feat/ai-gym-workout-activity`** trên Codemagic. Các ví dụ tạo repo/nhánh main bên dưới áp dụng khi bạn tự tạo repository mới.

Luồng đã cấu hình: **GitHub → Codemagic macOS → IPA release chưa ký → Sideloadly trên Windows → iPhone thật**. Không cần Mac cá nhân, certificate/provisioning profile của bạn hoặc Apple Developer Program trả phí. IPA chưa ký **không cài trực tiếp được**; Sideloadly phải ký lại bằng Apple Account của bạn.

## 1. Kết quả kiểm tra dự án

Thư mục gốc Flutter là thư mục **có `pubspec.yaml`**, hiện nằm lồng bên trong workspace:

```text
DoAnLapTrinhDiDong-feat-ai-gym-workout-activity/   ← workspace đang mở
└── DoAnLapTrinhDiDong-feat-ai-gym-workout-activity/  ← ROOT DỰ ÁN/GITHUB
    ├── codemagic.yaml
    ├── IOS_SIDELOAD_GUIDE.md
    ├── pubspec.yaml / pubspec.lock
    ├── lib/           # màn hình, dịch vụ, model, notification và support
    ├── assets/        # ảnh và font
    ├── ios/           # Runner, Xcode project/workspace, Flutter config, Podfile
    ├── android/       # giữ nguyên cấu hình Android
    ├── web/ / windows/
    ├── backend/       # ASP.NET Core, SQL Server, kiểm thử backend
    ├── database/ / docs/
    ├── test/          # kiểm thử Flutter
    └── tool/ci/       # đóng gói và kiểm tra IPA
```

Hai thư mục trên chưa có `.git` khi kiểm tra. Hướng dẫn này tạo repository tại **root Flutter bên trong**, không đẩy cả thư mục cha. Codemagic cần thấy `codemagic.yaml` ngay ở root repository.

| Mục | Kết quả |
|---|---|
| SDK tại Windows | Flutter **3.47.5 stable**, Dart **3.13.4** |
| Ràng buộc Dart | `^3.13.4`; không hạ SDK hoặc nâng dependencies |
| Phiên bản app | `0.1.0+1` |
| Bundle ID Runner | `com.aigym.aiGym` ở Debug/Profile/Release |
| Bundle ID test | `com.aigym.aiGym.RunnerTests` |
| Deployment target | **iOS 15.0** ở Xcode và Podfile; framework metadata đồng bộ 15.0 |
| Dự án iOS | Có sẵn Runner, AppDelegate/SceneDelegate, scheme và workspace; không cần chạy `flutter create` |
| Dependency native | Đã có tích hợp Swift Package Manager trong Xcode; bổ sung CocoaPods cho plugin cần fallback |
| Ký mã | Workflow dùng `--no-codesign`; không chọn Development Team hoặc cài signing profile |

Đã đọc các manifest/podspec của native plugin được resolve trong `.flutter-plugins-dependencies`. Các plugin iOS đang resolve yêu cầu tối đa iOS 15.0 (plugin `health`); đây là kiểm tra tĩnh, **không thay thế việc compile/link trên macOS**. Các đường dẫn Pub cache của Windows được `flutter pub get` tái tạo trên CI, không commit chúng.

| Dependency | Đánh giá iOS / giới hạn cần thử trên máy thật |
|---|---|
| `camera` → `camera_avfoundation` | Có implementation iOS; quyền camera đã có |
| `camera_windows` | Chỉ đăng ký Windows, không được đưa vào native iOS; giữ nguyên |
| `image_picker` | Có implementation iOS; đã có quyền ảnh/camera |
| `flutter_tts` | Có iOS; giọng tiếng Việt phụ thuộc giọng đã có trên thiết bị |
| `speech_to_text` | Có iOS; đã bổ sung `NSSpeechRecognitionUsageDescription`, microphone đã có |
| `health` | Có HealthKit; yêu cầu iOS 15+, entitlement và quyền đọc/ghi Health |
| `geolocator` | Có implementation Apple; quyền vị trí khi sử dụng đã có; không cam kết GPS nền |
| `pedometer` | Có iOS; đã có `NSMotionUsageDescription`; phụ thuộc cảm biến/quyền thực tế |
| `permission_handler` | Có implementation Apple; luồng bước chân hiện tại chỉ gọi permission activityRecognition trên Android |
| `flutter_local_notifications`, `flutter_timezone`, `timezone` | Plugin có hỗ trợ iOS nhưng code lịch nhắc của dự án chỉ triển khai Android/Chrome, iOS chưa có lịch nhắc hệ thống |
| `shared_preferences`, `package_info_plus`, `device_info_plus` | Có implementation iOS; phiên bản thực tế lấy từ lockfile |
| `printing`, `pdf` | Có đường dùng iOS/Dart; cần thử in/xuất PDF trên máy thật |
| `http`, `flutter_map`, `latlong2` | Dart/network; cần mạng và URL server phù hợp |
| `web` | Chỉ dùng trong các nhánh import dành cho web; không thay thế native iOS |

## 2. Capability và tài khoản miễn phí

Entitlement nguồn hiện có là `com.apple.developer.healthkit = true`. Không thấy APNs `aps-environment`, App Groups, iCloud, Associated Domains, In-App Purchase hoặc Sign in with Apple entitlement trong Runner. Nút đăng nhập mang biểu tượng Apple không chứng minh đã có tích hợp Sign in with Apple thực tế.

**HealthKit không mặc định yêu cầu tài khoản trả phí**: bảng capability hiện tại của Apple đánh dấu hỗ trợ cả Apple Account miễn phí. Tuy nhiên, việc Sideloadly tạo profile/entitlement phù hợp cho app này vẫn phải thử. Build mặc định giữ Apple Health và entitlement nguồn. Không giả định mọi plugin hay capability đều hoạt động sau khi ký lại.

Nếu Sideloadly báo lỗi HealthKit/provisioning, có tùy chọn fallback:

1. Đặt biến Codemagic `IOS_DISABLE_HEALTHKIT=true` trong group `ios_sideload`.
2. Build lại và tải IPA mới.
3. CI chỉ thay nội dung `Runner.entitlements` thành dictionary rỗng trong checkout tạm, đồng thời truyền Dart define tương ứng.
4. Bản iOS đó không gọi API HealthKit và báo đã tắt đồng bộ khi người dùng kết nối Health. Android không bị ảnh hưởng; source entitlement gốc vẫn giữ nguyên.

Mặc định không đặt biến này, hoặc đặt `false`. Không bật fallback chỉ vì dùng tài khoản miễn phí. Khi cần xác minh đầy đủ Apple Health, dùng build mặc định và kiểm tra entitlement sau khi Sideloadly ký. File `.entitlements` trong source không tự chứng minh entitlement của app sau khi ký: IPA unsigned không có chữ ký Apple hợp lệ, và công cụ ký phải cấp `com.apple.developer.healthkit` phù hợp với profile cuối cùng. Nếu công cụ không cấp được, Apple Health có thể không hoạt động dù app chính cài được; dùng fallback để thử phần còn lại.

Không có tính năng đã xác nhận trong source hiện tại bắt buộc mua Apple Developer Program để chạy thử phần app chính. Nếu sau này thêm APNs/Sign in with Apple/iCloud/App Groups, phải đối chiếu capability tương ứng; workflow này không cấu hình các dịch vụ đó. App Store/TestFlight không nằm trong giải pháp này.

## 3. Chuẩn bị backend cho iPhone

Địa chỉ `localhost` trên iPhone là chính iPhone; `10.0.2.2` chỉ là địa chỉ đặc biệt của Android Emulator. Không dùng hai địa chỉ này cho IPA.

1. Kết nối iPhone và Windows cùng Wi-Fi, tránh guest Wi-Fi cô lập thiết bị.
2. Dùng `ipconfig` trên Windows để lấy IPv4 của card Wi-Fi, ví dụ `192.168.1.20`.
3. Từ root Flutter chạy backend cho phép thiết bị trong LAN kết nối:

   ```powershell
   dotnet run --project backend/AiGym.Api --launch-profile http --urls http://0.0.0.0:5129
   ```

4. Nếu Windows Firewall hỏi, cho phép backend trên mạng **Private**. Chỉ mở cổng cần dùng cho mạng nội bộ.
5. Trên Safari iPhone thử `http://192.168.1.20:5129/swagger` trước khi build app.
6. Đặt `API_BASE_URL=http://192.168.1.20:5129` trong Codemagic. Đây là ví dụ: thay bằng IP thật hoặc HTTPS backend của bạn. Không thêm `/api` vì các service đã tự nối `/api/...`.

Workflow kiểm tra biến này tồn tại và loại URL loopback/emulator để tránh build ra app chắc chắn không đăng nhập được. CI không cần truy cập IP LAN của bạn trong lúc compile. Backend vẫn phải chạy và reachable khi sử dụng app. Đổi URL cần build/cài lại IPA; Dart define không phải biến có thể sửa sau khi đã cài.

Phân tích ảnh gọi LM Studio trực tiếp qua `LM_STUDIO_URL`, mặc định hiện tại là `127.0.0.1:1234/v1` nên không hoạt động trên iPhone. Nếu dùng tính năng này, đặt thêm `LM_STUDIO_URL=http://192.168.1.20:1234/v1`, bật phục vụ trong LAN trong LM Studio và cho phép cổng 1234 trên mạng Private. Không public LM Studio ra Internet. AI chat đi qua backend dùng cấu hình LM Studio riêng của backend. Nếu không đặt URL LM Studio, workflow giữ mặc định cũ; tính năng ảnh sẽ cần cấu hình lại trước khi dùng.

`Info.plist` đã có mô tả truy cập LAN và cho phép HTTP phục vụ thử nghiệm. HTTPS hợp lệ vẫn là lựa chọn tốt khi có server. Không cam kết HTTP tới IP LAN hoạt động trên mọi phiên bản iOS; thử URL bằng Safari và kiểm tra log nếu ATS chặn. Chấp nhận quyền Local Network khi iPhone hỏi.

## 4. Đưa source lên GitHub

Source trước đây có mật khẩu SMTP trong `backend/AiGym.Api/appsettings.json`. Đã xóa giá trị khỏi file này và giữ cấu hình máy Windows bằng .NET User Secrets ngoài repository, với `UserSecretsId=aigym-local-development`. Nếu mật khẩu đã từng được chia sẻ/commit, thu hồi và tạo mật khẩu mới ở nhà cung cấp email; xóa file hiện tại không xóa lịch sử Git.

Backend Development tự đọc user secrets. Trên máy khác, cấu hình `Smtp__Password` bằng biến môi trường hoặc .NET User Secrets cục bộ; không đặt giá trị trong source. Không đưa secret SMTP lên Codemagic vì build Flutter không cần nó. Quên mật khẩu qua email cần secret hợp lệ; các máy mới phải tự cấu hình.

JWT key và admin seed đang là dữ liệu demo phát triển đã có trong backend; không coi chúng là thông tin an toàn cho môi trường public. Dùng secret bên ngoài source và tài khoản riêng trước khi public backend. Không đưa token thật/production key vào Git.

1. Tạo repository GitHub riêng tư, ví dụ `ai-gym`. Có thể dùng GitHub Desktop nếu chưa quen Git.
2. Mở PowerShell **tại thư mục chứa `pubspec.yaml`**, không phải thư mục cha:

   ```powershell
   Get-Item pubspec.yaml, codemagic.yaml
   git init
   git branch -M main
   git status --short
   git add .
   git diff --cached --stat
   ```

3. Kiểm tra phần đã stage. `.gitignore` đã loại `build/`, `.dart_tool/`, `Pods`, `.env`, `.p12`, `.p8`, `.mobileprovision`, `.ipa`, user secret và khóa notification cục bộ. Nếu file nhạy cảm đã được Git track từ trước, `.gitignore` không tự bỏ track; bỏ chúng khỏi index và xử lý lịch sử nếu cần. Không commit password, token, certificate hoặc generated config chứa đường dẫn máy.
4. Khi phần stage đã đúng, thực hiện (thay URL ví dụ):

   ```powershell
   git commit -m "Configure unsigned iOS IPA build"
   git remote add origin https://github.com/YOUR_USER/ai-gym.git
   git push -u origin main
   ```

5. Kiểm tra trên GitHub: `codemagic.yaml`, `pubspec.yaml`, `ios/`, `lib/`, `assets/`, `tool/ci/` phải xuất hiện ở root. Commit `pubspec.lock`. Không cần upload build output.

Các lệnh commit/push trên là thao tác bạn tự thực hiện; quá trình cấu hình này chưa tạo repository, chưa commit hoặc push hộ bạn.

## 5. Tạo tài khoản và kết nối Codemagic

1. Mở [Codemagic](https://codemagic.io/), chọn Sign up và đăng nhập bằng GitHub.
2. Ưu tiên tài khoản **Personal** và kiểm tra quota miễn phí trước khi build. Tại thời điểm đối chiếu, Codemagic công bố 500 phút macOS M2/tháng cho tài khoản cá nhân; điều kiện có thể thay đổi. Không cần bật thanh toán tự động để làm theo hướng dẫn.
3. Chọn Add application, chọn GitHub và cấp quyền truy cập **repository cần build**. Repository private cần được cấp quyền rõ ràng cho tích hợp.
4. Chọn repo và nhánh đã chứa file YAML, sử dụng cấu hình `codemagic.yaml` (nếu đang ở Flutter Workflow Editor, chuyển sang YAML).
5. Trong Environment variables của ứng dụng/nhóm, tạo group **`ios_sideload`** và cho ứng dụng dùng group này. Workflow đã khai báo group theo đúng tên đó.
6. Thêm `API_BASE_URL` bằng URL backend từ mục 3. Tùy nhu cầu thêm `LM_STUDIO_URL`. Chỉ thêm `IOS_DISABLE_HEALTHKIT=true` khi thực sự cần fallback; nếu không, bỏ qua hoặc đặt `false`.
7. Không nhập Apple Account, mật khẩu Apple, certificate, provisioning profile, App Store Connect API key hoặc signing group vào Codemagic. URL được nhúng trong app nên không phải chỗ chứa secret.

## 6. Chạy workflow và tải IPA

1. Chọn **Start new build**.
2. Chọn nhánh `main` (hoặc nhánh bạn đã push) và workflow **`ios-unsigned-ipa`**.
3. Bấm Start new build và đọc từng bước log.

| Bước workflow | Công việc |
|---|---|
| Máy build | `mac_mini_m2`, tối đa 60 phút, Flutter stable, Xcode latest, CocoaPods có sẵn từ image |
| Check tools and iPhone backend URL | Ghi phiên bản tool, kiểm tra URL backend; không kiểm tra tài khoản Apple |
| Get Flutter packages | `flutter pub get`; tôn trọng lockfile, không chạy pub upgrade |
| Prepare free-account build and install pods | Mặc định giữ HealthKit; áp dụng fallback nếu được bật; sinh config Flutter với `--config-only`, chạy `pod install` |
| Build unsigned iOS release for physical devices | `flutter build ios --release --no-codesign` với các Dart define cho URL và fallback |
| Package and validate unsigned IPA | Tìm `build/ios/iphoneos/Runner.app`; kiểm tra plist, executable arm64 và quyền execute; copy bằng `ditto`, ZIP giữ symlink và kiểm tra nội dung |
| Artifacts | Lưu IPA, SHA-256 và log Xcode; không có bước publish |

Khi build thành công, mở trang build → **Artifacts**, tải:

```text
build/ios/ipa/FlutterApp-unsigned.ipa
build/ios/ipa/FlutterApp-unsigned.ipa.sha256
```

IPA xuất hiện riêng trong Artifacts; checksum/log có thể nằm trong ZIP artifacts bổ sung của Codemagic. Bên trong IPA phải có:

```text
Payload/
└── Runner.app/
    ├── Info.plist
    ├── Runner
    ├── Frameworks/...
    └── ... toàn bộ bundle từ Xcode
```

Không đổi tên `.app` thành `.ipa`, không ZIP thêm thư mục cha `build/` và không dùng output `iphonesimulator`. Script kiểm tra ZIP CRC, plist, platform iPhoneOS, Bundle ID, minimum OS và executable. Kiểm tra cấu trúc **chưa xác nhận chữ ký hoặc khả năng cài**. Có thể xem ZIP bằng 7-Zip trên Windows nhưng không giải nén/nén lại để cài vì dễ mất permissions hoặc symlink.

## 7. Cài Sideloadly và chuẩn bị iPhone

1. Tải từ [trang Sideloadly chính thức](https://sideloadly.io/), chọn bản Windows phù hợp (thường 64-bit).
2. Theo yêu cầu hiện tại của Sideloadly, dùng **iTunes và iCloud bản desktop/web do Apple cung cấp**, theo liên kết trên trang Sideloadly; trang này yêu cầu bỏ bản Microsoft Store nếu đang dùng. Không gỡ phần mềm của bạn tự động; kiểm tra hướng dẫn và dữ liệu đồng bộ trước khi thay phiên bản.
3. Cài driver Apple cần thiết qua các bộ cài trên, sau đó cài/mở Sideloadly. Nếu máy chưa nhận iPhone, khởi động lại Windows.
4. Kết nối iPhone bằng cáp USB có truyền dữ liệu, mở khóa iPhone, chọn **Trust This Computer / Tin cậy máy tính này**, nhập mật mã trên iPhone.
5. Kiểm tra thiết bị hiện trong iTunes và danh sách iDevice của Sideloadly. Dùng USB cho lần đầu.

## 8. Import, ký và cài bằng Apple Account miễn phí

1. Chọn đúng iPhone trong Sideloadly.
2. Kéo `FlutterApp-unsigned.ipa` vào ô IPA hoặc bấm chọn file. Đây là lúc thử import thực tế; chưa được kiểm chứng trong phiên làm việc trên Windows này.
3. Dùng chế độ cài bằng **Apple ID / Apple Account sideload**, không dùng chế độ Normal Install yêu cầu IPA đã ký.
4. Nhập Apple Account của bạn **chỉ trong Sideloadly trên Windows**. Khi công cụ yêu cầu, nhập mật khẩu và mã 2FA trực tiếp trong giao diện công cụ. Không ghi chúng vào source, GitHub, Codemagic, YAML hoặc gửi vào chat/log.
5. Nếu Bundle ID trùng hoặc profile không tạo được, dùng tùy chọn đổi Bundle ID trong Sideloadly, ví dụ `com.tenban.aigym.personal`; chọn một ID ổn định và giữ lại cho các lần refresh.
6. Bấm **Start**, chờ ký và cài hoàn tất. Để thiết bị mở khóa nếu công cụ yêu cầu; đọc log lỗi nếu có.
7. Trên iPhone vào **Settings → General → VPN & Device Management**, chọn developer profile tương ứng và Trust/Verify nếu hệ thống yêu cầu. Có thể cần Internet để xác minh.
8. Với iOS 16 trở lên: vào **Settings → Privacy & Security → Developer Mode**, bật, khởi động lại và xác nhận sau khi máy lên. Nếu mục chưa xuất hiện, thực hiện lần cài developer app qua USB trước, rồi kiểm tra lại; tên/vị trí có thể khác theo iOS.
9. Mở app. Thử đăng nhập backend, camera, microphone/nhận dạng giọng nói, ảnh, vị trí, chuyển động và Health riêng từng tính năng. Cấp quyền phù hợp; cài được app không đảm bảo tất cả plugin đã hoạt động.

Release Flutter dùng AOT nên không cần bật JIT để chạy app này. Không chọn tùy chọn sửa minimum iOS nhằm ép chạy trên thiết bị dưới iOS 15; plugin vẫn có thể crash.

## 9. Hết hạn sau khoảng 7 ngày và refresh

Theo Apple, profile phát triển miễn phí hết hạn sau 7 ngày; tài khoản miễn phí còn có giới hạn App ID/thiết bị và tối đa 3 app đang cài trên mỗi thiết bị. Sideloadly cũng mô tả thời hạn 7 ngày cho tài khoản miễn phí.

- **Refresh thủ công:** mở Sideloadly trên Windows, kết nối iPhone, chọn lại cùng IPA/Apple Account/Bundle ID và bấm Start trước khi hết hạn. Không cần build lại Codemagic mỗi tuần nếu source và URL không đổi.
- **Auto refresh:** có thể bật daemon auto-refresh của Sideloadly theo hướng dẫn công cụ. Windows và daemon phải đang chạy, iPhone phải được ghép đôi và reachable. Không coi auto-refresh là đảm bảo khi máy tắt hoặc thiết bị không kết nối.
- Có thể dùng Wi-Fi sau lần ghép đôi USB thành công, cùng mạng và đủ dịch vụ Apple/Bonjour; USB là cách khắc phục đầu tiên nếu refresh thất bại.
- Nếu đã hết hạn, ký/cài lại. Giữ cùng tài khoản và Bundle ID thường cho phép cập nhật tại chỗ; sao lưu dữ liệu quan trọng, không cam kết dữ liệu được giữ nếu đổi ID/profile hoặc gỡ app.

## 10. Lỗi thường gặp

| Triệu chứng | Cách xử lý |
|---|---|
| Không có workflow | YAML phải ở root GitHub, đã commit/push, chọn đúng branch và chế độ YAML |
| Group `ios_sideload` không tồn tại | Tạo group, cấp quyền cho application và thêm `API_BASE_URL` |
| Check backend URL thất bại | Không bỏ trống; dùng URL gốc `http(s)://host:port`, không dùng localhost, 10.0.2.2, credentials hoặc query |
| Dart SDK không thỏa `^3.13.4` | Xem `flutter --version` trong CI; dùng stable có Dart đủ mới hoặc pin đúng stable 3.47.5 nếu image hỗ trợ; không hạ ràng buộc SDK để né lỗi |
| Không tìm thấy Podfile/config Flutter | Kiểm tra đã push `ios/Podfile` và xcconfig; `flutter pub get` phải chạy trước config-only/pod install |
| Pod cần minimum iOS cao hơn | Kiểm tra phiên bản lockfile và log pod; hiện source/podspec đã đối chiếu iOS 15. Không tự pub upgrade |
| Lỗi SPM/CocoaPods/link Xcode | Dự án dùng SPM kèm fallback CocoaPods; xem dependency cụ thể trong log. Xác nhận log Xcode/Flutter version trước khi thay version; không xóa tích hợp SPM hàng loạt |
| Không có Runner.app/arm64 | Bước build phải thành công cho device; không dùng `--simulator` hoặc artifact simulator |
| IPA không hợp lệ | Đọc lỗi `validate_ipa.py`; đúng root Payload, app đầy đủ và ZIP không hỏng. Tải lại artifact nguyên gốc |
| Sideloadly không nhận iPhone | USB dữ liệu, mở khóa/Trust, kiểm tra driver iTunes/iCloud desktop, Apple Mobile Device service |
| Lỗi đăng nhập/2FA | Kiểm tra bằng giao diện Sideloadly và tài khoản Apple; không đưa mật khẩu vào pipeline |
| Đạt giới hạn App ID hoặc 3 app | Giữ cùng Bundle ID, bỏ app thử không cần thiết hoặc chờ giới hạn App ID được reset; không tạo ID mới liên tục |
| Entitlement/profile không hợp lệ | Kiểm tra Bundle ID và log ký. Nếu lỗi chỉ ở HealthKit, thử fallback `IOS_DISABLE_HEALTHKIT=true` rồi build lại; bản đó mất đồng bộ Health |
| Untrusted Developer / Developer Mode | Trust profile và bật Developer Mode theo mục 8; kiểm tra Internet/ngày giờ thiết bị |
| App không mở sau một tuần | Ký/cài lại hoặc cấu hình refresh, không chỉ tải lại IPA chưa ký |
| Đăng nhập báo không kết nối | Thử swagger bằng Safari, kiểm tra cùng Wi-Fi, IP Windows, bind `0.0.0.0`, firewall Private, Local Network và URL đã nhúng |
| AI ảnh không kết nối | Cấu hình `LM_STUDIO_URL` cho iPhone và cho phép LM Studio nghe trong LAN; URL localhost mặc định không dùng được trên điện thoại |
| Voice crash khi xin quyền | Đảm bảo IPA mới chứa cả NSSpeechRecognitionUsageDescription và NSMicrophoneUsageDescription |
| Không có lịch nhắc iOS | Giới hạn code hiện có; plugin có hỗ trợ iOS nhưng phần native notification của app hiện chỉ triển khai Android |
| Email reset password lỗi trên máy khác | Cấu hình SMTP bằng biến môi trường/User Secrets ngoài repo; mật khẩu không còn nằm trong appsettings.json |

## 11. Phạm vi đã và chưa kiểm chứng

Đã kiểm tra tĩnh cấu trúc Flutter/iOS, manifest plugin trong Pub cache, deployment target và capability. Có kiểm thử tự động cho bộ kiểm tra cấu trúc IPA bằng ZIP giả lập và cho tùy chọn HealthKit (iOS bị tắt theo flag, Android giữ nguyên). Đây không phải IPA thực tế.

Máy hiện tại chạy Windows nên **chưa chạy Xcode, CocoaPods, Swift compilation/linking, build arm64 thật, đóng gói bundle thật bằng ditto/zip trên macOS, import IPA vào Sideloadly, ký bằng Apple Account hoặc cài/chạy trên iPhone**. Không có artifact IPA thật cho đến khi Codemagic build thành công. Các phiên bản tool `stable/latest` được ghi vào log; khả năng tương thích cuối cùng phải xác nhận ở lần CI đầu tiên.

Xem kết quả kiểm tra cục bộ và giới hạn phát hiện thêm trong `docs/ios-ci-verification.md`.

## 12. Nguồn đối chiếu

- [Codemagic: unsigned workflow và macOS toolchain](https://docs.codemagic.io/yaml-quick-start/first-signed-build/)
- [Codemagic: YAML, repository root, artifact và schema](https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/)
- [Codemagic: giá và quota miễn phí](https://docs.codemagic.io/billing/pricing/)
- [Apple: giới hạn Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Apple: bảng supported capabilities, gồm HealthKit](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [Apple: Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
- [Sideloadly: tải, yêu cầu Windows, ký miễn phí và refresh](https://sideloadly.io/)
- [Plugin speech_to_text: quyền iOS](https://pub.dev/packages/speech_to_text)
- [Plugin health: cấu hình iOS](https://pub.dev/packages/health)
