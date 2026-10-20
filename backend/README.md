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
