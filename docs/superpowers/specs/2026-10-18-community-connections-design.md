# Kết nối PT và bạn tập bằng tài khoản thật

## Mục tiêu đã thống nhất

Thay hồ sơ minh họa bằng tài khoản thật có hồ sơ PT hoặc Bạn tập. Người dùng
gửi/hủy lời mời, xem trạng thái; người nhận đồng ý/từ chối. Database là nguồn
trạng thái chung cho hai tài khoản và khi mở lại ứng dụng.

## Phương án

Chọn bảng hồ sơ cộng đồng riêng và một bản ghi kết nối cho mỗi cặp tài khoản.
Cách này giữ luồng đăng nhập hiện có, cho phép người dùng chủ động công khai
hồ sơ và ngăn lời mời trùng ở cả hai chiều.

Hai phương án khác không chọn: thêm trực tiếp mọi trường công khai vào tài
khoản Identity (trộn hồ sơ tìm người với xác thực); lưu mỗi lần gửi thành bản
ghi độc lập (cần thêm quy tắc để ngăn lời mời đang chờ trùng/hai chiều).

## Hồ sơ thật

- Trong tab Tìm PT / Bạn tập có nút Hồ sơ kết nối của tôi để tạo/sửa hồ sơ.
- Tên lấy từ FullName của tài khoản, không cho nhập tên người khác.
- Trường bắt buộc: loại PT/Bạn tập, thành phố, ít nhất một mục tiêu.
- Thành phố dùng ba lựa chọn hiện có: Hà Nội, TP. Hồ Chí Minh, Đà Nẵng.
- Mục tiêu dùng ba lựa chọn hiện có: Giảm cân, Tăng cơ, Giữ dáng.
- Giới thiệu ngắn, lịch rảnh và chi tiết là văn bản tùy chọn có giới hạn độ dài.
- Avatar dùng ảnh mặc định theo loại hồ sơ; không thêm tải ảnh trong phạm vi này.
- Hồ sơ PT là loại người dùng tự chọn; không hiển thị huy hiệu xác minh.
- Chỉ tài khoản đã lưu hồ sơ xuất hiện trong danh sách; không hiển thị chính mình.
- Bộ lọc thành phố/mục tiêu dùng API, danh sách phân trang 20 hồ sơ/lần.
- Không tạo tài khoản giả hoặc tự động công khai các tài khoản hiện có.

## Luồng lời mời

| Trạng thái | Người gửi | Người nhận |
|---|---|---|
| Chưa có | Gửi lời mời | Gửi lời mời |
| Đang chờ | Xem trạng thái, Hủy | Đồng ý hoặc Từ chối |
| Đã kết nối | Xem Đã kết nối | Xem Đã kết nối |
| Đã hủy / Đã từ chối | Xem kết quả, có thể gửi lại | Xem kết quả, có thể gửi lại |

Gửi lời mời yêu cầu cả hai tài khoản có hồ sơ cộng đồng. Không gửi cho chính
mình. Khi đã có lời mời đang chờ ở chiều ngược lại, API trả lời mời đó để
người nhận quyết định; không tự động đồng ý. Kết nối không phụ thuộc loại hồ sơ.

Trong tab tìm người có các mục Tìm người, Lời mời nhận, Đã gửi và Đã kết nối.
Lời mời không bị ẩn bởi bộ lọc thành phố/mục tiêu. Danh sách nhận/đã gửi hiển
thị trạng thái gần nhất của mỗi cặp, kể cả đã hủy/từ chối. Danh sách kết nối
chỉ hiển thị các cặp đã đồng ý.

Không thêm chat, thông báo đẩy, hủy kết nối đã được chấp nhận, chặn tài khoản
hoặc toàn bộ lịch sử từng lần gửi trong phạm vi này.

## Dữ liệu và bảo vệ trạng thái

- CommunityProfile: UserId duy nhất, loại hồ sơ, thành phố, mục tiêu, giới thiệu,
  lịch rảnh, chi tiết và UpdatedAt; liên kết đến tài khoản Identity.
- CommunityConnection: cặp tài khoản chuẩn hóa có khóa duy nhất, người gửi,
  người nhận, trạng thái Pending/Accepted/Rejected/Cancelled, mã lời mời hiện
  tại, thời gian tạo/cập nhật và phiên bản chống cập nhật xung đột.
- Khóa cặp là SHA-256 của hai ID sắp thứ tự, mã hóa có độ dài từng phần để
  tránh nhập nhằng; không dùng index ghép hai cột nvarchar(450).
- Gửi lại sau hủy/từ chối tạo mã lời mời mới trên cùng cặp. Thao tác bằng mã
  lời mời cũ không được tác động tới lời mời mới.
- Mọi endpoint yêu cầu JWT; ID người thao tác lấy từ JWT, không nhận từ body.
- Chỉ người gửi hủy; chỉ người nhận đồng ý/từ chối. Người ngoài không được
  xem hoặc thay đổi lời mời. Kiểm tra quyền trước khi xử lý thao tác lặp.
- Gửi lặp hoặc xử lý lại cùng quyết định trả trạng thái hiện tại, không tạo
  thêm kết nối. Quyết định trái với trạng thái đã chốt trả 409 kèm trạng thái
  mới nhất; frontend tải lại. Cập nhật có kiểm tra phiên bản để hai quyết định
  đồng thời không cùng thành công.
- Thêm bảng vào database hiện có theo cơ chế nâng cấp bổ sung đang dùng trong
  dự án; không xóa tài khoản, bài viết, lượt thích hoặc dữ liệu cũ.

## Hợp đồng API dự kiến

- GET/PUT /api/community/profile: đọc/lưu hồ sơ của tài khoản hiện tại.
- GET /api/community/profiles: lọc và phân trang hồ sơ, kèm trạng thái kết nối
  và vai trò người gửi/người nhận của người đang đăng nhập.
- GET /api/community/connections?view=incoming|outgoing|accepted&page=1&pageSize=20:
  lời mời/kết nối của mình, kèm tên và hồ sơ công khai của đối phương.
- POST /api/community/connections với recipientUserId: gửi hoặc trả cặp hiện có.
- PUT /api/community/connections/{invitationId} với action=cancel|accept|reject:
  chuyển trạng thái đúng quyền và trả bản ghi mới nhất.
- Danh sách có items/page/pageSize/hasMore; kết quả thao tác trả trạng thái
  chuẩn từ server. Thiếu hồ sơ trả 409 với hướng dẫn tạo hồ sơ; dữ liệu sai
  trả 400; không tồn tại trả 404; sai quyền trả 403.
- API không công khai email, token hoặc các trường Identity riêng tư.

## Flutter

Tách model/API/controller kết nối và nội dung tab tìm người thành file riêng,
giữ luồng bảng tin và lượt thích hiện có. Xóa dữ liệu hồ sơ giả và tập ID lời
mời chỉ lưu trong State. Tải dữ liệu khi mở tab, kéo để tải lại và có Tải thêm.

Nút thao tác bị khóa trong lúc gửi. Chỉ cập nhật theo phản hồi thành công của
server; thất bại giữ trạng thái đã xác nhận và cho thử lại. Có loading/rỗng/lỗi
cho hồ sơ và lời mời. Khi đổi tài khoản, bỏ cache của phiên cũ và bỏ qua phản
hồi cũ. Mở lại app dùng JWT đã lưu để tải lại hồ sơ và trạng thái từ API.

## Kiểm chứng hoàn thành

1. Hai tài khoản A/B tạo hồ sơ, tìm được nhau; A gửi, A thấy đang chờ, B thấy
   lời mời nhận; B đồng ý và cả hai thấy đã kết nối khi tải lại/đăng nhập lại.
2. B từ chối hoặc A hủy: trạng thái đúng ở hai phía; gửi lại có mã mới.
3. Gửi lặp và gửi đồng thời hai chiều không tạo cặp trùng; không tự kết nối.
4. Chỉ đúng người được hủy/nhận lời/từ chối; không thao tác lên chính mình,
   không dùng ID giả hoặc thao tác bằng mã lời mời cũ sau khi gửi lại.
5. Hai quyết định đồng thời chỉ chốt được một trạng thái; trả lỗi có thể phục hồi.
6. SQL Server: nâng cấp schema hiện có, khóa duy nhất, cập nhật đồng thời và
   đọc lại bằng DbContext mới. Test dùng database tạm riêng như kiểm thử likes.
7. Flutter: lọc hồ sơ thật, gửi/hủy/nhận/từ chối, khóa nút bấm lặp, lỗi mạng,
   refresh, trạng thái rỗng và không trộn dữ liệu giữa hai tài khoản.
8. Chạy analyzer, test liên quan và toàn bộ suite; báo riêng các lỗi demo/auth
   đã tồn tại. Giữ các chỉnh sửa chưa commit của người dùng.
