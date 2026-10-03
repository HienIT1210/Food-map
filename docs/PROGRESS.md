# PROGRESS — Trạng thái dự án (bộ nhớ chung giữa các agent)

> Mọi agent phải đọc file này đầu phiên và cập nhật cuối mỗi bước nhỏ. Nếu file này mâu thuẫn với code/git thì tin code/git và sửa file này.

**Cập nhật lần cuối:** (ngày giờ) bởi (tên agent/tool)

---

## 1. Trạng thái hiện tại

- **Milestone đang làm:** M0
- **Tình trạng:** chưa bắt đầu
- **Nhánh git đang dùng:** main

## 2. Tiến độ milestone

- [ ] M0 — Khởi tạo repo, CI, cấu trúc
- [ ] M1 — Schema, RLS, view công khai, RPC, seed, test RLS
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

- **Việc:** (mô tả)
- **File liên quan:** (đường dẫn)
- **Dở ở chỗ nào / vì sao dừng:** (ví dụ: hết hạn mức, đang chờ quyết định, lỗi chưa sửa)
- **Có commit `wip:` chưa:** (có/không, hash)

## 4. Bước tiếp theo (3 việc cụ thể, theo thứ tự)

1. (việc cụ thể, kèm file/hàm nếu có)
2. (việc cụ thể)
3. (việc cụ thể)

## 5. Lệnh chạy / kiểm tra

> Cập nhật cho đúng thực tế sau M0.

```
Chạy dev:        (điền)
Lint:            (điền)
Type-check:      (điền)
Test:            (điền)
Reset database:  (điền)
```

## 6. Quyết định đã chốt (không đổi khi chưa hỏi người dùng)

- Nền tảng: web PWA, mobile-first (không làm app native ở giai đoạn này)
- Stack: Next.js (App Router) + TypeScript strict + Tailwind + Supabase + MapLibre GL JS
- Review = bình luận (không có hệ thống bình luận riêng)
- Ẩn danh = ẩn với người dùng khác, không phải ẩn với quản trị; ẩn danh làm bằng view công khai không chứa `user_id`
- Đăng nhập: Google + Email; chế độ Khách chỉ xem
- Chỉ đường: mở liên kết Google Maps/Apple Maps, không dẫn đường trong app
- (agent thêm các quyết định mới ở đây, kèm lý do ngắn)

## 7. Giả định (chi tiết hơn ở `docs/ASSUMPTIONS.md`)

- (liệt kê)

## 8. Vấn đề / bug đã biết

- (mô tả, mức độ, file liên quan)

## 9. Nhật ký bàn giao

| Thời gian | Agent/Tool | Đã làm gì | Commit |
|---|---|---|---|
| | | | |
