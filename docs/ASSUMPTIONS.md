# ASSUMPTIONS

Agent ghi các giả định đã tự chọn (kèm lý do ngắn và ngày) vào đây thay vì dừng lại hỏi.

| Ngày | Giả định | Lý do | Agent |
|---|---|---|---|
| 2026-10-03 | Next.js **16.3.8** (App Router, Turbopack mặc định), React 19.2.8, Tailwind CSS **4.3.3**, TypeScript 5.9.3 `strict`, `@types/node` 24.19.1 | `create-next-app@16.3.8` + Node 24 trên máy dev; Vitest 5 yêu cầu `@types/node` ≥ 22 | Cursor Grok |
| 2026-10-03 | i18n: `next-intl@4.14.9`, locale mặc định `vi`, khung `en`, `localePrefix: 'as-needed'` | SPEC yêu cầu tiếng Việt mặc định; URL `/` không cần tiền tố `/vi` | Cursor Grok |
| 2026-10-03 | PWA M0 chỉ có `src/app/manifest.ts` (web app manifest). Chưa cài Serwist/service worker | DoD M0 ghi manifest cơ bản; PWA đầy đủ thuộc M9 | Cursor Grok |
| 2026-10-03 | Máy Windows 8GB không chạy Docker/`supabase start`. Job CI `database` chỉ chạy khi có file `supabase/migrations/*.sql` | Tránh OOM trên máy dev; kiểm thử RLS/pgTAP làm trên GitHub Actions từ M1 | Cursor Grok |
| 2026-10-03 | Email auth (chi tiết magic link vs mật khẩu) chưa chọn ở M0 | Thuộc M2 | Cursor Grok |
| 2026-10-04 | Email auth: chọn phương án Email + Password (với emailRedirectTo callback) kết hợp Google OAuth | Thân thiện, phổ biến với người dùng mobile và dễ kiểm thử; đáp ứng AUTH-01 | Antigravity |
| 2026-10-04 | Xóa tài khoản (AUTH-04): thực hiện qua Edge Function `delete-account` sử dụng service role để gọi `auth.admin.deleteUser()`, kích hoạt cascade xóa profiles và reviews | Tuân thủ bảo mật, không để lộ service role key ra client | Antigravity |

- M1: Giả định rằng Supabase trên môi trường CI và production hỗ trợ thiết lập `security_invoker = off` (hoặc cú pháp `with (security_invoker = off)`) cho view để kích hoạt quyền truy cập bằng quyền sở hữu, phục vụ cho view `public_reviews`. Giả định `unaccent` và `pg_trgm` được phép cài đặt vào schema `extensions`.