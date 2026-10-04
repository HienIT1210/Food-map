# PROGRESS — Trạng thái dự án (bộ nhớ chung giữa các agent)

> Mọi agent phải đọc file này đầu phiên và cập nhật cuối mỗi bước nhỏ. Nếu file này mâu thuẫn với code/git thì tin code/git và sửa file này.

**Cập nhật lần cuối:** 2026-10-04 11:35 (UTC+7) bởi Antigravity

---

## 1. Trạng thái hiện tại

- **Milestone đang làm:** M1 (DoD đã chuẩn bị xong, chờ chạy CI)
- **Tình trạng:** hoàn thành code M1 (Schema, RLS, view, RPC, seed, pgTAP test)
- **Nhánh git đang dùng:** main

## 2. Tiến độ milestone

- [x] M0 — Khởi tạo repo, CI, cấu trúc
- [x] M1 — Schema, RLS, view công khai, RPC, seed, test RLS
- [ ] M2 — Xác thực (Google/Email), khách, hồ sơ, xóa tài khoản
- [ ] M3 — Bản đồ, clustering, thẻ quán, bộ lọc
- [ ] M4 — Tìm kiếm có dấu/không dấu, chi tiết quán, danh sách review
- [ ] M5 — Viết/sửa/xóa review, ảnh (xóa EXIF), ẩn danh, giới hạn chống lạm dụng
- [ ] M6 — Thêm quán bằng ghim, kiểm tra trùng
- [ ] M7 — Chỉ đường, lưu quán, chia sẻ
- [ ] M8 — Báo cáo, chặn, kiểm duyệt, trang quản trị, pháp lý
- [ ] M9 — PWA hoàn chỉnh, E2E, tối ưu, triển khai

## 3. Đang làm dở (QUAN TRỌNG cho agent tiếp quản)

> Nếu không có gì dở dang, ghi "Không có".

- **Việc:** Không có. (Người dùng sẽ tự push code và theo dõi CI GitHub Actions để verify Supabase database migration và pgTAP tests).
- **File liên quan:** —
- **Dở ở chỗ nào / vì sao dừng:** —
- **Có commit `wip:` chưa:** không

## 4. Bước tiếp theo (3 việc cụ thể, theo thứ tự)

1. M2: Thiết lập Supabase Auth cho Google và Email (magic link hoặc password).
2. M2: Tạo logic Auth trên client (Next.js server/client components), xử lý chế độ Khách (chỉ xem, không ghi).
3. M2: Xây dựng UI và Edge function xóa tài khoản.

## 5. Lệnh chạy / kiểm tra

```
Chạy dev:        npm run dev
Lint:            npm run lint
Type-check:      npx tsc --noEmit
Test:            npm test
Reset database:  npx supabase db reset   # cần Docker; không chạy trên máy Windows 8GB
Test RLS:        npx supabase test db    # chỉ trên CI / máy có Docker, từ M1
E2E:             npx playwright test     # chưa cài; M9
```

## 6. Quyết định đã chốt (không đổi khi chưa hỏi người dùng)

- Nền tảng: web PWA, mobile-first (không làm app native ở giai đoạn này)
- Stack: Next.js (App Router) + TypeScript strict + Tailwind + Supabase + MapLibre GL JS
- Review = bình luận (không có hệ thống bình luận riêng)
- Ẩn danh = ẩn với người dùng khác, không phải ẩn với quản trị; ẩn danh làm bằng view công khai không chứa `user_id`
- Đăng nhập: Google + Email; chế độ Khách chỉ xem
- Chỉ đường: mở liên kết Google Maps/Apple Maps, không dẫn đường trong app
- Máy Windows 8GB: không Docker, không `supabase start`; RLS/pgTAP chạy trên GitHub Actions từ M1
- Next.js 16.3.8 + Tailwind 4.3.3 + next-intl 4.14.9 (vi mặc định, `/en` cho English)

## 7. Giả định (chi tiết hơn ở `docs/ASSUMPTIONS.md`)

- PWA M0 chỉ web app manifest; Serwist ở M9
- `localePrefix: as-needed` nên `/` = tiếng Việt
- Job CI `database` skip khi chưa có `supabase/migrations/*.sql`
- View `public_reviews` chạy với quyền invoker=off (tức là chủ sở hữu) để vượt qua RLS và áp dụng cơ chế lọc ẩn danh.

## 8. Vấn đề / bug đã biết

- `jsdom@30.1.1` cảnh báo engine trên Node 24.11.1 (yêu cầu ≥ 24.15). `npm test` vẫn pass trên máy này. GitHub Actions dùng `node-version: "24"` (bản 24 mới hơn).
- `next dev` tự thêm khối luật Next.js vào cuối `AGENTS.md`; nội dung luật repo gốc được giữ nguyên.

## 9. Nhật ký bàn giao

| Thời gian | Agent/Tool | Đã làm gì | Commit |
|---|---|---|---|
| 2026-10-04 | Cursor Grok | M0: Next.js 16 + Tailwind 4 + next-intl + Vitest + supabase init + CI; `npm run dev` OK | 85a8c73 |
| 2026-10-04 | Antigravity | M1: Tạo schema, RLS policies, trigger chống lạm dụng, RPC tìm kiếm/bản đồ, view `public_reviews`, seed & test RLS. | [pending commit] |
