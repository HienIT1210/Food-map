# PROGRESS — Trạng thái dự án (bộ nhớ chung giữa các agent)

> Mọi agent phải đọc file này đầu phiên và cập nhật cuối mỗi bước nhỏ. Nếu file này mâu thuẫn với code/git thì tin code/git và sửa file này.

**Cập nhật lần cuối:** 2026-10-09 bởi DeepSeek Harness (tiếp quản M5)

---

## 1. Trạng thái hiện tại

- **Milestone hiện tại:** M5 — viết/sửa/xóa review, upload ảnh (xóa EXIF), ẩn danh, "Hữu ích", giới hạn chống lạm dụng.
- **M4:** CI xanh và migration `20261009100000_m4_search_and_restaurant_detail.sql` đã `db push` lên cloud (người dùng xác nhận).
- **Đã xong theo commit:** M0–M3 (người dùng xác nhận), M4 (CI xanh + đã push).
- **M5 nằm trong commit `2d3f083`** (`feat: add M5 review writing and photos`): migration `20261009150000_m5_review_writes.sql`, `supabase/tests/08_m5_review_write_test.sql`, `src/features/reviews/*` (ReviewComposer, ReviewList, ReviewCard, MyReviews, image-processing, repository, types), `ProfileView`, i18n `vi.json`/`en.json`.
- **Còn lại:** commit M5 chưa push; CI (job `verify` + job `database`) chưa xác nhận; migration M5 chưa `db push`; kiểm tra tay M5 chưa chạy.
- **Kiểm tra local phiên này (2026-10-09):** `npm run lint` pass; `npx tsc --noEmit` pass; `npm test` pass (8 files / 18 tests); `npm run build` pass. `npm test` và `npm run build` phải chạy ngoài sandbox — xem mục 8.

## 2. Tiến độ milestone

- [x] M0 — Khởi tạo repo, CI, cấu trúc
- [x] M1 — Schema, RLS, view công khai, RPC, seed; security follow-up CI xanh (38+4 pgTAP assertions)
- [x] M2 — Xác thực (Google/Email), khách, hồ sơ, xóa tài khoản (4/4 pgTAP tests)
- [x] M3 — MapLibre, vị trí, tải vùng, clustering, thẻ, bộ lọc và list (người dùng xác nhận đã xong)
- [x] M4 — Tìm kiếm có/không dấu, chi tiết quán, danh sách review; CI xanh, migration đã `db push`; checklist UI thủ công còn chờ
- [ ] M5 — Code + migration + test đã có; đang chờ CI xanh, `db push` và kiểm tra tay. **Chưa xác nhận DoD.**
- [ ] M6 — Thêm quán bằng ghim, kiểm tra trùng
- [ ] M7 — Chỉ đường, lưu quán, chia sẻ
- [ ] M8 — Báo cáo, chặn, kiểm duyệt, trang quản trị, pháp lý
- [ ] M9 — PWA hoàn chỉnh, E2E, tối ưu, triển khai

## 3. Đang làm dở (QUAN TRỌNG cho agent tiếp quản)

- **Việc:** M5. Migration M5 đã được sửa trực tiếp (chưa áp dụng cloud nên còn được phép sửa file).
- **File liên quan:** `supabase/migrations/20261009150000_m5_review_writes.sql`, `supabase/tests/01_rls_test.sql`, `supabase/tests/05_security_privileges_test.sql`, `supabase/tests/09_m5_review_rules_test.sql` (mới), `supabase/functions/delete-account/index.ts`, `docs/SECURITY-TESTS.md`.
- **Dở ở chỗ nào / vì sao dừng:** CI database chưa chạy lại sau các sửa đổi M5; pgTAP không chạy được ở máy Windows này (không Docker). Mutation check cho quy tắc bảo mật mới còn phải chạy trên nhánh riêng và dán log CI.
- **Có commit `wip:` chưa:** Không.

### 3.1. Hai file agent trước để dở và cách xử lý

1. `docs/PROGRESS.md`: bản chưa commit đã **ghi đè** nội dung HEAD bằng một bản cũ hơn (lùi về 2026-10-06, nói "đang làm M3"), làm mất lịch sử M3/M4/M5 và các quyết định. Đã khôi phục toàn bộ lịch sử và cập nhật lại theo thực tế (file này).
2. `supabase/tests/01_rls_test.sql`: bản chưa commit gồm 4 nhóm thay đổi:
   - **Đúng hướng:** T23–T25 đổi từ `throws_ok(...42501)` sang đọc lại giá trị sau `UPDATE` (giữ nguyên 3 slot). Giữ lại.
   - **Sai (đã hoàn nguyên):** T6/T11 bị hạ `lim` từ 50 về 10 kèm đổi tên test. Đây là tái phạm lỗi top-N đã có bằng chứng CI trong `docs/SECURITY-TESTS.md`; đã trả về `lim=50` và tên test gốc.
   - **Sai (đã hoàn nguyên):** xóa `set local role postgres; set local "request.jwt.claims" to '{}';` ngay trước block fixture giới hạn. Thiếu dòng này thì JWT claim cũ (User B) còn hiệu lực và trigger gán quán cho User B.
   - **Thiếu (đã bổ sung):** T8/T20/T22/T33/T34–T36 viết theo mô hình cũ (authenticated ghi trực tiếp được). M5 đã thu hồi quyền ghi bảng nên phải cập nhật lại — xem mục 6.

## 4. Bước tiếp theo (3 việc cụ thể, theo thứ tự)

1. Push nhánh và chờ CI; nếu job `database` đỏ thì thêm `diag()` để lấy bằng chứng rồi sửa theo đúng nguyên nhân.
2. Người dùng đọc migration rồi tự chạy `supabase db push` (agent không chạy).
3. Chạy checklist kiểm tra tay M5 ở mục 5.2, sau đó mới đánh dấu DoD M5 và **không sang M6**.

## 5. Lệnh chạy / kiểm tra

```
Chạy dev:        npm run dev
Lint:            npm run lint
Type-check:      npx tsc --noEmit
Test:            npm test                     # cần chạy NGOÀI sandbox (xem mục 8)
Build:           npm run build                # cần chạy NGOÀI sandbox (xem mục 8)
Reset database:  npx supabase db reset   # cần Docker; không chạy trên máy Windows này
Test RLS:        npx supabase test db    # chỉ trên CI / máy có Docker
E2E:             npx playwright test     # chưa cài; M9
```

### 5.1. Nội dung migration M5 cần đọc trước khi `db push`

`supabase/migrations/20261009150000_m5_review_writes.sql` (chưa áp dụng cloud, sửa trực tiếp được). Tóm tắt để đọc nhanh:

1. `check_review_limits()` — BEFORE INSERT trên `reviews`; khóa advisory theo `auth.uid()`, đếm review của chính người gọi trong 24h qua, ngưỡng lấy từ `app.review_daily_limit` (mặc định 10). Không đọc `new.user_id` do client gửi.
2. `save_review(restaurant, dish, rating, content, is_anonymous)` → upsert theo (người gọi, quán, món); kiểm tra rating 1–5, nội dung ≤ 2000, tài khoản không bị ban, quán `active`, món thuộc quán; **ẩn danh chỉ khi email đã xác minh và tài khoản ≥ 24h** (`app.anonymous_review_min_age`).
3. `delete_review(id)` — xóa file Storage của review rồi xóa review; chỉ chủ sở hữu.
4. `my_review_for_target`, `my_reviews` — trả bản ghi của chính người gọi, không trả `user_id`.
5. `toggle_review_helpful(id)` — không cho tự vote; chèn/xóa trong `review_helpful`; `helpful_count` do trigger tính lại từ bảng vote.
6. `add_review_photo(review_id, path, position)` — chỉ chủ review; **bắt buộc `path` bắt đầu bằng `review_id`**.
7. Thu hồi `insert/update/delete` trên `reviews`, `review_photos`, `review_helpful` khỏi `public, anon, authenticated`; chỉ cấp `execute` RPC cho `authenticated` (anon bị từ chối).
8. Storage bucket `review-photos`: `file_size_limit = 5 MiB`, `allowed_mime_types = {image/jpeg, image/webp}`; policy SELECT công khai, INSERT/DELETE chỉ cho chủ review khớp thư mục đầu = `review_id`; **không cấp UPDATE** (ảnh là write-once).
9. `enforce_review_photo_limit()` — tối đa 5 ảnh/review (trigger BEFORE INSERT), có khóa advisory.
10. `recalculate_restaurant_review_stats()` — tính lại `avg_rating`, `review_count` sau insert/delete/update rating|status; có backfill cho dữ liệu cũ.
11. `recalculate_review_helpful_count()` — tính lại `helpful_count` sau insert/delete vote.
12. `enforce_review_system_fields()` + trigger `trg_enforce_review_system_fields` — chặn người dùng tự đặt `status`, `helpful_count`, `created_at`, `updated_at`.
13. View `public_reviews` (`security_invoker = off`) — thêm `photo_paths`; vẫn mask `author_id`/`author_name`/`author_avatar` khi `is_anonymous`; **không có cột `user_id`**.

Đường dẫn ảnh do **client** tạo (`src/features/reviews/repository.ts`: `${reviewId}/${crypto.randomUUID()}.jpg`), **database** chỉ kiểm tra thư mục đầu = `review_id`, Storage policy kiểm tra chủ sở hữu review đó. Đường dẫn **không chứa `user_id`** — kể cả review ẩn danh. Trigger `enforce_anonymous_review_photo_path` chỉ là danh sách đen bổ sung; hàng rào thật là (a) quyền ghi bảng đã thu hồi, (b) ràng buộc path trong `add_review_photo`, (c) policy Storage theo chủ sở hữu.

### 5.2. Checklist kiểm tra tay M5 (sau `db push`)

1. Đăng nhập, mở một quán, viết review có món + 2 ảnh; xác nhận ảnh hiển thị và không quá 5 ảnh.
2. Sửa lại đúng cặp (quán, món) đó; xác nhận **không** sinh hàng review thứ hai.
3. "Review của tôi" → xóa review; xác nhận review biến mất và file ảnh cũng bị xóa trong Storage.
4. Bấm "Hữu ích" trên review người khác; xác nhận không bấm được trên review của chính mình.
5. Tạo tài khoản mới (chưa đủ 24h hoặc chưa xác minh email) → thử đăng ẩn danh; xác nhận bị server từ chối.
6. Đăng 11 review trong 24h; xác nhận review thứ 11 bị từ chối (thử cả bằng DevTools gọi trực tiếp RPC).
7. DevTools Network: mở phản hồi `public_reviews`; xác nhận **không** có `user_id`/`author_id` cho review ẩn danh, và `photo_paths` không chứa UUID người dùng.
8. Upload một tệp không phải ảnh (đổi đuôi thành `.jpg`); ghi lại hành vi thực tế của Storage (xem rủi ro còn lại ở mục 8).
9. Xóa tài khoản; xác nhận ảnh review của tài khoản đó cũng bị xóa khỏi Storage.

## 6. Thay đổi M5 trong phiên này (rút gọn)

- **Migration (sửa trực tiếp, chưa `db push`):** nối lại trigger `trg_enforce_review_system_fields` (hàm đã có nhưng trigger bị mất khi thay hàm ở M5); thêm ràng buộc độ dài `review_photos_storage_path_length (1..300)`; bỏ policy UPDATE trên `storage.objects` cho bucket ảnh review.
- **`delete-account` Edge Function:** dọn file trong Storage trước khi xóa user (cascade bảng không xóa file).
- **`01_rls_test.sql`:** hoàn nguyên 2 chỗ sai như mục 3.1; T8/T20/T22/T33 giữ nguyên `42501` (M5 từ chối mọi ghi trực tiếp — bất biến bảo mật không đổi, chỉ đổi lý do từ chối); T34–T37 chuyển sang đường ghi hợp lệ (`add_review_photo` cho chủ review, insert/update có đặc quyền cho fixture) để vẫn kiểm chứng đúng quy tắc ẩn danh; T38 mới: ghi metadata ảnh trực tiếp bị `42501`. Giữ nguyên `plan(38)`.
- **`05_security_privileges_test.sql`:** R20/R23 nay kiểm tra `authenticated` **không còn** quyền ghi bảng review/ảnh và **có** quyền `execute` RPC. Giữ nguyên `plan(24)`.
- **`09_m5_review_rules_test.sql` (mới, `plan(16)`):** quyền RPC của anon, quyền bảng của authenticated, điều kiện ẩn danh (đủ tuổi + đã xác minh email), một review cho mỗi (người dùng, quán, món), tối đa 5 ảnh, không tự vote, `helpful_count` tính từ bảng vote.

## 7. Quyết định đã chốt (không đổi khi chưa hỏi người dùng)

- Nền tảng: web PWA, mobile-first (không làm app native ở giai đoạn này)
- Stack: Next.js (App Router) + TypeScript strict + Tailwind + Supabase + MapLibre GL JS
- Review = bình luận (không có hệ thống bình luận riêng)
- Ẩn danh = ẩn với người dùng khác, không phải ẩn với quản trị; ẩn danh làm bằng view công khai không chứa `user_id`
- Đăng nhập: Google + Email/Mật khẩu; chế độ Khách chỉ xem, chỉ mở popup đăng nhập đúng lúc cần ghi
- Xóa tài khoản: Edge Function `delete-account` dùng service role key, xóa user trong Auth dẫn tới cascade profile & review, **và xóa file ảnh trong Storage**
- Chỉ đường: mở liên kết Google Maps/Apple Maps, không dẫn đường trong app
- Máy Windows 8GB: không Docker, không `supabase start`; RLS/pgTAP chạy trên GitHub Actions từ M1
- Next.js 16.3.8 + Tailwind 4.3.3 + next-intl 4.14.9 (vi mặc định, `/en` cho English)
- Tất cả hàm pgTAP trong test phải gọi kèm schema `extensions.*` và search_path phải phục hồi `public, extensions;` sau khi thử nghiệm ngữ cảnh cô lập `public`.
- Dev dùng Supabase cloud, không dùng Docker ở máy; test database chạy trên GitHub Actions (có bước mô phỏng cloud với search_path=public)
- Không nạp seed.sql lên cloud (nó chứa người dùng giả trong auth.users)
- `profiles` chỉ cho `authenticated` cập nhật `display_name` và `avatar_url`; các cột `role` và `is_banned` bị giới hạn bằng column privileges.
- Review insert phải kiểm tra trạng thái `profiles.is_banned`; photo path không được chứa UUID chủ review khi review ẩn danh.
- **M5 (mới):** từ M5 trở đi `authenticated` **không** ghi trực tiếp bảng `reviews`/`review_photos`/`review_helpful`; mọi thay đổi đi qua RPC có kiểm tra chủ sở hữu. T6/T11 dùng `lim=50` (đã có bằng chứng CI về top-N).
- **M5 (mới):** ảnh review là write-once — không cấp policy UPDATE trên Storage; xóa ảnh đi kèm xóa review hoặc xóa tài khoản.

## 8. Vấn đề / bug đã biết

- `jsdom@30.1.1` cảnh báo engine trên Node 24.11.1 (yêu cầu ≥ 24.15). `npm test` vẫn pass trên máy này.
- `next dev` tự thêm khối luật Next.js vào cuối `AGENTS.md`; nội dung luật repo gốc được giữ nguyên.
- Deno Edge Functions trong `supabase/functions` được exclude khỏi `tsconfig.json` của Next.js để tránh xung đột kiểu type giữa Node và Deno.
- **Sandbox Windows (quan trọng cho agent sau):** trong phiên này, tiến trình chạy trong sandbox có mức toàn vẹn **Low**, còn tệp do lần chạy **ngoài sandbox** tạo ra có mức **Medium**. Hệ quả: `npm test` / `npm run build` lỗi `spawn EPERM` (Vite/SWC cần spawn tiến trình con có ống dẫn) và `npx tsc --noEmit` lỗi `EPERM ... tsconfig.tsbuildinfo` nếu tệp cache đó do lần chạy ngoài sandbox để lại. Cách xử lý: chạy `npm test` và `npm run build` ngoài sandbox; nếu tsc báo EPERM với `tsconfig.tsbuildinfo` thì xóa tệp cache đó ngoài sandbox rồi chạy lại (lần chạy trong sandbox sẽ tạo lại tệp ở mức Low).
- **Đường dẫn workspace thiếu quyền Windows:** đầu phiên, mọi lệnh `pwsh` đều lỗi `SetNamedSecurityInfoW failed (Win32 5): grantWrite(D:\wamp\www\food-map)`. Đã sửa bằng script chẩn đoán ACL (bản backup/khôi phục nằm trong `.acl-recovery/`). Thư mục `.acl-recovery/` là rác công cụ, đã thêm vào `.gitignore`.
- **Rủi ro còn lại (Storage):** `allowed_mime_types` chỉ kiểm tra Content-Type do client khai báo, không kiểm tra magic byte. Bucket lại là công khai nên một tệp HTML khai báo `image/jpeg` có thể được phục vụ từ miền Storage dùng chung. Chưa xử lý trong M5; đề xuất cho M8/M9: kiểm tra magic byte phía server (Edge Function hoặc trigger trên `storage.objects`) hoặc chỉ phục vụ ảnh qua signed URL/`Content-Disposition: attachment`.
- **Rủi ro còn lại (đã chấp nhận):** `photo_paths` trong `public_reviews` chứa `review_id` làm thư mục đầu, nên người biết `review_id` có thể đoán được URL ảnh. Đây không phải `user_id` và ảnh vốn công khai theo thiết kế; không đổi trong M5.

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
| 2026-10-08 | Codex | CI follow-up: `01_rls_test.sql` T23 đổi sang `throws_ok` 42501 cho UPDATE các cột hệ thống của `restaurants`; `plan(38)` và 3 slot giữ nguyên. Chờ log CI. | 4739d74 (kèm sau) |
| 2026-10-08 | Codex | Mutation evidence: người dùng xác nhận main `4739d74` xanh. PR #4 database job cố ý FAIL (Files=6, Tests=77) khi khôi phục quyền ghi rộng; PR không merge. Xem `docs/SECURITY-TESTS.md`. | PR #4 |
| 2026-10-09 | Codex | M4 search/detail + migration `20261009100000`; sửa lỗi top-N bằng `diag()` (T6/T11 dùng `lim=50`). Người dùng xác nhận CI M4 xanh và đã `db push`. | `bb689e0` |
| 2026-10-09 | Codex | Sinh code M5 (RPC ghi review, Storage ảnh, composer/MyReviews, xử lý ảnh xóa EXIF, i18n) + `08_m5_review_write_test.sql`. Local lint/tsc/test/build pass; hết token trước khi commit hai file đang sửa. | `2d3f083` |
| 2026-10-09 | DeepSeek Harness | Tiếp quản M5: khôi phục `PROGRESS.md` bị ghi đè; hoàn nguyên 2 chỗ sai trong `01_rls_test.sql` (T6/T11 `lim=10`, mất `role postgres` + clear JWT trước fixture); cập nhật 01/05 cho mô hình RPC M5; thêm `09_m5_review_rules_test.sql`; nối trigger `trg_enforce_review_system_fields`, thêm ràng buộc độ dài path, bỏ policy UPDATE Storage; `delete-account` dọn ảnh Storage. Chạy 4 lệnh local; chờ CI và `db push`. | (commit của phiên này) |
