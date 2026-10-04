# ASSUMPTIONS

Agent ghi các giả định đã tự chọn (kèm lý do ngắn và ngày) vào đây thay vì dừng lại hỏi.

| Ngày | Giả định | Lý do | Agent |
|---|---|---|---|
| 2026-10-03 | Next.js **16.3.8** (App Router, Turbopack mặc định), React 19.2.8, Tailwind CSS **4.3.3**, TypeScript 5.9.3 `strict`, `@types/node` 24.19.1 | `create-next-app@16.3.8` + Node 24 trên máy dev; Vitest 5 yêu cầu `@types/node` ≥ 22 | Cursor Grok |
| 2026-10-03 | i18n: `next-intl@4.14.9`, locale mặc định `vi`, khung `en`, `localePrefix: 'as-needed'` | SPEC yêu cầu tiếng Việt mặc định; URL `/` không cần tiền tố `/vi` | Cursor Grok |
| 2026-10-03 | PWA M0 chỉ có `src/app/manifest.ts` (web app manifest). Chưa cài Serwist/service worker | DoD M0 ghi manifest cơ bản; PWA đầy đủ thuộc M9 | Cursor Grok |
| 2026-10-03 | Máy Windows 8GB không chạy Docker/`supabase start`. Job CI `database` chỉ chạy khi có file `supabase/migrations/*.sql` | Tránh OOM trên máy dev; kiểm thử RLS/pgTAP làm trên GitHub Actions từ M1 | Cursor Grok |
| 2026-10-03 | Email auth (chi tiết magic link vs mật khẩu) chưa chọn ở M0 | Thuộc M2 | Cursor Grok |