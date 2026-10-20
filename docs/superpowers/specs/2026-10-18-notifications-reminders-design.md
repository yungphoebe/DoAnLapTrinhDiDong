# Thông báo và nhắc nhở trên Android, Chrome

## Mục tiêu đã được duyệt trong hội thoại

Có danh sách thông báo theo tài khoản; nhắc tập, uống nước và báo cáo tuần theo
cài đặt. Tắt thì ngừng nhắc; chạm mở đúng màn hình. Hỗ trợ Android bằng lịch
nhắc cục bộ và Chrome bằng Web Push từ backend, không yêu cầu dự án Firebase.

Đây là bổ sung hệ thống thông báo, không phải chỉ thay nội dung nút chuông.
Công tắc hiện tại chỉ tồn tại trong bộ nhớ, chưa có lịch nhắc hoặc inbox.

## Quyết định kiến trúc

- SQL Server lưu cài đặt theo tài khoản và danh sách thông báo đã đến hạn.
- Backend có BackgroundService tính lịch đến hạn, ghi inbox và gửi Web Push.
- Android đặt lịch cục bộ sau khi tải/lưu cài đặt; hệ điều hành phát thông báo
  khi ứng dụng ở nền. Không gửi thêm push Android để tránh phát hai lần.
- Chrome dùng service worker riêng để nhận push và mở/focus ứng dụng khi chạm.
- Các adapter nền tảng tách khỏi controller, giúp kiểm thử lịch và giao diện
  mà không phụ thuộc plugin native hoặc dịch vụ push thật.
- Không triển khai FCM: phương án đó cần thêm tài khoản/dự án và cấu hình
  Firebase trong khi backend hiện có đủ để gửi Web Push tiêu chuẩn.

## Cài đặt và lịch nhắc

Giữ các công tắc nhắc tập, uống nước, báo cáo tuần ở vị trí hiện có. Bổ sung
trường chọn lịch ngay tại các mục đó. Các mục giọng nói, động lực và rung không
bị biến thành một hệ thống mới trong phạm vi này.

| Loại | Lịch chỉnh được | Giá trị ban đầu khi bật |
|---|---|---|
| Tập luyện | Các ngày trong tuần và giờ | Hằng ngày lúc 18:00 |
| Uống nước | Giờ bắt đầu/kết thúc và khoảng cách 60–240 phút | 09:00–21:00, mỗi 120 phút |
| Báo cáo tuần | Thứ trong tuần và giờ | Chủ nhật lúc 20:00 |

- Tài khoản chưa có cài đặt bắt đầu với ba loại nhắc tắt; không tự phát thông
  báo trước khi người dùng bật và xử lý yêu cầu quyền trên thiết bị.
- Múi giờ lấy từ thiết bị dưới dạng IANA, lưu cùng cài đặt. Tính lịch theo giờ
  địa phương, lưu các thời điểm tuyệt đối ở UTC. Đồng bộ khi đổi múi giờ/mở app.
- Đổi giờ hoặc ngày phải thay lịch cũ, không cộng thêm các lịch song song.
- Nhắc tập lưu ngay như công tắc hiện tại. Uống nước/báo cáo tuần cùng lịch tương
  ứng chỉ áp dụng khi bấm Lưu ở Cài đặt AI Coach; thoát không lưu thì bỏ thay đổi.
- Thay đổi được xác nhận thành công khi backend đã lưu. Nếu lỗi, giữ cài đặt
  đã xác nhận và báo có thể thử lại; không hiển thị đã lưu thành công giả.
- Tắt trên thiết bị đang thao tác hủy lịch loại đó ngay. Nếu lưu backend lỗi,
  vẫn giữ chặn nhắc cục bộ cho loại đó và hiển thị trạng thái cần thử lưu lại.
- Backend dừng tạo/gửi nhắc tương lai sau khi nhận cài đặt tắt. Thông báo cũ
  trong inbox vẫn giữ. Không phát bù các mốc đã bị tắt.

### Đồng bộ giữa thiết bị

Cài đặt và inbox dùng chung theo tài khoản. Android đồng bộ và thay lịch khi
mở/resume ứng dụng hoặc lưu cài đặt trên máy đó. Vì Android phát lịch cục bộ,
việc tắt từ Chrome không thể bảo đảm hủy tức thời lịch trên một Android đang
đóng/offline; máy Android áp dụng ở lần đồng bộ kế tiếp. Không tuyên bố có khả
năng thu hồi thông báo đã được dịch vụ push nhận hoặc đã hiện trên hệ điều hành.

## Danh sách và màn hình đích

- Nút chuông ở Trang chủ mở /notifications; có số chưa đọc.
- Danh sách lấy API, mới nhất trước, phân trang 20 bản ghi/lần, kéo tải lại,
  hiển thị loại, nội dung, thời gian và trạng thái đọc/chưa đọc.
- Có đánh dấu một thông báo đã đọc khi chạm và Đánh dấu tất cả đã đọc.
- Loading, rỗng, lỗi có nút thử lại; lỗi đánh dấu đọc không chặn mở màn hình.
- /workouts: lịch tập/chi tiết nhắc tập; nếu chưa có lịch thật thì thông báo
  chưa có lịch, không biến các bài tập minh họa thành lịch cá nhân đã lưu.
- /water: màn hình uống nước, hiển thị lịch nhắc đã cấu hình và đường dẫn chỉnh
  cài đặt. Không thêm số ml đã uống giả hoặc nhật ký nước ngoài phạm vi yêu cầu.
- /weekly-report: tuần được nhắc và dữ liệu báo cáo nếu có; hiện dự án chưa có
  nhật ký tập trong database nên hiển thị Chưa có dữ liệu cho tuần này.
- Nội dung báo cáo chỉ là nhắc mở báo cáo, không khẳng định báo cáo đã có số liệu.
- Chạm trong danh sách, thông báo Android hoặc Chrome dùng cùng bộ định tuyến
  theo loại, không nhận URL tùy ý từ payload.
- Mở app từ thông báo phải đợi khôi phục phiên trước khi điều hướng. Hết phiên
  thì mở đăng nhập và tiếp tục đích sau đăng nhập nếu đúng tài khoản; thông báo
  của tài khoản khác không mở dữ liệu riêng tư của tài khoản trước.

## Database và hợp đồng API

- ReminderSettings: UserId duy nhất, bật/tắt từng loại, lịch và múi giờ,
  UpdatedAt, phiên bản cài đặt để lịch cũ không ghi đè lịch mới.
- UserNotification: ID, UserId, Kind, tiêu đề/nội dung, ScheduledAtUtc, CreatedAt,
  ReadAt, ngày/tuần liên quan và khóa sự kiện duy nhất theo người/loại/mốc nhắc.
- WebPushSubscription: UserId, endpoint duy nhất, khóa công khai/xác thực của
  subscription, thời gian cập nhật và phiên bản đăng ký. Không lưu JWT trong worker.
- Thêm bảng bằng cơ chế nâng cấp bổ sung của dự án; giữ dữ liệu đã có.
- GET/PUT /api/notifications/settings: đọc/lưu cài đặt của tài khoản hiện tại.
- GET /api/notifications?page=1&pageSize=20: items, hasMore, unreadCount.
- PUT /api/notifications/{id}/read và PUT /api/notifications/read-all: thao tác
  lặp an toàn, chỉ tác động dữ liệu của chính mình.
- GET /api/notifications/push-key, POST/DELETE /api/notifications/subscriptions:
  đăng ký/hủy trình duyệt hiện tại. ID người dùng chỉ lấy từ JWT.
- Validate enum, ngày, giờ, khoảng cách và múi giờ; giới hạn kích thước body.
- Endpoint subscription chỉ được trỏ tới host push Chrome đã cho phép trong
  cấu hình, dùng HTTPS và không theo redirect để tránh backend gọi URL tùy ý.

## Scheduler và Web Push

- Scheduler kiểm tra lịch khoảng mỗi phút, dùng đồng hồ có thể thay thế trong
  test. Mốc tiếp theo được tính từ cài đặt thay vì cộng cố định 24 giờ vào UTC.
- Ghi sự kiện bằng khóa duy nhất để nhiều vòng chạy/khởi động lại không tạo
  thông báo trùng. Khi server gián đoạn, chỉ lưu các mốc bỏ lỡ trong 24 giờ gần
  nhất; mỗi loại chỉ push mốc gần nhất còn mới, không dồn nhiều nhắc cùng lúc.
- Việc gửi kiểm tra lại cài đặt còn bật/phiên bản phù hợp và subscription còn
  hiệu lực. Có retry có giới hạn cho lỗi tạm thời; xóa endpoint trả 404/410.
- Mỗi sự kiện có tag ổn định để push retry không tạo nhiều thẻ giống nhau.
- VAPID tạo một lần bằng tiện ích của dự án, khóa riêng lưu ngoài source,
  không đưa vào Git/log/API. Backend dùng lại khóa sau khi khởi động lại.
- Tài liệu chạy dùng cổng Chrome cố định để origin/subscription ổn định.
- Chrome cần quyền thông báo, service worker và secure context (HTTPS hoặc
  localhost). Backend cần chạy và có mạng để gửi; trình duyệt/OS có quyền trì
  hoãn hoặc chặn nền. Không cam kết phát khi người dùng force-stop trình duyệt.

## Android, quyền và đăng xuất

- Dùng adapter thông báo cục bộ, timezone và receiver khôi phục lịch sau reboot
  theo khả năng plugin chính thức được chọn ở bước kế hoạch triển khai.
- Yêu cầu quyền từ thao tác bật nhắc của người dùng, không tự hỏi khi mở app.
  Nếu bị từ chối, hiển thị Nhắc trên thiết bị chưa được cấp quyền và cho mở
  cài đặt hệ thống; inbox vẫn hoạt động.
- Dùng lịch không yêu cầu quyền exact alarm đặc biệt. Hệ điều hành có thể trì
  hoãn vì tiết kiệm pin; không trình bày đây là lịch báo thức chính xác tuyệt đối.
- Hủy các ID lịch thuộc loại nhắc khi tắt; không hủy nhầm loại còn bật.
- Đăng xuất thực sự xóa phiên hiện có qua AuthService, hủy lịch Android, gỡ
  subscription trình duyệt và xóa cache. Không chỉ điều hướng về màn đăng nhập.
- Worker/browser lưu dấu phiên đang hoạt động để bỏ qua push muộn của tài khoản
  cũ sau logout; thay tài khoản phải đăng ký lại và tải đúng inbox/cài đặt.

## Kiểm thử và nghiệm thu

1. Lưu/mở lại cài đặt, danh sách thông báo và trạng thái đọc theo hai tài khoản;
   tài khoản khác không đọc/sửa thông báo hoặc subscription không thuộc mình.
2. Đồng hồ giả: đúng các ngày/giờ, giới hạn uống nước, tuần, đổi múi giờ, sửa
   lịch, bật/tắt; chạy scheduler lặp không tạo sự kiện trùng.
3. SQL Server: nâng cấp database có sẵn, khóa sự kiện, scheduler đồng thời,
   đọc lại bằng DbContext mới; dùng database test riêng.
4. Adapter fake: tắt hủy đúng ID, sửa lịch thay lịch cũ, logout hủy hết,
   quyền bị từ chối/lỗi schedule có trạng thái rõ ràng.
5. Widget: danh sách/phân trang/rỗng/lỗi, lưu và hủy sửa cài đặt, đánh dấu đọc,
   chạm mỗi loại mở đúng màn hình, khôi phục phiên và đổi tài khoản.
6. Chrome: build web, đăng ký service worker, xin quyền, Web Push thực tế trên
   localhost với origin cố định, nhận khi đóng tab, click mở/focus đúng màn hình.
7. Android: build APK và kiểm tra trên emulator/thiết bị khi có sẵn; thử app nền,
   khởi động từ thông báo và tắt lịch. Nếu không có thiết bị phải ghi rõ giới hạn
   kiểm chứng, không dùng test fake để khẳng định thông báo hệ thống đã chạy.
8. Chạy analyzer, test backend/Flutter và build phù hợp. Báo lại riêng 5 test
   demo/auth/shell đã thất bại trước công việc này nếu vẫn còn lỗi.

## Nguồn kỹ thuật

- MDN: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation
- MDN Push API: https://developer.mozilla.org/en-US/docs/Web/API/Push_API
- Android alarms: https://developer.android.com/develop/background-work/services/alarms

## Ngoài phạm vi

Không thêm Firebase, SMS/email nhắc, phân tích sức khỏe mới hoặc số liệu tập
luyện giả. Luồng kết nối PT/Bạn tập có bản thiết kế riêng đang chờ duyệt; công
việc thông báo không được coi là đã triển khai luồng kết nối đó.
