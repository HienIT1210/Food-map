# PROGRESS — Trạng thái dự án (bộ nhớ chung giữa các agent)

> Mọi agent phải đọc file này đầu phiên và cập nhật cuối mỗi bước nhỏ. Nếu file này mâu thuẫn với code/git thì tin code/git và sửa file này.

**Cập nhật lần cuối:** 2026-10-05 07:30 (UTC+7) bởi Antigravity

---

## 1. Trạng thái hiện tại

- **Milestone đang làm:** M1/M2 — chuẩn hóa test pgTAP và hoàn thiện bước mô phỏng Cloud trong CI
- **Tình trạng:**
  - Bước mô phỏng Cloud trong CI:
    - Làm sạch public schema và khôi phục toàn bộ quyền mặc định của Supabase: `GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role`, `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES/FUNCTIONS/SEQUENCES TO anon, authenticated, service_role`.
    - Dọn dẹp `auth.users` (`DELETE FROM auth.users;`) trước khi áp dụng seed để tránh lỗi trùng lặp khóa chính `users_pkey`.
    - Áp dụng các file migration và seed với `PGOPTIONS="-c search_path=public"` và `-v ON_ERROR_STOP=1`.
  - Kiểm thử RLS:
    - Bổ sung kiểm chứng trong T4.3 (01_rls_test.sql): User B truy cập được review của chính mình (chứng minh có quyền SELECT trên bảng, không bị permission denied) nhưng không thấy review của User A (chứng minh thứ chặn là RLS).
    - Giữ nguyên số test: 16 test trong `01_rls_test.sql` và 4 test trong `02_auth_trigger_test.sql` -> Tổng cộng 20 test (Files=2, Tests=20).
- **Nhánh git đang dùng:** main

## 2. Tiến độ milestone

- [x] M0 — Khởi tạo repo, CI, cấu trúc
- [ ] M1 — Schema, RLS, view công khai, RPC, seed, test RLS (16/16 pgTAP tests)
- [ ] M2 — Xác thực (Google/Email), khách, hồ sơ, xóa tài khoản (4/4 pgTAP tests)
- [ ] M3 — Bản đồ, clustering, thẻ quán, bộ lọc
- [ ] M4 — Tìm kiếm có dấu/không dấu, chi tiết quán, danh sách review
- [ ] M5 — Viết/sửa/xóa review, ảnh (xóa EXIF), ẩn danh, giới hạn chống lạm dụng
- [ ] M6 — Thêm quán bằng ghim, kiểm tra trùng
- [ ] M7 — Chỉ đường, lưu quán, chia sẻ
- [ ] M8 — Báo cáo, chặn, kiểm duyệt, trang quản trị, pháp lý
- [ ] M9 — PWA hoàn chỉnh, E2E, tối ưu, triển khai

## 3. Đang làm dở (QUAN TRỌNG cho agent tiếp quản)

> Nếu không có gì dở dang, ghi "Không có".

- **Việc:** Đẩy commit sửa CI (dọn auth.users + khôi phục default privileges) và test T4.3 RLS vs permission denied, chờ CI xác nhận Files=2, Tests=20.
- **File liên quan:** `supabase/tests/01_rls_test.sql`, `.github/workflows/ci.yml`
- **Dở ở chỗ nào / vì sao dừng:** Chờ CI GitHub Actions chạy.
- **Có commit `wip:` chưa:** không

## 4. Bước tiếp theo (3 việc cụ thể, theo thứ tự)

1. Đọc kết quả CI trên GitHub Actions: xác nhận Tests=16 (01_rls_test.sql) và Tests=4 (02_auth_trigger_test.sql), tổng cộng Files=2, Tests=20 xanh, có CURRENT_USER: authenticated và AUTH.UID() là UUID.
2. Kiểm chứng DoD M1 và M2 đạt yêu cầu, đánh dấu hoàn thành M1, M2.
3. Chuyển sang M3 (Bản đồ và MapLibre GL JS).

## 5. Lệnh chạy / kiểm tra

```
Chạy dev:        npm run dev
Lint:            npm run lint
Type-check:      npx tsc --noEmit
Test:            npm test
Reset database:  npx supabase db reset   # cần Docker; không chạy trên máy Windows 8GB
Test RLS:        npx supabase test db    # chỉ trên CI / máy có Docker
E2E:             npx playwright test     # chưa cài; M9
```

## 6. Quyết định đã chốt (không đổi khi chưa hỏi người dùng)

- Nền tảng: web PWA, mobile-first (không làm app native ở giai đoạn này)
- Stack: Next.js (App Router) + TypeScript strict + Tailwind + Supabase + MapLibre GL JS
- Review = bình luận (không có hệ thống bình luận riêng)
- Ẩn danh = ẩn với người dùng khác, không phải ẩn với quản trị; ẩn danh làm bằng view công khai không chứa `user_id`
- Đăng nhập: Google + Email/Mật khẩu; chế độ Khách chỉ xem, chỉ mở popup đăng nhập đúng lúc cần ghi
- Xóa tài khoản: Edge Function `delete-account` dùng service role key, xóa user trong Auth dẫn tới cascade profile & review
- Chỉ đường: mở liên kết Google Maps/Apple Maps, không dẫn đường trong app
- Máy Windows 8GB: không Docker, không `supabase start`; RLS/pgTAP chạy trên GitHub Actions từ M1
- Next.js 16.3.8 + Tailwind 4.3.3 + next-intl 4.14.9 (vi mặc định, `/en` cho English)
- Tất cả hàm pgTAP trong test phải gọi kèm schema `extensions.*` và search_path phải phục hồi `public, extensions;` sau khi thử nghiệm ngữ cảnh cô lập `public`.

## 7. Giả định (chi tiết hơn ở `docs/ASSUMPTIONS.md`)

- PWA M0 chỉ web app manifest; Serwist ở M9
- `localePrefix: as-needed` nên `/` = tiếng Việt
- Job CI `database` chạy tự động khi có migration
- View `public_reviews` chạy với quyền invoker=off (chủ sở hữu)
- Email auth: dùng email/mật khẩu kết hợp Google OAuth; xóa tài khoản qua Edge Function
- `set local search_path` là utility statement, tách thành lệnh riêng biệt với câu lệnh SELECT test.

## 8. Vấn đề / bug đã biết

- `jsdom@30.1.1` cảnh báo engine trên Node 24.11.1 (yêu cầu ≥ 24.15). `npm test` vẫn pass trên máy này.
- `next dev` tự thêm khối luật Next.js vào cuối `AGENTS.md`; nội dung luật repo gốc được giữ nguyên.
- Deno Edge Functions trong `supabase/functions` được exclude khỏi `tsconfig.json` của Next.js để tránh xung đột kiểu type giữa Node và Deno.

## 9. Nhật ký bàn giao

| Thời gian | Agent/Tool | Đã làm gì | Commit |
|---|---|---|---|
| 2026-10-04 | Cursor Grok | M0: Next.js 16 + Tailwind 4 + next-intl + Vitest + supabase init + CI; `npm run dev` OK | 85a8c73 |
| 2026-10-04 | Antigravity | M1: Tạo schema, RLS policies, trigger chống lạm dụng, RPC tìm kiếm/bản đồ, view `public_reviews`, seed & test RLS. | 45c09ec |
| 2026-10-04 | Antigravity | M1: Sửa logic test RLS, thêm diag cho auth.uid(), sửa CI start DB | a9b8d80 |
| 2026-10-04 | Antigravity | M2: Auth (Google + Email), Profile, Chế độ Khách, Xóa tài khoản (Edge Function), migration trigger profile & pgTAP | aac0909 |
| 2026-10-04 | Antigravity | fix(tests): sửa syntax error `set local` trong scalar subquery — T10-T14 (01) và T4 (02) | a0895a6 |
| 2026-10-04 | Antigravity | fix(tests): gọi pgTAP qua `extensions.*`, chuẩn hóa phục hồi search_path và mô phỏng Cloud trong CI | 15faf09 |
| 2026-10-05 | Antigravity | fix(ci): dọn auth.users + cấp lại default privileges trên public trong mô phỏng Cloud; bổ sung kiểm chứng RLS vs permission denied | [pending] |
