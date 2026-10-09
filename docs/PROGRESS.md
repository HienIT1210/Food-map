# PROGRESS — Trạng thái dự án (bộ nhớ chung giữa các agent)

> Mọi agent phải đọc file này đầu phiên và cập nhật cuối mỗi bước nhỏ. Nếu file này mâu thuẫn với code/git thì tin code/git và sửa file này.

**Cập nhật lần cuối:** 2026-10-09 bởi Codex

---

## 1. Trạng thái hiện tại

- **Milestone hiện tại:** M5 — đang triển khai luồng viết/sửa/xóa review, upload ảnh, ẩn danh và nút hữu ích. M4 CI xanh và migration đã `db push` theo xác nhận của người dùng.
- **Đã có trong code:** MapLibre, clustering, nút vị trí, worker postinstall, attribution control, dữ liệu seed.
- **Đã xong:** M3 theo xác nhận của người dùng; M0–M2 cũng đã hoàn tất.
- **Đã xác nhận:** Người dùng báo CI đã pass và đã chạy `db push` lên cloud. Test T6/T11 dùng `lim=50`; CI trước đó xác nhận `Test Phở` ở vị trí 11 với `lim=10`, nên test dùng limit nhỏ bị ảnh hưởng bởi top-N chứ RPC không lỗi.
- **M5 đã thêm trong working tree:** migration `20261009150000_m5_review_writes.sql`; RPC ghi/xóa/đánh dấu hữu ích; storage bucket và quyền ảnh; giới hạn ảnh 5, tài khoản ẩn danh xác minh email + tuổi tối thiểu 24h; tính lại điểm/số review; composer và xử lý ảnh canvas xóa EXIF.
- **Còn lại:** M5 chưa được xác nhận hoàn tất. Migration chưa `db push`; pgTAP mới chưa chạy trên database; bốn lệnh ứng dụng và CI cuối còn chờ. M4 chưa có xác nhận kiểm tra UI thủ công.
- **Kiểm tra M5 local 2026-10-09:** `npm run lint` pass; `npx tsc --noEmit` pass; `npm test` pass (8 files / 18 tests); `npm run build` pass (Next.js compile, TypeScript, static generation). Build cần chạy ngoài sandbox do Windows DACL chặn SWC; không chạy được Supabase pgTAP local vì máy dev không dùng Docker.
- **Nhánh:** `main`; đang có thay đổi M5 chưa commit.

## 2. Tiến độ milestone

- [x] M0 — Khởi tạo repo, CI, cấu trúc
- [x] M1 — Schema, RLS, view công khai, RPC, seed; security follow-up CI xanh (38+4 pgTAP assertions)
- [x] M2 — Xác thực (Google/Email), khách, hồ sơ, xóa tài khoản (4/4 pgTAP tests)
- [x] M3 — MapLibre, vị trí, tải vùng, clustering, thẻ, bộ lọc và list (người dùng xác nhận đã xong)
- [x] M4 — Tìm kiếm có dấu/không dấu, chi tiết quán, danh sách review; local checks và CI pass theo xác nhận người dùng, migration đã `db push`; còn checklist UI thủ công chưa được xác nhận
- [ ] M5 — Đang triển khai; code và test mới trong working tree, migration cần CI và người dùng `db push` trước khi xác nhận DoD
- [ ] M6 — Thêm quán bằng ghim, kiểm tra trùng
- [ ] M7 — Chỉ đường, lưu quán, chia sẻ
- [ ] M8 — Báo cáo, chặn, kiểm duyệt, trang quản trị, pháp lý
- [ ] M9 — PWA hoàn chỉnh, E2E, tối ưu, triển khai

## 3. Đang làm dở (QUAN TRỌNG cho agent tiếp quản)

- **Việc:** M5.
- **File liên quan:** `src/features/reviews/`, `src/features/restaurants/`, `src/messages/{vi,en}.json`, `supabase/migrations/20261009150000_m5_review_writes.sql`, `supabase/tests/08_m5_review_write_test.sql`.
- **Dở ở đâu:** CI của commit M5 và pgTAP 08 còn chờ; migration cần người dùng `db push` sau CI; chưa kiểm tra tay M5. Chưa nhận kết quả kiểm tra tay M4.
- **Có commit `wip:` chưa:** Không.

## 4. Bước tiếp theo (3 việc cụ thể, theo thứ tự)

1. Commit và push thay đổi M5; chờ người dùng dán trạng thái job app/database của CI.
2. Sau khi CI database xanh, người dùng chạy `supabase db push` để áp dụng `20261009150000_m5_review_writes.sql`.
3. Kiểm tra tay: đăng review thường có món/ảnh, xem ảnh hiển thị và giới hạn 5; sửa cùng cặp quán+món rồi xác nhận không tạo hàng thứ hai; xóa trong “Review của tôi” và xác nhận ảnh đi theo; bấm Hữu ích trên review người khác (không được trên review của mình); tạo tài khoản chưa đủ 24h/chưa xác minh và thử đăng ẩn danh; xác nhận review thứ 11 trong 24h bị server từ chối; DevTools xem response review ẩn danh không có `user_id`/UUID chủ review trong đường dẫn ảnh. Không sang M6.

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
- Dev dùng Supabase cloud, không dùng Docker ở máy; test database chạy trên GitHub Actions (có bước mô phỏng cloud với search_path=public)
- Không nạp seed.sql lên cloud (nó chứa người dùng giả trong auth.users)
- `profiles` chỉ cho `authenticated` cập nhật `display_name` và `avatar_url`; các cột `role` và `is_banned` bị giới hạn bằng column privileges.
- Review insert phải kiểm tra trạng thái `profiles.is_banned`; photo path không được chứa UUID chủ review khi review ẩn danh.

## 7. Giả định (chi tiết hơn ở `docs/ASSUMPTIONS.md`)

- PWA M0 chỉ web app manifest; Serwist ở M9
- `localePrefix: as-needed` nên `/` = tiếng Việt
- Job CI `database` chạy tự động khi có migration
- View `public_reviews` chạy với quyền invoker=off (chủ sở hữu)
- Email auth: dùng email/mật khẩu kết hợp Google OAuth; xóa tài khoản qua Edge Function
- `set local search_path` là utility statement, tách thành lệnh riêng biệt với câu lệnh SELECT test.

## 8. Vấn đề / bug đã biết
- M3: không có cột giờ mở cửa; chip “Đang mở cửa” chưa áp dụng cho dữ liệu hiện tại. Bộ lọc và metadata danh sách được thêm bằng migration mới; phải chạy `supabase db push` trên cloud.
- Security 2026-10-08: migration `20261008100000_harden_user_write_privileges.sql` chưa áp dụng cloud. Test-first branch `security/m3-privilege-tests-first` (`5cf329f`) và intentional mutation branch `security/m3-privilege-mutation` (`7becc17`) đã push; PR/pgTAP CI evidence còn chờ do Actions API/PR không truy cập được trong môi trường này. Xem `docs/SECURITY-TESTS.md`.
- 2026-10-08: sửa nguyên nhân test DB đỏ: stale JWT claim khi `set role postgres`, seed rating bị insert trigger canonicalize về 0, `handle_new_user` tự tạo profile gây trùng PK; thêm fixture rules vào `docs/SECURITY-TESTS.md`. Bốn lệnh ứng dụng pass; chờ CI log database, không `db push`.

- M3: chưa kiểm tra thủ công kéo/zoom và từ chối quyền vị trí; CI cho commit `92249b0` xanh ở cả hai job (run 37616916247). Chưa xác nhận lại thủ công trên phiên bản postinstall; chưa chuyển M4.
- Worker MapLibre là asset sinh tự động trong `public/maplibre`; sau khi nâng `maplibre-gl`, `postinstall` cần copy lại hai file worker/shared.

- `jsdom@30.1.1` cảnh báo engine trên Node 24.11.1 (yêu cầu ≥ 24.15). `npm test` vẫn pass trên máy này.
- `next dev` tự thêm khối luật Next.js vào cuối `AGENTS.md`; nội dung luật repo gốc được giữ nguyên.
- Deno Edge Functions trong `supabase/functions` được exclude khỏi `tsconfig.json` của Next.js để tránh xung đột kiểu type giữa Node và Deno.
- M4 dùng migration `20261009100000_m4_search_and_restaurant_detail.sql` (thay RPC `search_restaurants`, thêm `restaurant_detail`, index trigram/cursor); người dùng xác nhận đã `db push`. Search/detail RPC là `security invoker`, có `set search_path = public, extensions`, grant execute tường minh cho `anon, authenticated`.
- M4 review client chỉ query `public_reviews` với danh sách cột tường minh và schema strict; không chọn `author_id`, `user_id` hoặc avatar, và nhãn ẩn danh không có liên kết hồ sơ. Có unit test kiểm tra request/response giả lập và pgTAP chạy dưới `anon`.
- Schema hiện không có cột/nguồn ảnh cho quán hoặc review; M4 chỉ hiển thị danh sách món, chưa thêm ảnh hay triển khai viết review (M5).
- Hướng dẫn tự kiểm tra M4 sau `db push`: (1) tìm `pho bo`, xác nhận món/quán “phở bò” xuất hiện; thử một lỗi nhỏ như `pho bee`, tên quán và địa chỉ không dấu; (2) chọn kết quả, xác nhận bản đồ bay tới pin; bấm pin/thẻ “Xem chi tiết”; (3) xem địa chỉ, điểm, số review, món/giá; thử Google Maps, Apple Maps và Chia sẻ; (4) đổi review giữa mới nhất/hữu ích/sao cao/sao thấp, tải trang kế; (5) dùng fixture có review ẩn danh, xác nhận “Thực khách ẩn danh” và không có link hồ sơ; trong DevTools Network mở phản hồi `public_reviews`, xác nhận không có khóa/giá trị `user_id`; (6) thử trạng thái rỗng và ngắt mạng để xem lỗi/thử lại. Không tạo review mới vì viết review thuộc M5.
- M4 local checks 2026-10-09: lint, typecheck, npm test (7 files / 17 tests), build đều pass với `SWC_NATIVE_BINDING_CACHE=0`; người dùng xác nhận CI pass và migration đã được đẩy lên cloud.
- M5 2026-10-09: thêm RPC bảo vệ ghi/sửa/xóa review, “Review của tôi”, vote hữu ích, Storage ảnh, giới hạn 5 ảnh, giới hạn review 10/ngày khóa theo tài khoản và điều kiện ẩn danh. Canvas giới hạn cạnh 1600px/nén JPEG 0.8/xóa EXIF; test ảnh có EXIF đầu vào và pgTAP plan(13). Bốn lệnh ứng dụng local pass; pgTAP/CI và kiểm tra tay còn chờ. Migration `20261009150000_m5_review_writes.sql` chưa `db push`.

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
| 2026-10-05 | Người dùng (tự cập nhật) | Xác nhận M1: CI xanh (20 test), đã `supabase db push` lên cloud, RLS bật ở mọi bảng, trigger tạo hồ sơ có mặt | (hash commit mới nhất) |
| 2026-10-05 | GitHub Copilot | M1 security follow-up: T5 fixture riêng, 22 assertions mới, migration hardening; PR #2 CI xanh ở run #28 | `71e841c` |
| 2026-10-05 | GitHub Copilot | Mutation checks 3(a)-3(c): T15-T18, T20, T21-T22 đỏ; PR #3 đóng không merge và nhánh mutation đã xóa; baseline khôi phục xanh run #32 | temporary commits not merged |
| 2026-10-06 | Codex | Sửa tương thích API react-map-gl/maplibre 8.1.3 + maplibre-gl 6.12.0; lint/tsc/test/build local pass. Kiểm tra tay + CI xanh còn chờ. | `d9ba42d` |
| 2026-10-07 | Codex | Sửa worker trắng MapLibre v6: postinstall copy hai module, client setWorkerUrl một chỗ có version query, proxy bỏ qua `/maplibre/*` có test. Generated worker bị gitignore. Bốn lệnh local pass; CI run 37616916247 success ở cả hai job; kiểm tra tay sau install sạch còn chờ. | `92249b0` |
| 2026-10-07 | Codex | M3: bộ lọc RPC, list view, find-area, BottomNav Map/List, unit + pgTAP tests; migration mới cần cloud db push. Chưa chuyển M4. | pending |
| 2026-10-08 | Codex | Thêm migration quyền theo cột/trigger, hardening limit và RPC cap/sort; bốn lệnh ứng dụng pass. DB CI/mutation PR chưa xác nhận; không `db push`, chưa sang M4. | `76b4f3d` |

- 2026-10-08 CI follow-up: 01_rls_test.sql T23 now expects SQLSTATE 42501 for UPDATE of system-managed restaurant fields; privileged readbacks confirm avg_rating, review_count, and status did not change. plan(38) and the three assertion slots remain unchanged. CI database result pending user log; no db push, mutation PR, or M4.

- 2026-10-08 mutation evidence: user confirmed main commit 4739d74 is green. PR #4 database job intentionally reports Files=6, Tests=77, Result=FAIL: 01 T23 and 05 R1/R3-R7 detect restored broad write grants; R2 reaches the daily-limit trigger and reports P0001 rather than expected 42501. PR remains unmerged; no db push or M4. See SECURITY-TESTS.md.
- 2026-10-09 user confirms M4 CI pass and cloud `db push` complete. M4 local checks pass; manual UI/Network checklist remains unconfirmed.
- 2026-10-09 M5 implementation prepared: local lint/tsc/test/build pass; pgTAP/CI, migration push, and manual verification pending. No work on M6.
