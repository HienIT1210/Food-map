# ARCHITECTURE

Agent mô tả kiến trúc thực tế khi triển khai: luồng dữ liệu, cách client truy cập Supabase,
view công khai `public_reviews` (và vì sao nó chạy với quyền chủ sở hữu), RPC, Edge Functions.

## M0 — khung ứng dụng

- **Next.js App Router** trong `src/app/[locale]/`. Routing locale do `next-intl` (`src/proxy.ts`, `src/i18n/`).
- **Phân lớp feature** (chưa có logic): `src/features/{auth,map,restaurants,reviews,saved,moderation,profile}` — sau này: `components/` → `hooks/` → `repository.ts`. Component không gọi Supabase trực tiếp.
- **i18n**: chuỗi UI trong `src/messages/vi.json` và `en.json`.
- **Supabase**: chỉ có `supabase/config.toml` + thư mục migrations/functions/tests trống. Client JS và schema sẽ thêm từ M1/M2.
- **CI**: job `verify` (lint, `tsc`, Vitest, build) chạy mọi PR. Job `database` dùng `supabase db start` + `supabase test db` trên Ubuntu khi đã có migration SQL.

## Cập nhật M1: View công khai và Quyền truy cập
- Để đảm bảo tính năng ẩn danh hoạt động an toàn mà người dùng không thể can thiệp bằng cách query trực tiếp DB, bảng `reviews` bị đóng chặt (chỉ tác giả mới được SELECT). 
- View `public_reviews` được dùng làm cổng truy cập công khai. View này được cấu hình chạy với quyền của chủ sở hữu (bằng cách bỏ qua `security_invoker = on` hoặc thiết lập `security_invoker = off` theo mặc định của PostgreSQL). Do chạy bằng quyền chủ sở hữu, view này sẽ bypass RLS của bảng `reviews` để trả về danh sách, nhưng nó **được chọn lọc kỹ lưỡng** để không bao giờ trả về `user_id` thật nếu `is_anonymous` là true, đồng thời lọc luôn những user bị chặn (dựa vào bảng `blocks`).
- Thiết kế này ngăn chặn lộ thông tin từ network layer, vì Supabase auto-generates REST/GraphQL API từ View mà không có cột `author_id` thật cho những bài ẩn danh.