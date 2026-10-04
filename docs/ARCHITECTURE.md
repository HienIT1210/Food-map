# ARCHITECTURE

Agent mô tả kiến trúc thực tế khi triển khai: luồng dữ liệu, cách client truy cập Supabase,
view công khai `public_reviews` (và vì sao nó chạy với quyền chủ sở hữu), RPC, Edge Functions.

## M0 — khung ứng dụng

- **Next.js App Router** trong `src/app/[locale]/`. Routing locale do `next-intl` (`src/proxy.ts`, `src/i18n/`).
- **Phân lớp feature** (chưa có logic): `src/features/{auth,map,restaurants,reviews,saved,moderation,profile}` — sau này: `components/` → `hooks/` → `repository.ts`. Component không gọi Supabase trực tiếp.
- **i18n**: chuỗi UI trong `src/messages/vi.json` và `en.json`.
- **Supabase**: chỉ có `supabase/config.toml` + thư mục migrations/functions/tests trống. Client JS và schema sẽ thêm từ M1/M2.
- **CI**: job `verify` (lint, `tsc`, Vitest, build) chạy mọi PR. Job `database` dùng `supabase db start` + `supabase test db` trên Ubuntu khi đã có migration SQL.