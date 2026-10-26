# Lưu dữ liệu cộng đồng, PT và bạn tập

## Mục tiêu

Hồ sơ PT/bạn tập, bài đăng, lượt thích, bình luận và lời mời kết nối được lưu
trong SQL Server qua API. Hai tài khoản và các lần mở lại ứng dụng đọc cùng
trạng thái đã xác nhận. Một tài khoản chỉ có một lượt thích trên mỗi bài.

Bản này mở rộng thiết kế `2026-10-18-community-connections-design.md` bằng
phần bình luận và tích hợp dữ liệu cộng đồng. Các quy tắc hồ sơ, bộ lọc và
chuyển trạng thái kết nối trong bản trước tiếp tục áp dụng.

## Hiện trạng đã kiểm tra

- Posts đã có API tạo/sửa/xóa và bảng tin phân trang.
- PostLikes có khóa chính ghép (PostId, UserId), lệnh thêm có khóa phạm vi
  UPDLOCK/HOLDLOCK và thao tác đặt trạng thái liked=true/false. Kiểm thử SQL
  hiện có gửi đồng thời 12 yêu cầu để kiểm tra chống trùng.
- community.dart còn hồ sơ minh họa và tập ID lời mời trong State.
- PostApi.addComment còn thêm bình luận vào bộ nhớ; API trả bài chưa có tổng
  bình luận. Giao diện đang cộng 23 bình luận minh họa vào số thực tế.

## Phương án

Dùng bảng quan hệ riêng cho hồ sơ, bình luận và kết nối, liên kết tài khoản
Identity. Giữ Posts/PostLikes và cơ chế nâng cấp bổ sung bảng đang dùng.
Phương án lưu JSON trong tài khoản ít bảng hơn nhưng khó ràng buộc duy nhất,
phân trang và xử lý cập nhật đồng thời; không chọn phương án đó.

## Dữ liệu và quyền

- CommunityProfile: UserId là khóa chính; loại PT/Bạn tập, thành phố, mục tiêu,
  giới thiệu, lịch rảnh, chi tiết, UpdatedAt. Tên lấy từ tài khoản. Người dùng
  chủ động lưu hồ sơ trước khi xuất hiện trong tìm kiếm; không tạo hồ sơ giả.
- CommunityConnection: một hàng cho mỗi cặp tài khoản chuẩn hóa, khóa SHA-256
  theo thiết kế trước; sender/recipient, invitationId, trạng thái, thời gian
  và revision chống xung đột. InvitationId đổi khi gửi lại sau hủy/từ chối.
- PostComment: Id GUID do client tạo cho mỗi lần gửi, PostId, AuthorId,
  Content tối đa 1000 ký tự, CreatedAt UTC. Khóa chính chặn gửi trùng khi thử
  lại do mất phản hồi mạng. Cùng Id/cùng chủ/cùng nội dung trả bình luận đã
  lưu; tái sử dụng Id cho dữ liệu khác trả 409.
- Bình luận xóa theo bài đăng; liên kết tác giả dùng NO ACTION để tránh nhiều
  đường cascade trên SQL Server. Khóa ngoại không cho lưu vào bài/tài khoản
  không tồn tại. Chỉ số (PostId, CreatedAt, Id) phục vụ phân trang.
- Tất cả thao tác cộng đồng dùng JWT; AuthorId/sender lấy từ JWT, không tin
  ID tác giả trong body. Chỉ tác giả hoặc admin xóa bình luận của họ.
- PostLikes giữ khóa (PostId, UserId) và thao tác đặt trạng thái hiện có;
  tổng lượt tính từ hàng dữ liệu, không dùng bộ đếm minh họa.

## Hợp đồng API

Hồ sơ và lời mời dùng các endpoint và quy tắc trong thiết kế kết nối trước:
GET/PUT /api/community/profile, GET /api/community/profiles,
GET/POST /api/community/connections và PUT /api/community/connections/{invitationId}.

- GET /api/posts/{postId}/comments?page=1&pageSize=20: danh sách mới nhất
  trước, thứ tự CreatedAt rồi Id giảm dần, items/page/pageSize/hasMore/totalCount.
- POST /api/posts/{postId}/comments: body {requestId, content}; trả bình luận
  chuẩn từ server và tổng số hiện tại; 201 khi tạo, 200 khi thử lại cùng dữ liệu.
- DELETE /api/posts/{postId}/comments/{commentId}: kiểm tra chủ/admin và bài
  tương ứng; 204 khi xóa thành công. Không thêm sửa bình luận trong phạm vi này.
- PostResponse thêm commentCount. Tên tác giả bình luận lấy từ tài khoản thật;
  không công khai email/token hoặc trường Identity riêng tư.
- Kiểm tra chuỗi trắng, giới hạn độ dài, phân trang, bài không tồn tại và
  quyền trước khi ghi. Lỗi trả trạng thái 400/401/403/404/409 tương ứng.

## Flutter

Tách model/API/controller và giao diện tìm PT/bạn tập khỏi community.dart.
Thay hồ sơ minh họa bằng API, có tạo/sửa hồ sơ của tôi, lọc, tải lại/tải thêm,
lời mời nhận/đã gửi/đã kết nối, cùng trạng thái tải/rỗng/lỗi.

Bình luận tải khi mở bảng bình luận, có tải thêm, tổng số thật, nhập/gửi và
xóa đúng quyền. Khi gửi lỗi giữ nội dung và requestId để thử lại; gửi thành
công mới xóa ô nhập. Khóa nút trong lúc ghi. Không cộng số 23 minh họa.

Mọi controller chụp phiên đăng nhập và thế hệ yêu cầu; khi đổi tài khoản xóa
cache, bỏ phản hồi cũ. Không hiển thị thành công bằng cách chỉ đổi chữ nút:
cập nhật theo dữ liệu server, và tải lại khi mở app/tab.

## Nâng cấp dữ liệu

Thêm CommunitySchema.EnsureAsync vào DatabaseSeeder sau EnsureCreated, tạo
bảng/chỉ số còn thiếu và chạy lại an toàn. Database mới dùng cùng mapping EF.
Không xóa hoặc tái tạo database, tài khoản, bài viết hay lượt thích hiện có.
Giữ PostApi.seeded chỉ làm fixture kiểm thử; luồng production dùng API thật.

## Kiểm chứng

1. A/B lưu hồ sơ; context mới đọc đúng; lọc không trả chính mình hoặc người
   chưa công khai hồ sơ. A không sửa hồ sơ B.
2. A gửi/hủy, B nhận/đồng ý/từ chối; tài khoản ngoài không xử lý được. Gửi
   hai chiều không tạo hai hàng, quyết định đồng thời chỉ một trạng thái chốt,
   invitationId cũ không thay đổi lời mời mới.
3. Bình luận A được B và phiên mở lại đọc đúng; thử lại cùng requestId chỉ
   tạo một hàng; lỗi mạng giữ nội dung; B không xóa bình luận A.
4. Giữ kiểm thử SQL Server 12 yêu cầu thích trùng, hai tài khoản, bỏ thích
   lặp và đọc lại; kiểm tra nâng cấp schema hai lần trên database thử riêng.
5. Kiểm thử Flutter cho trạng thái rỗng/lỗi/phân trang, gửi lỗi/thử lại,
   đổi tài khoản khi request đang chờ và tổng bình luận thực tế.
6. Chạy analyzer, kiểm thử backend/Flutter phù hợp và build web; báo riêng
   các lỗi kiểm thử cũ hoặc phần chưa kiểm tra trên thiết bị thật.

## Phạm vi

Không thêm chat, thanh toán PT, xác minh chứng chỉ, tải avatar, push lời mời
hoặc lịch sử mọi lần gửi. Những phần này không cần cho việc lưu dữ liệu trên.
