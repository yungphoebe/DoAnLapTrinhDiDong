# API bảng tin, thích và bình luận

## Phạm vi theo yêu cầu mới

Chỉ backend: bảng tin phân trang, thích/bỏ thích, đọc/gửi/sửa/xóa bình luận,
và kiểm tra quyền sửa/xóa bài viết. Chưa triển khai hồ sơ PT/bạn tập, kết nối
hoặc giao diện Flutter trong đợt này. Đây là phạm vi thu gọn thay cho đề xuất
toàn bộ dữ liệu cộng đồng trong `2026-10-20-community-persistence-design.md`.

Không xây hoặc mở rộng luồng tạo bài. `POST /api/posts` đã tồn tại trong mã
hiện tại; giữ nguyên endpoint đó ngoài phạm vi thay đổi. Kiểm thử mới tạo bài
trực tiếp trong database thử, không phụ thuộc một luồng đăng bài mới.

## Hiện trạng

- GET /api/posts/feed đã có page/pageSize/hasMore, sắp xếp CreatedAt và Id
  giảm dần; pageSize 1–100, mặc định 20.
- PUT /api/posts/{id}/like nhận liked=true/false; khóa chính PostLikes
  (PostId, UserId) và UPDLOCK/HOLDLOCK ngăn thích trùng, kể cả đồng thời.
- PUT/DELETE /api/posts/{id} đã kiểm tra tác giả hoặc admin.
- Chưa có bảng/API bình luận; số bình luận tại Flutter còn là dữ liệu tại máy.

## Thiết kế API

Mọi endpoint thuộc phạm vi yêu cầu JWT. Tài khoản thao tác lấy từ JWT;
không nhận AuthorId của người gửi trong body.

| Endpoint | Hành vi |
|---|---|
| GET /api/posts/feed?page=1&pageSize=20 | Giữ phân trang, liked của tài khoản hiện tại, tổng likes và thêm commentCount thực tế |
| PUT /api/posts/{postId}/like | Đặt liked=true/false; trả postId/liked/likeCount; lặp cùng trạng thái không cộng thêm |
| PUT /api/posts/{postId} | Sửa nội dung khi là tác giả hoặc admin; nội dung 1–1000 ký tự sau trim |
| DELETE /api/posts/{postId} | Xóa khi là tác giả hoặc admin; bình luận và lượt thích đi theo bài |
| GET /api/posts/{postId}/comments?page=1&pageSize=20 | Phân trang mới nhất trước; items/page/pageSize/hasMore/totalCount |
| POST /api/posts/{postId}/comments | Nhận requestId GUID/content; trả bình luận đã lưu; thử lại cùng requestId không tạo trùng |
| PUT /api/posts/{postId}/comments/{commentId} | Sửa nội dung khi là tác giả bình luận hoặc admin |
| DELETE /api/posts/{postId}/comments/{commentId} | Xóa khi là tác giả bình luận hoặc admin |

Bình luận trả id/postId/authorId/authorName/content/createdAt/updatedAt;
tên lấy từ tài khoản thật. Không trả email hoặc trường Identity riêng tư.
Chủ bài không có quyền sửa/xóa bình luận của người khác, trừ khi là admin.

Nội dung bắt buộc 1–1000 ký tự sau trim. Phân trang như feed (1–100).
Trả 400 cho dữ liệu sai, 401 khi chưa đăng nhập, 403 khi không có quyền,
404 cho bài/bình luận không tồn tại hoặc comment không thuộc post trong URL.
RequestId đã dùng cho tài khoản/bài/nội dung khác trả 409. Sau khi bình luận
đã sửa, gửi lại yêu cầu tạo cũ trả 409 thay vì ghi đè nội dung mới.

## Dữ liệu và nâng cấp

Thêm PostComment: Id GUID làm khóa chính, PostId, AuthorId nvarchar(450),
Content nvarchar(1000), CreatedAt/UpdatedAt UTC. Chỉ số
(PostId, CreatedAt, Id) phục vụ phân trang ổn định. PostId FK xóa cascade;
AuthorId FK NO ACTION tránh nhiều đường cascade SQL Server.

Thêm CommentSchema.EnsureAsync theo cơ chế bổ sung bảng đang dùng và gọi
từ DatabaseSeeder. Cùng cấu trúc trong EF OnModelCreating cho database mới.
Không tái tạo database hoặc sửa dữ liệu cũ. Giữ ràng buộc PostLikes hiện có.

GET bình luận và feed chỉ đọc dữ liệu server; không dùng số minh họa.
Trùng requestId được chặn tại database. Lỗi cạnh tranh khi tạo được đọc lại
để xác định thử lại hợp lệ hay xung đột, không trả thành công khi chưa lưu.

## Tệp dự kiến

- Models/PostComment.cs, Data/CommentSchema.cs, Dtos/CommentDtos.cs.
- Controllers/PostCommentsController.cs cho API bình luận.
- ApplicationDbContext, DatabaseSeeder: mapping/nâng cấp bổ sung.
- PostsController/PostDtos: commentCount và giới hạn sửa bài.
- Tests/FeedCommentsApiTests.cs và CommentsSqlServerTests.cs.
- backend/README.md: hợp đồng API, trạng thái lỗi, lệnh kiểm thử.

## Kiểm chứng

1. Feed phân trang không trùng khi trùng thời gian tạo, trang sai trả 400;
   thích/bỏ thích theo hai tài khoản và mở context mới vẫn đúng.
2. Giữ kiểm thử SQL Server hiện có gửi 12 yêu cầu thích đồng thời, chỉ một
   hàng cho mỗi tài khoản/bài; bỏ thích lặp không giảm sai tổng.
3. Bình luận lưu và đọc lại từ context mới; phân trang/tổng số chính xác.
   RequestId lặp/đồng thời không tạo thêm hàng; không nhận giả tác giả.
4. A không sửa/xóa bài hoặc bình luận B. Chủ bài không sửa/xóa bình luận B;
   tác giả và admin thực hiện đúng quyền. URL post/comment sai cặp trả 404.
5. Nội dung rỗng/quá dài, JWT thiếu, bài không tồn tại được từ chối và không
   thay đổi database. Xóa bài xóa comments/likes liên quan.
6. Nâng cấp schema chạy hai lần trên SQL Server thử riêng, không mất dữ liệu;
   chạy toàn bộ kiểm thử backend bằng artifacts riêng để tránh khóa API đang chạy.
