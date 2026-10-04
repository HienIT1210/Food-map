# food-map

Web app (PWA) bản đồ review món ăn: xem quán trên bản đồ, viết review (có thể ẩn danh), chỉ đường.

- Đặc tả: `docs/SPEC.md`
- Tiến độ và bàn giao giữa các agent: `docs/PROGRESS.md`
- Luật cho AI agent: `AGENTS.md`

## Yêu cầu máy

- Node.js **20.9+** (máy này đang dùng 24)
- npm
- **Không cần Docker** trên máy Windows khi phát triển frontend. Không chạy `supabase start` trên máy dev cấu hình yếu.
- Schema, RLS và pgTAP sẽ chạy trên GitHub Actions (job `database`) từ milestone **M1**.

## Cài đặt và chạy

```bash
copy .env.example .env.local
npm install
npm run dev
```

Mở [http://localhost:3000](http://localhost:3000). Giao diện mặc định tiếng Việt (`/`); bản tiếng Anh tại `/en`.

Sao chép biến môi trường từ `.env.example`. Chưa cần khóa Supabase thật ở M0.

## Lệnh kiểm tra

```bash
npm run lint
npx tsc --noEmit
npm test
npm run build
```

## Supabase CLI (cấu hình local, chưa khởi động stack)

CLI được cài như devDependency (`npx supabase`). Thư mục `supabase/` đã `init` sẵn.

```bash
npx supabase --version
```

Khi có Docker (CI / máy mạnh hơn, từ M1):

```bash
npx supabase db reset
npx supabase test db
```

## Cấu trúc chính

Xem `docs/SPEC.md` mục 5. Code ứng dụng nằm trong `src/` (App Router, `features/`, `messages/` cho i18n).
