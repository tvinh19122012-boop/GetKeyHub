# SIKE HUB — Key System (vượt link Link4m • key 48h theo máy)

Hệ thống key hoàn chỉnh: user **vượt 1 link rút gọn** để lấy key, key **ngẫu nhiên theo từng máy** (HWID), **không trùng**, mỗi key **hết hạn sau 48h** kể từ lúc kích hoạt.

## Luồng hoạt động

```
[Script trong game] ──GET KEY──> [Server /api/getlink]
        │                              │ rút gọn bằng Link4m API
        │<── link4m.com/xxxxxx ─────────┘
        │ (copy link)
        ▼
[User mở trình duyệt, vượt link] ──> [getkey.html?hwid=..&token=..]
        │ bấm NHẬN KEY
        ▼
[Server /api/redeem] ──> tạo key SIKE-XXXX-XXXX-XXXX (48h, gắn HWID)
        │
        ▼
[User dán key vào script] ──VERIFY──> [Server /api/verify] ──> ✔ chạy script
```

## Cấu trúc project

```
sikehub-keysystem/
├── server/           # backend Node.js (deploy lên Render)
│   ├── server.js
│   ├── package.json
│   └── .gitignore
├── docs/             # web tĩnh (bật GitHub Pages từ thư mục này)
│   ├── getkey.html   # trang nhận key sau khi vượt link
│   └── index.html    # trang giới thiệu
├── lua/
│   └── KeySystem.lua # module key, paste vào ĐẦU script
├── render.yaml       # deploy Render 1-click (optional)
└── README.md
```

## Bước 1 — Đưa code lên GitHub

1. Tạo repo mới trên GitHub (vd: `sikehub`), để **Public** (Pages free cần public, hoặc Pro mới dùng private).
2. Upload toàn bộ thư mục `sikehub-keysystem` (giữ nguyên cấu trúc `server/`, `docs/`, `lua/`).

> ⚠️ **KHÔNG** commit token Link4m vào repo. Token chỉ điền ở biến môi trường Render (Bước 3).

## Bước 2 — Bật GitHub Pages (trang nhận key)

1. Vào repo → **Settings → Pages**.
2. **Source:** Deploy from a branch → Branch: `main` → Folder: `/docs` → Save.
3. Chờ 1–2 phút, bạn sẽ có link dạng:
   ```
   https://TENBAN.github.io/sikehub
   ```
   Đây chính là `SITE_URL` (không có `/` ở cuối). Trang nhận key sẽ là `.../getkey.html`.

## Bước 3 — Deploy server lên Render (free)

1. Vào [render.com](https://render.com) → đăng nhập bằng GitHub → **New → Web Service** (hoặc **Blueprint** nếu dùng `render.yaml`).
2. Chọn repo `sikehub`, cấu hình:
   - **Root Directory:** `server`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Plan:** Free
3. Thêm **Environment Variables**:
   | Key | Value |
   |---|---|
   | `LINK4M_API` | token Link4m của bạn (`67b17d...` — lấy trong tài khoản Link4m) |
   | `SITE_URL` | `https://TENBAN.github.io/sikehub` (link Pages ở Bước 2) |
   | `KEY_TTL_HOURS` | `48` |
4. Bấm **Deploy**. Xong sẽ có link server dạng:
   ```
   https://sikehub-keyserver.onrender.com
   ```
   Đây chính là `SERVER_URL`. Mở link này trên trình duyệt, thấy dòng `SIKE HUB Key Server` là OK.

> 💤 Render free sẽ **ngủ sau 15 phút** không ai gọi. Lần gọi đầu sau khi ngủ chờ **30–60s** để server dậy (script đã báo sẵn cho user). Muốn online 24/7 thì dùng UptimeRobot ping link server mỗi 5 phút, hoặc nâng cấp gói trả phí.

## Bước 4 — Điền SERVER_URL vào 2 chỗ

1. **`docs/getkey.html`** — sửa dòng:
   ```js
   const SERVER_URL = "https://THAY-BANG-LINK-SERVER.onrender.com";
   ```
2. **`lua/KeySystem.lua`** — sửa dòng:
   ```lua
   local SERVER_URL = "https://THAY-BANG-LINK-SERVER.onrender.com"
   ```
3. Commit + push lên GitHub (Pages tự cập nhật sau ~1 phút).

## Bước 5 — Gắn KeySystem vào script

Mở file script `SIKE_HUB.lua`, **paste toàn bộ nội dung `lua/KeySystem.lua` lên trên cùng** (dòng 1), lưu lại là xong.

(Xem file build sẵn `SIKE_HUB_with_key.lua` ở thư mục gốc project — nhớ sửa `SERVER_URL` trong đó trước khi dùng.)

## Test thử

1. Chạy script trong game → hiện bảng **SIKE HUB KEY SYSTEM**.
2. Bấm **GET KEY** → link được copy → mở bằng trình duyệt → vượt link Link4m.
3. Tới trang **NHẬN KEY** → bấm nút → copy key `SIKE-XXXX-XXXX-XXXX`.
4. Dán key vào script → **VERIFY** → ✔ script chạy.
5. Chạy lại script → **tự đăng nhập** (key còn hạn, không cần nhập lại).
6. Sau 48h key hết hạn → user bấm GET KEY lấy lại key mới.

## API tham khảo

| Endpoint | Ai gọi | Chức năng |
|---|---|---|
| `GET /` | test | kiểm tra server sống |
| `GET /api/getlink?hwid=...` | script | tạo token 1 lần + trả link Link4m đã rút gọn |
| `GET /api/redeem?hwid=...&token=...` | getkey.html | cấp key 48h gắn HWID (máy đã có key còn hạn → trả key cũ) |
| `GET /api/verify?key=...&hwid=...` | script | kiểm tra key: đúng máy + còn hạn |

## Bảo mật — đọc kỹ

- **Token Link4m chỉ nằm ở biến môi trường Render**, không để trong code Lua/HTML (user soi là thấy).
- Token bạn gửi trong chat đã bị lộ → nên vào Link4m đổi token mới nếu họ cho phép (nếu không đổi được thì vẫn dùng được, chỉ cần giữ kín từ giờ).
- `keys.json` (chứa key user) đã cho vào `.gitignore` — đừng public file này.
- HWID lấy từ `gethwid()` của executor, fallback sang `UID_<UserId>` nếu executor không hỗ trợ.

## Lỗi thường gặp

| Lỗi | Nguyên nhân / cách fix |
|---|---|
| `Không kết nối được server` | Render đang ngủ → chờ 30–60s thử lại; hoặc sai `SERVER_URL` |
| `Server chưa cấu hình LINK4M_API / SITE_URL` | quên thêm biến môi trường ở Render → thêm rồi redeploy |
| `Link hết hạn hoặc đã dùng` | token chỉ dùng 1 lần trong 30 phút → bấm GET KEY lấy link mới |
| `Key này thuộc về máy khác` | key gắn HWID, không share được |
| `Chờ 60s rồi lấy link mới` | chống spam, chờ rồi bấm lại |
| Trang getkey báo `Link thiếu thông tin` | mở trang trực tiếp không qua link vượt → phải GET KEY từ script |
