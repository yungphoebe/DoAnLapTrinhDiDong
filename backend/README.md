# AI GYM Backend

## Thong bao va phan hoi

Sau khi doi code, dung backend cu bang Ctrl+C truoc khi chay lai:

```powershell
dotnet run --project backend/AiGym.Api --launch-profile http
flutter run -d chrome --web-port=5353 --dart-define=API_BASE_URL=http://localhost:5129
```

Backend tu them cac bang ReminderSettings, UserNotifications,
BrowserPushSubscriptions va UserFeedback vao database hien co. Lich nhac mac
dinh tat. Mo Cai dat -> Lich nhac & thong bao, chon lich va cap quyen thiet bi.
Tren Chrome can giu backend dang chay; dong tab van co the nhan Web Push neu
trinh duyet/he dieu hanh cho phep chay nen. Android dung lich cuc bo; tat tu
Chrome duoc ap dung cho Android o lan mo/dong bo tiep theo.

API thong bao (yeu cau JWT, chi thao tac du lieu cua tai khoan hien tai):

| Endpoint | Ket qua |
|---|---|
| `GET /api/notifications?page=1&pageSize=20` | `items`, `page`, `pageSize`, `hasMore`, `unreadCount`; moi nhat truoc |
| `PUT /api/notifications/{id}/read` | 204; lap lai giu nguyen thoi diem da doc, ID cua tai khoan khac tra 404 |
| `PUT /api/notifications/read-all` | 204; chi danh dau thong bao chua doc cua chinh minh |
| `GET /api/notifications/settings` | Lich nhac va `revision` hien tai; mac dinh tat |
| `PUT /api/notifications/settings` | Luu toan bo lich, tra cau hinh da luu voi revision moi |

`pageSize` tu 1 den 100. Khi sua lich, doc GET settings, thay doi cac truong
can thiet va gui lai day du kem `revision` vua doc. Phien ban cu tra 409;
gio/ngay/khoang cach/mui gio sai tra 400, khong ghi de cau hinh da luu.
Thoi gian thong bao va xac nhan phan hoi duoc tra o UTC (`Z`).

Su kien nhac co ID xac dinh theo tai khoan/loai/moc UTC va khoa chinh database;
scheduler chay lap hoac dong thoi khong tao nhieu ban ghi cho cung su kien.
Tat lich dung tao su kien tuong lai, thong bao cu van nam trong danh sach.
Web Push Chrome giu theo phuong an Android/Chrome da chot; dot API nay
khong them nha cung cap push hay du an Firebase.

Trong Development, khoa VAPID duoc tao mot lan o
`backend/AiGym.Api/.local/notification-vapid.json` (da ignore). Khong xoa file
giua cac lan chay va khong commit khoa rieng. Production can cau hinh
`NotificationPush:PublicKey`, `NotificationPush:PrivateKey`,
`NotificationPush:Subject` (dia chi mailto cua nhom).

Nhom chua cung cap huong dan/dieu khoan/chinh sach. API `/api/support/content`
tra cac truong trong `SupportContent`: `GroupName`, `Guide`, `Terms`, `Privacy`,
`UpdatedAt`; khi chua cau hinh, giao dien hien thi ro noi dung chua duoc cung cap.
Nhom co the dat noi dung chinh thuc trong cau hinh moi truong/secret manager;
khong dua noi dung chinh sach tu sang tac vao source.

`POST /api/support/feedback` yeu cau JWT, body gom `requestId` (GUID), `subject`
(toi da 120 ky tu) va `content` (1-4000 ky tu). Phan hoi duoc luu database va
tra ID xac nhan; gui lai cung requestId/noi dung khong tao ban ghi trung.
Day la hop thu phan hoi trong database, khong tu dong gui email khi chua co
kenh tiep nhan chinh thuc cua nhom.

Kiem thu moi: `node --test test/notification_worker_test.cjs`,
`flutter test test/notifications_test.dart test/support_test.dart`, va
`dotnet test backend/AiGym.Api.Tests --artifacts-path .artifacts/notifications`.
Dung thu muc artifacts rieng de tranh khoa file backend dang chay. Dat
`AIGYM_TEST_SQLSERVER` nhu huong dan ben duoi de kiem thu tren SQL Server tam.

Backend ASP.NET Core Web API cho app AI GYM, gom Identity, JWT, role va API bai viet.

## Chay API

Yeu cau .NET SDK 9 tro len va SQL Server LocalDB hoac SQL Server.

```powershell
dotnet restore backend/AiGym.Backend.slnx
dotnet run --project backend/AiGym.Api
```

Mac dinh API chay theo `Properties/launchSettings.json`. Khi dung Conveyor, lay URL public/noi bo cua Conveyor va gan vao Flutter `.env`, vi du:

```env
API_BASE_URL=https://your-conveyor-url
```

## Cau hinh

File `backend/AiGym.Api/appsettings.json` co:

- `ConnectionStrings:DefaultConnection`: SQL Server database `AIGymDb`.
- `Jwt:Issuer`, `Jwt:Audience`, `Jwt:Key`, `Jwt:ExpiresInMinutes`.
- `LMStudio:BaseUrl`, `LMStudio:Model`: dia chi va model LMStudio dung cho tro ly AI.

Khi dua len may that, doi `Jwt:Key` sang secret rieng va khong commit secret san xuat.

LMStudio can chay tai `http://127.0.0.1:1234`, da nap model `qwen/qwen3.5-9b`,
sau do khoi dong lai backend de ap dung cau hinh.
Chat backend dung native API `POST /api/v1/chat` voi `reasoning: off` de model
khong dung het gioi han token cho suy luan va tra loi rong. Can phien ban LMStudio
ho tro API nay va model ho tro tat reasoning; chi noi dung `output` loai `message`
duoc tra ve ung dung.
Phan hoi chat duoc yeu cau ngan gon (toi da 100 tu, gioi han 256 token).
Backend cho toi da 15 phut cho model local cham; neu het thoi gian se tra JSON
HTTP 504 thay vi loi 500 khong doc duoc tren app.

## Tai khoan va role seed san

- Admin: `admin123@gmail.com`
- Mat khau: `123123123Az!`
- Roles: `Admin`, `User`

User dang ky qua API mac dinh duoc gan role `User`.

## Endpoint

### Auth

`POST /api/auth/register`

```json
{
  "fullName": "Nguyen Van A",
  "email": "user@example.com",
  "password": "123123123Az!"
}
```

`POST /api/auth/login`

```json
{
  "email": "admin123@gmail.com",
  "password": "123123123Az!"
}
```

`GET /api/auth/me`

Can header:

```http
Authorization: Bearer <token>
```

Token JWT co claim `userId`, `email`, `role`, `exp` de Flutter doc bang `jwt_decode`.

### Posts

Bang tin Flutter dung `GET /api/posts/feed?page=1&pageSize=20` (can JWT).
`page` bat dau tu 1, `pageSize` tu 1 den 100. Ket qua:

```json
{"items": [], "page": 1, "pageSize": 20, "hasMore": false}
```

Bai viet duoc sap xep theo `createdAt` giam dan, sau do `id` giam dan.
`imageAsset` ho tro asset Flutter (`assets/...`), URL HTTP(S), hoac duong dan
tuong doi voi API. `GET /api/posts` van giu ket qua danh sach cho trang admin.

`PUT /api/posts/{id}/like` voi JWT va body `{"liked": true}` de thich,
`{"liked": false}` de bo thich. Gui lap cung trang thai khong thay doi tong luot.
Ket qua: `{"postId": 1, "liked": true, "likeCount": 1}`.
Ca API danh sach va feed tra `liked` theo tai khoan dang dang nhap, `likeCount`
la tong dong trong bang `PostLikes`; cac bo dem minh hoa cu khong duoc su dung.
Backend tu bo sung bang `PostLikes` neu database SQL Server da ton tai.

Kiem thu SQL Server dung database tam rieng, khong sua database cua ung dung:

```powershell
$env:AIGYM_TEST_SQLSERVER='Server=(localdb)\MSSQLLocalDB;Integrated Security=true;TrustServerCertificate=true'
dotnet test backend/AiGym.Api.Tests
```

`GET /api/posts` can JWT.

`POST /api/posts` can login:

```json
{
  "content": "Tap nguc voi AI Gym",
  "tag": "Bai viet"
}
```

`PUT /api/posts/{id}` can chu bai viet hoac `Admin`.

`DELETE /api/posts/{id}` can chu bai viet hoac `Admin`.

### Binh luan va quyen noi dung

Tat ca endpoint bai viet/binh luan yeu cau JWT. `GET /api/posts/feed` tra them
`commentCount` tinh tu database. Bai viet va binh luan chi duoc sua/xoa boi
tac gia cua chinh noi dung do hoac `Admin`; chu bai khong duoc sua/xoa binh
luan cua tai khoan khac. ID tac gia lay tu JWT, ten binh luan lay tu tai khoan.

| Endpoint | Body / ket qua |
|---|---|
| `GET /api/posts/{postId}/comments?page=1&pageSize=20` | `items`, `page`, `pageSize`, `hasMore`, `totalCount`; moi nhat truoc, sap xep them theo ID khi trung thoi gian |
| `POST /api/posts/{postId}/comments` | `{"requestId":"<GUID>","content":"Noi dung"}`; 201 khi tao, 200 khi thu lai cung yeu cau |
| `PUT /api/posts/{postId}/comments/{commentId}` | `{"content":"Noi dung da sua"}`; 200 va binh luan da luu |
| `DELETE /api/posts/{postId}/comments/{commentId}` | 204 khi xoa thanh cong |

Binh luan tra `id`, `postId`, `authorId`, `authorName`, `content`, `createdAt`,
`updatedAt`. Noi dung binh luan va sua bai viet: 1-1000 ky tu sau khi trim.
`page` tu 1, `pageSize` tu 1 den 100. Loi: 400 du lieu sai, 401 chua dang
nhap, 403 khong co quyen, 404 bai/binh luan khong ton tai hoac sai cap URL.

Moi lan gui binh luan moi tao mot `requestId` GUID; thu lai do mat ket noi
phai giu nguyen ID va noi dung. Database chan trung ke ca gui dong thoi.
Dung lai ID cho tai khoan/bai/noi dung khac, hoac gui lai yeu cau tao sau khi
binh luan da sua, tra 409. Hay tai lai danh sach de lay trang thai moi nhat.

Backend tu bo sung bang `PostComments` vao database hien co khi khoi dong
lai; xoa bai se xoa binh luan va luot thich lien quan. Khong tao lai database.
`POST /api/posts` la endpoint da co; dot thay doi nay khong mo rong luong tao bai.

Chay kiem thu HTTP va SQL Server tren database tam rieng (giu backend dang chay):

```powershell
$env:AIGYM_TEST_SQLSERVER='Server=(localdb)\MSSQLLocalDB;Integrated Security=true;TrustServerCertificate=true'
dotnet test backend/AiGym.Api.Tests --artifacts-path .artifacts/comments
### AI

`POST /api/ai/chat` can dang nhap va chuyen yeu cau den LMStudio:

```json
{
  "message": "Goi y cho toi mot bai tap nguc cho nguoi moi."
}
```

## Kiem tra

```powershell
dotnet test backend/AiGym.Backend.slnx
dotnet build backend/AiGym.Backend.slnx
```
