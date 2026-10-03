# PROMPT CHO AGENT: Xây dựng web app "Bản đồ review món ăn" (PWA)

> Cách dùng: dán toàn bộ tài liệu này cho agent ở lần đầu. Sau đó giao **từng milestone một** (M0, M1, ...) và chỉ chuyển sang milestone kế tiếp khi Definition of Done của milestone hiện tại đã được kiểm chứng.

---

## 1. Vai trò và cách làm việc

Bạn là kỹ sư full-stack cấp cao, xây dựng một web app theo đặc tả dưới đây từ đầu đến khi có thể triển khai thật.

**Quy tắc làm việc (bắt buộc):**

1. **Đọc hết đặc tả trước khi viết code.** Mở đầu bằng một bản tóm tắt ngắn: bạn hiểu sản phẩm là gì, danh sách giả định của bạn, và các rủi ro bạn thấy.
2. **Không dựa vào trí nhớ về API của thư viện.** Với Next.js, Supabase, MapLibre, Serwist/PWA, next-intl: đọc tài liệu chính thức của phiên bản đang cài và chạy thử. Khóa phiên bản (pin) trong `package.json`.
3. **Làm theo lát cắt dọc (vertical slice):** mỗi milestone hoàn thành trọn một tính năng từ database tới giao diện và chạy được.
4. **Không sang milestone mới khi chưa chạy được Definition of Done (DoD)** của milestone hiện tại. Cuối mỗi milestone báo cáo: đã làm gì, cách chạy, đã kiểm chứng gì (kèm lệnh/kết quả), việc còn tồn đọng.
5. **Hỏi lại chỉ khi bị chặn thật sự.** Nếu không, chọn phương án hợp lý nhất, ghi vào `docs/ASSUMPTIONS.md` rồi tiếp tục.
6. **Commit nhỏ, mỗi commit một việc**, theo Conventional Commits (`feat:`, `fix:`, `chore:`...). Trước khi commit chạy: lint, type-check, test.
7. **Không đưa bí mật vào repo.** Khóa API đặt trong biến môi trường. Cung cấp `.env.example`.
8. **Không thêm dịch vụ có phí** hoặc thư viện nặng mà không hỏi tôi trước. Ưu tiên giải pháp miễn phí/mã nguồn mở.
9. **Không bịa dữ liệu thật.** Dữ liệu mẫu (seed) phải được đánh dấu rõ là mẫu (`source = 'seed'`).

---

## 2. Tổng quan sản phẩm

**Một câu:** Mở app là thấy **bản đồ** các quán/món ăn quanh mình; bấm vào xem **review** của cộng đồng, tự viết review (có thể **ẩn danh**), và **chỉ đường** tới quán ngay.

**Điểm khác biệt:** đánh giá theo **từng món** (không chỉ theo quán); chỉ có địa điểm ăn uống nên bản đồ gọn; review do cộng đồng đóng góp.

**Đối tượng:** người dùng Việt Nam (giao diện **tiếng Việt mặc định**), dùng chủ yếu trên **điện thoại**. Phạm vi địa lý: toàn Việt Nam về kỹ thuật, nhưng nội dung ban đầu tập trung 1-2 khu vực.

**Nền tảng:** Web app dạng **PWA**, **mobile-first**, chạy tốt trên Android Chrome và iPhone Safari, cài được vào màn hình chính. Không làm app native ở giai đoạn này.

**Khái niệm cốt lõi:**
- **Review = bình luận.** Chỉ có MỘT loại nội dung do người dùng viết: review gồm số sao (1-5), nội dung nhận xét, ảnh (tối đa 5), món được nhắc tới (tùy chọn), công tắc "Đăng ẩn danh". **Không có** hệ thống bình luận/trả lời riêng ở MVP.
- **Ẩn danh = ẩn với người dùng khác**, không phải ẩn với hệ thống/quản trị. Phải ghi rõ trong giao diện và điều khoản.

---

## 3. Phạm vi

### Có trong MVP
1. Đăng nhập: Google + Email; chế độ **Khách (guest)** chỉ xem
2. Bản đồ: vị trí hiện tại, pin quán, gom nhóm pin (clustering), tải theo vùng đang xem
3. Tìm kiếm (hỗ trợ tiếng Việt có dấu/không dấu) và bộ lọc
4. Trang chi tiết quán: thông tin, các món, danh sách review
5. Viết/sửa/xóa review (sao, nội dung, ảnh, ẩn danh)
6. Thêm quán mới bằng cách ghim lên bản đồ (có kiểm tra trùng)
7. Nút **Chỉ đường** (mở Google Maps/Apple Maps bằng liên kết)
8. Lưu quán/món ("Muốn thử", "Đã ăn")
9. Báo cáo nội dung, chặn người dùng, kiểm duyệt cơ bản
10. Hồ sơ cá nhân, xóa tài khoản
11. Trang Chính sách quyền riêng tư và Điều khoản sử dụng
12. PWA cài được vào màn hình chính

### Ngoài phạm vi (KHÔNG làm)
Đặt món/giao hàng/thanh toán; dẫn đường từng bước trong app; bình luận/trả lời riêng; theo dõi người dùng (follow); bảng xếp hạng; thông báo đẩy; tài khoản chủ quán; video; app native iOS/Android; đăng nhập bằng số điện thoại/Facebook/Apple.

---

## 4. Stack bắt buộc

| Lớp | Công nghệ |
|---|---|
| Framework | **Next.js (App Router) + TypeScript `strict`** |
| UI | **Tailwind CSS**; hệ thống design token; Dark Mode |
| Bản đồ | **MapLibre GL JS** (qua `react-map-gl/maplibre` hoặc tương đương). Dùng clustering có sẵn của GeoJSON source |
| Nền bản đồ | Style URL cấu hình bằng biến môi trường. **Không dùng máy chủ tile công cộng của OSM cho bản chạy thật**; dùng nhà cung cấp có gói miễn phí hoặc tự host (kiểm tra điều khoản) |
| Backend | **Supabase**: PostgreSQL + **PostGIS** + Auth + Storage + Edge Functions |
| Dữ liệu phía client | `@supabase/supabase-js`, **TanStack Query** |
| Form/validate | **React Hook Form + Zod** |
| i18n | **next-intl** (vi mặc định, có khung en) |
| PWA | Giải pháp PWA đang được duy trì cho Next.js (ví dụ Serwist). Agent kiểm tra tài liệu hiện hành |
| Test | **Vitest + Testing Library**, **Playwright** (E2E), **pgTAP** hoặc `supabase test db` (kiểm thử RLS) |
| CI | GitHub Actions: lint, type-check, test, build |
| Hosting | Vercel hoặc Cloudflare Pages (gói miễn phí; kiểm tra điều khoản) |
| Theo dõi lỗi | Sentry (gói miễn phí) — tùy chọn, bật sau M8 |

---

## 5. Cấu trúc repo

```
/
├─ src/
│  ├─ app/                  # Next.js App Router (routes, layouts)
│  ├─ features/
│  │  ├─ auth/
│  │  ├─ map/
│  │  ├─ restaurants/
│  │  ├─ reviews/
│  │  ├─ saved/
│  │  ├─ moderation/
│  │  └─ profile/
│  ├─ components/ui/        # component dùng chung, không chứa logic nghiệp vụ
│  ├─ lib/                  # supabase client, utils, constants
│  ├─ messages/             # vi.json, en.json
│  └─ styles/
├─ supabase/
│  ├─ migrations/           # MỌI thay đổi schema nằm ở đây
│  ├─ functions/            # Edge Functions
│  ├─ tests/                # test RLS (pgTAP)
│  ├─ seed.sql
│  └─ config.toml
├─ docs/
│  ├─ ASSUMPTIONS.md
│  ├─ ARCHITECTURE.md
│  └─ PRIVACY-DESIGN.md
├─ .env.example
└─ README.md
```

**Phân lớp trong mỗi feature:** `components/` (giao diện) → `hooks/` (logic, TanStack Query) → `repository.ts` (truy cập Supabase). **Component không gọi Supabase trực tiếp.**

---

## 6. Yêu cầu chức năng

### 6.1 Xác thực
- AUTH-01: Đăng nhập bằng Google (Supabase Auth OAuth) và Email (mật khẩu hoặc magic link; chọn một, ghi vào ASSUMPTIONS).
- AUTH-02: **Khách** xem được bản đồ, quán, review, chỉ đường. Mọi hành động ghi (viết review, thêm quán, lưu, báo cáo) yêu cầu đăng nhập; chỉ hiện yêu cầu đăng nhập **đúng lúc** người dùng thực hiện hành động đó.
- AUTH-03: Sửa hồ sơ (tên hiển thị, avatar).
- AUTH-04: **Xóa tài khoản** ngay trong app (Edge Function dùng service role). Mặc định: xóa toàn bộ review, ảnh và dữ liệu cá nhân của người đó.
- AUTH-05: Đăng xuất.

### 6.2 Bản đồ
- MAP-01: Hiển thị bản đồ toàn màn hình (mobile-first), xin quyền vị trí **chỉ khi người dùng bấm nút "Vị trí của tôi"**, hoặc có thông báo giải thích rõ lý do. Từ chối quyền vẫn dùng được (tìm bằng tay, kéo bản đồ).
- MAP-02: Tải quán theo **vùng đang xem** (bounding box) qua RPC `restaurants_in_bounds`, debounce ~300ms, giới hạn số kết quả (ví dụ 500), hủy request cũ khi có request mới.
- MAP-03: Gom nhóm pin (clustering) khi thu nhỏ.
- MAP-04: Pin phân biệt theo loại món hoặc điểm đánh giá (chọn một, ghi ASSUMPTIONS).
- MAP-05: Chạm pin → thẻ tóm tắt kéo lên từ dưới (tên, điểm TB, số review, khoảng cách nếu có vị trí, món nổi bật) → chạm tiếp để vào trang chi tiết.
- MAP-06: Bộ lọc dạng chip phía trên: Đang mở cửa (nếu có dữ liệu giờ), Dưới X đồng, Từ 4 sao, Loại món, Tỉnh/thành.
- MAP-07: Nút chuyển giữa xem **Bản đồ** và **Danh sách**.
- MAP-08: Nút "Tìm ở khu vực này" khi người dùng kéo bản đồ đi xa.

### 6.3 Tìm kiếm
- SRCH-01: Tìm theo tên quán, tên món, địa chỉ.
- SRCH-02: **Hỗ trợ có dấu và không dấu** (gõ "pho bo" ra "phở bò"); chịu sai chính tả nhẹ (trigram).
- SRCH-03: Chọn kết quả → bản đồ bay tới vị trí quán.

### 6.4 Quán và món
- RES-01: Trang chi tiết quán: tên, địa chỉ, ảnh, điểm TB, số review, danh sách món (kèm giá nếu có), nút Chỉ đường, nút Chia sẻ, danh sách review.
- RES-02: **Thêm quán mới**: người dùng ghim vị trí trên bản đồ hoặc tìm theo địa chỉ, nhập tên, loại món, (tùy chọn) giá/ảnh.
- RES-03: **Kiểm tra trùng**: cảnh báo khi đã có quán cùng/giống tên trong bán kính ~50m (`ST_DWithin` + độ tương đồng tên). Người dùng có thể xác nhận "đây là quán khác".
- RES-04: Báo "đã đóng cửa" / "sai vị trí" / "sai thông tin". Tự động ẩn quán khỏi bản đồ khi đủ ngưỡng báo cáo từ nhiều người dùng khác nhau (ngưỡng cấu hình được), chờ quản trị xem xét.
- RES-05: Danh mục món chuẩn (taxonomy) theo vùng miền, có bảng `dish_categories` và `dishes` (tên chuẩn + tên gọi khác), để tránh trùng lặp kiểu "Bún bò" / "Bún bò Huế".

### 6.5 Review (đồng thời là bình luận)
- REV-01: Viết review: sao (1-5, bắt buộc), nội dung (giới hạn độ dài, ví dụ 2000 ký tự), ảnh (0-5), món (tùy chọn), công tắc **"Đăng ẩn danh"**.
- REV-02: Mỗi tài khoản **chỉ có một review cho mỗi cặp (quán, món)**. Viết lại = cập nhật review cũ.
- REV-03: Sửa và xóa review của chính mình ("Review của tôi").
- REV-04: Bấm "Hữu ích" cho review của người khác (mỗi người một lần mỗi review).
- REV-05: Danh sách review sắp xếp theo: mới nhất / hữu ích nhất / sao cao / sao thấp. Phân trang (cursor-based).
- REV-06: **Review ẩn danh**: hiển thị tên chung "Thực khách ẩn danh" + avatar mặc định, không có liên kết hồ sơ. Không xuất hiện trong trang hồ sơ công khai. Vẫn tính vào điểm trung bình.
- REV-07: Xử lý ảnh **trên trình duyệt** trước khi tải lên: resize (cạnh dài tối đa ~1600px), nén (WebP/JPEG chất lượng ~0.8), **loại bỏ EXIF** bằng cách vẽ lại lên canvas rồi xuất. Phải có test xác nhận ảnh đầu ra không còn EXIF/GPS.

### 6.6 Chỉ đường
- NAV-01: Nút **Chỉ đường** mở liên kết `https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>`. Trên iOS, cho người dùng chọn Google Maps hoặc Apple Maps (`https://maps.apple.com/?daddr=<lat>,<lng>`).
- NAV-02: Hiển thị khoảng cách đường chim bay từ vị trí người dùng (nếu có quyền vị trí). Không tự dẫn đường trong app.

### 6.7 Lưu quán/món
- SAVE-01: Lưu vào "Muốn thử" hoặc "Đã ăn"; xem lại trong trang cá nhân.

### 6.8 Kiểm duyệt và an toàn
- MOD-01: **Báo cáo** review/quán/người dùng kèm lý do.
- MOD-02: **Chặn người dùng**: nội dung của người bị chặn không hiển thị với người chặn (lọc ở view/RPC).
- MOD-03: Bộ lọc từ ngữ cấm cơ bản phía server (trigger hoặc Edge Function), danh sách cấu hình được.
- MOD-04: Review bị báo cáo từ nhiều người khác nhau vượt ngưỡng sẽ tự chuyển trạng thái chờ duyệt (ẩn tạm).
- MOD-05: Quản trị: người dùng có `role = 'admin'` xem hàng đợi báo cáo, ẩn/xóa nội dung, khóa tài khoản. MVP chấp nhận dùng trang `/admin` đơn giản được bảo vệ bằng role, hoặc bảng điều khiển Supabase; ghi lựa chọn vào ASSUMPTIONS.
- MOD-06: Mọi truy cập của quản trị vào danh tính chủ sở hữu thật của review ẩn danh phải được **ghi nhật ký** (`admin_audit_log`).

### 6.9 Giới hạn chống lạm dụng (ép ở phía server, không chỉ client)
- Chỉ đăng ẩn danh khi tài khoản đã tồn tại tối thiểu 24 giờ và đã xác minh email (ngưỡng cấu hình được).
- Tối đa N review mỗi ngày mỗi tài khoản (mặc định 10); tối đa M quán mới mỗi ngày (mặc định 5).
- Thực thi bằng trigger/hàm trong database hoặc Edge Function, **không** chỉ kiểm tra ở giao diện.

### 6.10 Trang pháp lý
- LEGAL-01: Trang **Chính sách quyền riêng tư** và **Điều khoản sử dụng** (tiếng Việt), liên kết ở chân trang và màn hình đăng nhập. Nội dung nháp do agent soạn, ghi rõ **cần tôi/chuyên gia rà soát** (có tham chiếu tới quy định bảo vệ dữ liệu cá nhân tại Việt Nam). Phải nêu rõ nghĩa của "ẩn danh".
- LEGAL-02: Khi bật công tắc ẩn danh, hiển thị câu giải thích ngắn: ẩn với người dùng khác, quản trị viên vẫn có thể xử lý vi phạm.

---

## 7. Mô hình dữ liệu (phác thảo SQL — agent hoàn thiện, kiểm thử, và đặt trong migration)

> Đây là **phác thảo định hướng**. Agent phải kiểm tra tên schema của extension trên Supabase (ví dụ `extensions`), kiểu dữ liệu, chỉ mục, và chạy thử toàn bộ.

```sql
-- Extensions
create extension if not exists postgis;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- Hàm bọc để dùng unaccent trong chỉ mục (phải IMMUTABLE)
-- (agent: kiểm tra đúng schema của extension unaccent)
create or replace function public.f_unaccent(text)
returns text language sql immutable parallel safe as
$$ select unaccent('unaccent', $1) $$;

-- Hồ sơ
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  role text not null default 'user' check (role in ('user','admin')),
  is_banned boolean not null default false,
  created_at timestamptz not null default now()
);

-- Danh mục món
create table public.dish_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  region text           -- ví dụ: Bắc, Trung, Nam (tùy chọn)
);

create table public.dishes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text not null,   -- lower + bỏ dấu, dùng để tìm/ chống trùng
  category_id uuid references public.dish_categories(id),
  aliases text[] not null default '{}',
  unique (normalized_name)
);

-- Quán
create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  province text,                       -- đối chiếu danh mục hành chính hiện hành
  location geography(Point,4326) not null,
  created_by uuid references public.profiles(id) on delete set null,
  source text not null default 'user' check (source in ('user','seed')),
  status text not null default 'active' check (status in ('active','hidden_pending_review','closed','removed')),
  avg_rating numeric(3,2) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index restaurants_location_gix on public.restaurants using gist (location);
create index restaurants_name_trgm on public.restaurants using gin (public.f_unaccent(lower(name)) gin_trgm_ops);

create table public.restaurant_dishes (
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  dish_id uuid references public.dishes(id) on delete cascade,
  price_vnd integer check (price_vnd is null or price_vnd >= 0),
  primary key (restaurant_id, dish_id)
);

-- Review (đồng thời là bình luận)
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  dish_id uuid references public.dishes(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  content text check (char_length(content) <= 2000),
  is_anonymous boolean not null default false,
  status text not null default 'visible' check (status in ('visible','hidden_pending_review','removed')),
  helpful_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Một review cho mỗi (user, quán, món); dish null được coi là "quán nói chung"
create unique index reviews_one_per_target on public.reviews
  (user_id, restaurant_id, coalesce(dish_id, '00000000-0000-0000-0000-000000000000'::uuid));

create table public.review_photos (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  storage_path text not null,
  position smallint not null default 0
);

create table public.review_helpful (
  review_id uuid references public.reviews(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  primary key (review_id, user_id)
);

create table public.saved_items (
  user_id uuid references public.profiles(id) on delete cascade,
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  list_type text not null check (list_type in ('want_to_try','visited')),
  created_at timestamptz not null default now(),
  primary key (user_id, restaurant_id, list_type)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('review','restaurant','user')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)
);

create table public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade,
  blocked_id uuid references public.profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  target_type text,
  target_id uuid,
  created_at timestamptz not null default now()
);
```

### 7.1 Row Level Security (bắt buộc bật cho MỌI bảng)
Nguyên tắc: **mặc định từ chối**, chỉ mở đúng quyền cần thiết.
- `profiles`: ai cũng đọc được `id, display_name, avatar_url`; chỉ chủ sở hữu sửa hồ sơ của mình. Cột `role` và `is_banned` **không** cho người dùng tự sửa.
- `reviews`: **client không SELECT trực tiếp** người khác. Chủ sở hữu có thể SELECT/UPDATE/DELETE review của chính mình. INSERT yêu cầu `user_id = auth.uid()`, không bị banned, vượt qua kiểm tra giới hạn chống lạm dụng.
- Người dùng công khai chỉ đọc review qua **view `public_reviews`** (mục 7.2).
- `restaurants`: ai cũng đọc quán `status = 'active'`; INSERT cho người dùng đã đăng nhập (qua giới hạn); không cho tự sửa `status`, `avg_rating`, `review_count`.
- `reports`, `blocks`, `saved_items`, `review_helpful`: chỉ chủ sở hữu thao tác/đọc dòng của mình.
- `admin_audit_log`: chỉ quản trị đọc; ghi qua hàm đặc quyền.

### 7.2 View công khai (cốt lõi của tính ẩn danh)

```sql
create view public.public_reviews as
select
  r.id,
  r.restaurant_id,
  r.dish_id,
  r.rating,
  r.content,
  r.is_anonymous,
  r.helpful_count,
  r.created_at,
  case when r.is_anonymous then null else r.user_id end as author_id,
  case when r.is_anonymous then null else p.display_name end as author_name,
  case when r.is_anonymous then null else p.avatar_url end as author_avatar
from public.reviews r
join public.profiles p on p.id = r.user_id
where r.status = 'visible'
  and not exists (
    select 1 from public.blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = r.user_id
  );
```

**Yêu cầu quan trọng:**
- View chạy với quyền chủ sở hữu (bỏ qua RLS của bảng gốc) là **có chủ đích** — vì thế view **chỉ được chứa các cột an toàn** như trên. Agent phải ghi chú rõ điều này trong `ARCHITECTURE.md` và kiểm tra cấu hình `security_invoker` cho đúng ý đồ.
- **Không bao giờ** trả `user_id` thật của review ẩn danh ra client, qua bất kỳ endpoint/RPC/view nào. Kể cả `review_photos`: đường dẫn ảnh của review ẩn danh không được chứa `user_id` (dùng UUID ngẫu nhiên).
- Phải có **test tự động** chứng minh: (a) khách/người dùng khác không lấy được `user_id` của review ẩn danh; (b) người dùng A không sửa/xóa được review của B; (c) người bị chặn không thấy... theo quy tắc `blocks`.

### 7.3 RPC (hàm) chính
- `restaurants_in_bounds(min_lat, min_lng, max_lat, max_lng, filters jsonb, lim int default 500)` → danh sách quán gọn (id, tên, lat, lng, avg_rating, review_count, loại) trong khung nhìn.
- `search_restaurants(q text, lim int default 20)` → tìm theo `f_unaccent(lower(...))` với trigram.
- `check_duplicate_restaurant(name text, lat float, lng float)` → các quán gần/giống tên trong ~50m.
- Trigger cập nhật `avg_rating`, `review_count` khi review thay đổi.
- Trigger/hàm kiểm tra giới hạn chống lạm dụng và bộ lọc từ cấm khi INSERT review/quán.

---

## 8. Yêu cầu phi chức năng

- **Hiệu năng:** màn hình bản đồ hiển thị dưới ~2 giây trên 4G; chỉ tải quán trong vùng nhìn thấy; danh sách dùng phân trang/ảo hóa; ảnh có thumbnail và lazy-load. Mục tiêu Lighthouse mobile: Performance ≥ 80, Accessibility ≥ 90 (agent báo kết quả thực tế).
- **Bảo mật:** HTTPS; không lộ service role key ra client; RLS bật mọi bảng; kiểm tra input bằng Zod ở client và ràng buộc ở database; chống XSS (không render HTML thô từ nội dung người dùng); đặt các HTTP security header cơ bản.
- **Quyền riêng tư:** không lưu lịch sử vị trí người dùng; tọa độ người dùng chỉ dùng tức thời trên client để hiển thị/khoảng cách; **không ghi log** dữ liệu cá nhân hay tọa độ.
- **Khả năng truy cập:** nhãn cho nút/ảnh, hỗ trợ bàn phím, độ tương phản đủ, tôn trọng cỡ chữ hệ thống.
- **Mạng yếu:** có trạng thái tải/lỗi/thử lại; PWA cache phần vỏ (app shell), không cần offline đầy đủ ở MVP.
- **Khả năng mở rộng:** schema không khóa cứng vào một thành phố; có `province`, chỉ mục không gian.

---

## 9. UI/UX

- **Mobile-first**: bản đồ chiếm toàn màn hình; thanh tìm kiếm + chip lọc nổi phía trên; thẻ quán dạng **bottom sheet** kéo lên; thanh điều hướng dưới (Bản đồ, Danh sách, Đã lưu, Tôi).
- Mỗi màn hình xử lý đủ 4 trạng thái: **đang tải, rỗng, lỗi, thành công**.
- Chuỗi giao diện **không viết cứng**, đặt trong `messages/vi.json` (và `en.json`).
- Hỗ trợ Dark Mode theo hệ thống. Chọn màu và typography nhất quán qua design token.
- Màn hình đăng nhập/đăng ký ngắn gọn; khách xem được ngay không bị chặn.

---

## 10. Quy tắc viết code

- TypeScript `strict`, **cấm `any`** trừ khi có chú thích lý do.
- Cấu trúc theo **tính năng**; component → hook → repository (mục 5).
- Mọi dữ liệu từ server và input người dùng **kiểm tra bằng Zod**.
- Không `console.log` dữ liệu nhạy cảm; dùng logger có mức độ.
- Hàm nhỏ, tên rõ nghĩa; bình luận giải thích **vì sao**, không lặp lại **cái gì**.
- Mọi thay đổi database đi qua **migration** trong repo; không sửa tay trên dashboard.
- Mỗi PR/commit kèm test cho logic mới; lỗi được sửa phải có test tái hiện.
- ESLint + Prettier + `tsc --noEmit` sạch trước khi hoàn thành mỗi milestone.

---

## 11. Milestone và Definition of Done

| Mốc | Nội dung | DoD (phải kiểm chứng bằng cách chạy) |
|---|---|---|
| **M0** | Khởi tạo repo: Next.js + TS strict, Tailwind, ESLint/Prettier, next-intl, cấu trúc thư mục, Supabase CLI + project local, CI, README, `.env.example`, PWA manifest cơ bản | `npm run dev` chạy; CI xanh (lint, type-check, test, build); README hướng dẫn chạy từ đầu |
| **M1** | Schema + migration + RLS + `public_reviews` + RPC + seed (vài chục quán mẫu đánh dấu `seed`) + **test RLS** | `supabase db reset` chạy sạch; test RLS pass, gồm: không lộ `user_id` ẩn danh, không sửa review người khác; `restaurants_in_bounds` trả đúng theo vùng |
| **M2** | Xác thực: Google + Email, chế độ Khách, hồ sơ, xóa tài khoản | Đăng nhập/đăng xuất/xóa tài khoản chạy được; khách không thực hiện được hành động ghi |
| **M3** | Bản đồ: MapLibre, vị trí người dùng, tải theo vùng, clustering, chạm pin → thẻ tóm tắt, bộ lọc | Kéo/zoom bản đồ tải đúng quán, không giật; từ chối quyền vị trí vẫn dùng được |
| **M4** | Tìm kiếm có dấu/không dấu + trang chi tiết quán + danh sách review (phân trang, sắp xếp) | "pho bo" tìm ra "phở bò"; review ẩn danh hiển thị đúng tên chung, không lộ `user_id` qua mạng (kiểm tra request) |
| **M5** | Viết/sửa/xóa review, upload ảnh (resize, nén, **xóa EXIF**), công tắc ẩn danh, "Hữu ích", giới hạn chống lạm dụng | Đăng review có ảnh; test xác nhận ảnh không còn EXIF/GPS; vượt giới hạn bị từ chối ở **phía server** |
| **M6** | Thêm quán bằng ghim + kiểm tra trùng + báo "đóng cửa/sai vị trí" | Không tạo trùng trong ~50m khi cùng/giống tên (có thể xác nhận bỏ qua); quán bị báo đủ ngưỡng tự ẩn |
| **M7** | Chỉ đường (Google Maps/Apple Maps), Lưu quán, Chia sẻ | Nút mở đúng ứng dụng với đúng tọa độ trên Android và iPhone |
| **M8** | Báo cáo, chặn, kiểm duyệt, trang quản trị tối thiểu, nhật ký audit, trang pháp lý, bộ lọc từ cấm | Báo cáo → xuất hiện ở hàng đợi quản trị; người bị chặn bị ẩn; trang pháp lý có liên kết; audit log ghi khi quản trị xem danh tính |
| **M9** | PWA hoàn chỉnh, E2E (Playwright) cho luồng chính, tối ưu hiệu năng/truy cập, triển khai lên hosting, hướng dẫn vận hành | Cài được vào màn hình chính; E2E pass; báo cáo Lighthouse; có URL chạy thật và tài liệu triển khai |

**Luồng E2E tối thiểu (M9):** khách mở bản đồ → xem quán → đăng nhập → viết review ẩn danh có ảnh → thấy review (không lộ tên) → bấm chỉ đường → báo cáo review.

---

## 12. Biến môi trường (`.env.example`)

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=        # chỉ dùng phía server/Edge Function, KHÔNG để lộ ra client
NEXT_PUBLIC_MAP_STYLE_URL=        # URL style bản đồ (nhà cung cấp tile)
NEXT_PUBLIC_SITE_URL=
```

---

## 13. Chiến lược nội dung ban đầu (không phải việc của agent, để tham khảo)

Bản đồ trống thì không ai dùng. Cần tự thêm 100-200 quán ở 1-2 khu vực làm điểm nóng, mời nhóm nhỏ review thật, mở rộng khi khu vực đầu tiên có người dùng quay lại. Dữ liệu seed trong repo chỉ để **phát triển và kiểm thử**, không phải dữ liệu thật để công bố.

---

## 14. Những điều cần tránh

- Trả `user_id` thật của review ẩn danh ra client dưới bất kỳ hình thức nào.
- Để client đọc trực tiếp bảng `reviews` của người khác.
- Chỉ kiểm tra giới hạn/quyền ở giao diện mà không ép ở database.
- Dùng máy chủ tile công cộng của OSM cho bản chạy thật; dùng khóa Google Maps cho phần hiển thị bản đồ (không cần thiết ở thiết kế này).
- Viết code theo trí nhớ về API thư viện phiên bản mới mà không đọc tài liệu và chạy thử.
- Thêm tính năng ngoài phạm vi (mục 3) khi chưa được yêu cầu.
- Hứa hẹn "ẩn danh tuyệt đối" trong giao diện/điều khoản. Chỉ nói đúng: ẩn với người dùng khác.

---

## 15. Yêu cầu đầu ra mỗi lần báo cáo

1. Tóm tắt đã làm gì (ngắn).
2. Lệnh để chạy và kiểm tra.
3. Kết quả kiểm chứng DoD (dán kết quả lệnh/test).
4. Giả định mới (đã ghi vào `docs/ASSUMPTIONS.md`).
5. Vấn đề tồn đọng và đề xuất bước kế tiếp.
