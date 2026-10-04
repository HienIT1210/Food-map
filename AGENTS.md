# AGENTS.md — Luật chung cho mọi AI agent làm việc trong repo này

> Repo này có thể được nhiều agent (Antigravity, Cursor, Copilot...) làm việc **lần lượt**. Bạn có thể là agent tiếp quản giữa chừng. Bộ nhớ chung duy nhất là **repo này** (code, git, và `docs/PROGRESS.md`), không phải cuộc trò chuyện trước đó.

## 1. Việc BẮT BUỘC làm đầu mỗi phiên

1. Đọc `docs/SPEC.md` (đặc tả sản phẩm và milestone).
2. Đọc `docs/PROGRESS.md` (trạng thái hiện tại, việc dở dang, bước tiếp theo).
3. Chạy `git status` và `git log -n 15 --oneline`. Nếu có thay đổi chưa commit, xem `git diff` để hiểu agent trước đang dở việc gì.
4. Tóm tắt cho người dùng trong **tối đa 5 dòng**: đang ở milestone nào, đã xong gì, đang dở gì, bạn định làm gì tiếp. Sau đó mới bắt đầu.

Nếu `docs/PROGRESS.md` mâu thuẫn với trạng thái thật của code, **tin code và git**, rồi sửa PROGRESS.md cho đúng.

## 2. Cách làm việc

- Làm **một milestone một lần**, theo đúng thứ tự trong `docs/SPEC.md`. Không sang milestone mới khi chưa chạy kiểm chứng Definition of Done của milestone hiện tại.
- Chỉ **một agent làm việc tại một thời điểm** trên cùng thư mục làm việc. Nếu thấy thay đổi chưa commit mà bạn không tạo ra, hãy hỏi người dùng trước khi ghi đè hoặc xóa.
- Không đổi các **quyết định đã chốt** (mục "Quyết định" trong PROGRESS.md) khi chưa hỏi người dùng.
- Không tự thêm dịch vụ có phí hoặc thư viện nặng. Không thêm tính năng ngoài phạm vi trong SPEC.
- Không đưa bí mật (khóa API, service role key) vào repo. Dùng biến môi trường.
- Không dựa vào trí nhớ về API thư viện phiên bản mới: đọc tài liệu chính thức và chạy thử.

## 3. Cuối mỗi bước nhỏ (và TRƯỚC khi hết token / bị ngắt)

1. Chạy kiểm tra: lint, type-check, test (lệnh ở mục 4).
2. **Cập nhật `docs/PROGRESS.md`**: việc đã xong, việc đang dở (file nào, dở chỗ nào, vì sao), 3 bước tiếp theo cụ thể, quyết định/giả định mới, thêm một dòng vào "Nhật ký bàn giao".
3. **Commit**. Nếu công việc chưa xong nhưng bạn sắp hết hạn mức hoặc phải dừng, vẫn commit với tiền tố `wip:` và ghi rõ chỗ dở trong PROGRESS.md. Tuyệt đối không để công việc dở mà không ghi lại.

Commit nhỏ, mỗi commit một việc, theo Conventional Commits (`feat:`, `fix:`, `chore:`, `test:`, `docs:`, `wip:`).

## 4. Lệnh chuẩn

> Agent đầu tiên điền chính xác các lệnh này sau khi hoàn thành M0, và giữ cho đúng.

```
Chạy dev:        npm run dev
Lint:            npm run lint
Type-check:      npx tsc --noEmit
Test:            npm test
Reset database:  supabase db reset
Test RLS:        supabase test db
E2E:             npx playwright test
```

## 5. Quy tắc code (tóm tắt; chi tiết ở `docs/SPEC.md`)

- TypeScript `strict`, cấm `any` trừ khi có chú thích lý do.
- Cấu trúc theo tính năng; component → hook → repository. Component không gọi Supabase trực tiếp.
- Mọi input và dữ liệu từ server kiểm tra bằng Zod.
- Mọi thay đổi database đi qua migration trong `supabase/migrations/`.
- **Tuyệt đối không** trả `user_id` thật của review ẩn danh ra client.
- Mỗi màn hình xử lý đủ trạng thái: đang tải, rỗng, lỗi, thành công.
- Chuỗi giao diện đặt trong tệp i18n, không viết cứng.

## 6. Khi nhận bàn giao từ agent khác

Làm đúng mục 1. Không bắt đầu lại từ đầu, không viết lại phần đã chạy được trừ khi có lỗi rõ ràng. Nếu thấy việc dở dang không rõ ý đồ, hỏi người dùng thay vì đoán.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
