# PRIVACY-DESIGN

Ghi cách thiết kế ẩn danh và quyền riêng tư: dữ liệu nào được lưu, ai đọc được gì,
cách chặn lộ `user_id` của review ẩn danh, cách xóa EXIF, cách xóa tài khoản, nhật ký audit của quản trị.

## Cơ chế Ẩn danh tại Database (M1)

1. **RLS Mặc định**: Bảng `reviews` được khóa, người dùng chỉ đọc được bài của mình qua API bảng.
2. **View Công khai chạy bằng quyền Chủ sở hữu**: Tính năng ẩn danh không chỉ phụ thuộc vào UI hay API Server chặn. View `public_reviews` được tạo để đọc bảng `reviews` bằng quyền chủ sở hữu DB (Bypass RLS), nhưng nội bộ View đã sử dụng biểu thức `CASE WHEN r.is_anonymous THEN null ELSE r.user_id END` để đảm bảo `user_id` không bao giờ rời khỏi database đối với các review ẩn danh. Điều này nghĩa là dù client dùng bất kỳ công cụ nào để query GraphQL hay REST endpoint của view này, họ vẫn chỉ nhận được giá trị null thay vì id thật của người dùng.

## Ghi chú M5 — 2026-10-09

### Đường dẫn ảnh review không chứa danh tính

- Client tạo tên tệp: `${reviewId}/${crypto.randomUUID()}.jpg` (`src/features/reviews/repository.ts`). Không có nhánh nào ghép `user_id` vào đường dẫn, kể cả review ẩn danh.
- Database chỉ chấp nhận đường dẫn có thư mục đầu bằng `review_id` (`add_review_photo`).
- Storage policy chỉ cho chủ của `review_id` đó ghi/xóa, nên "thư mục đầu = `auth.uid()`" không được dùng và không cần dùng.

### Rủi ro còn lại: `storage.objects.owner_id` gắn danh tính người tải lên

**Cơ chế (có bằng chứng tài liệu):** tài liệu Supabase Storage nói rõ: "When creating new buckets or objects in Supabase Storage, an owner is automatically assigned to the bucket or object. The owner is the user who created the resource and the value is derived from the `sub` claim in the JWT. We store the `owner` in the `owner_id` column." và "When using the `service_key` to create a resource, the owner will not be set". Xem [Ownership | Supabase Docs](https://supabase.com/docs/guides/storage/security/ownership) và bản nguồn [ownership.mdx](https://raw.githubusercontent.com/supabase/supabase/refs/heads/master/apps/docs/content/guides/storage/security/ownership.mdx). Tài liệu Access Control cũng dùng chính trường này để phân quyền: `using ((select auth.jwt()->>'sub') = owner_id)` — [Storage Access Control](https://supabase.com/docs/guides/storage/security/access-control).

**Hệ quả:** mọi ảnh review do người dùng tải lên đều có `owner_id` = `auth.uid()` của người đó, **kể cả khi review là ẩn danh**. Đây là một trường danh tính song song với `reviews.user_id`, nằm ngoài tầm kiểm soát của view `public_reviews`.

**Ai đọc được `owner_id`:**

- Đường dẫn công khai (`/storage/v1/object/public/review-photos/<path>`) phục vụ nội dung tệp và **không** đọc bảng `storage.objects`, nên không lộ `owner_id`.
- Các thao tác có đọc metadata (list/info qua Storage API, ví dụ `storage.from(bucket).list()` hoặc `.info()`) đi qua `storage.objects` và **chịu RLS**. Vì migration M5 tạo policy `"Review photos are publicly readable" ... for select using (bucket_id = 'review-photos')`, policy này **không giới hạn theo `auth.uid()`**, nên hàng tương ứng là đọc được với vai `anon`/`authenticated`. Do đó client có thể nhận metadata của ảnh thuộc review ẩn danh, và trong đó có `owner_id`.
- **Trạng thái xác minh:** kết luận trên dựa trên tài liệu và trên policy trong repo; chưa chạy thử end-to-end vì migration M5 chưa được `db push` và máy dev không có Docker. Đây là **rủi ro được đánh dấu, chưa đóng**.

**Cách tự kiểm chứng sau `db push`** (chạy khi đã đăng nhập một tài khoản bất kỳ không phải chủ review ẩn danh):

```js
// Trong DevTools console của app đã đăng nhập (dùng anon key + session hiện tại)
const { data, error } = await supabase.storage.from("review-photos").list("<reviewId của review ẩn danh>");
console.log(error ?? data); // nếu thấy owner_id/owner trùng UUID người viết → đã lộ danh tính
```

**Hướng xử lý đề xuất (chọn một, làm ở milestone sau — không nằm trong M5):**

1. **Tải ảnh qua Edge Function dùng service role**: object được tạo bằng service role nên `owner_id` không được gán; Edge Function tự kiểm tra chủ review và thay `auth.uid()` làm hàng rào. Đổi lại phải bỏ policy INSERT trực tiếp cho `authenticated`.
2. **Thu hẹp policy SELECT của `storage.objects`**: chỉ cho `owner_id = auth.uid()` hoặc `bucket_id <> 'review-photos'` đọc metadata. Giữ được đường dẫn công khai cho việc hiển thị ảnh vì tệp vẫn phục vụ qua endpoint public không qua RLS. Cách này nhẹ nhất và đóng đúng chỗ rò metadata.
3. **Chuyển bucket sang private + signed URL** (có thời hạn), phát URL qua RPC/Edge Function; ảnh ẩn danh không còn truy cập được bằng suy đoán đường dẫn.

Khuyến nghị: làm (2) ngay khi có dịp sửa Storage policy, và cân nhắc (3) ở M9 khi chốt PWA/triển khai. Cho tới lúc đó, tài liệu này ghi nhận rằng **ẩn danh hiện chỉ được bảo đảm ở lớp dữ liệu review, chưa được bảo đảm ở lớp metadata của tệp ảnh**.

### Xóa EXIF (M5)

- Ảnh được vẽ lại qua canvas và xuất JPEG (`prepareReviewPhoto`), nên không còn EXIF/GPS.
- `hasExifMetadata()` trong `src/features/reviews/image-processing.ts` dò marker APP1 (0xE1) và có test cho cả ảnh có EXIF đầu vào lẫn ảnh không có (`src/features/reviews/image-processing.test.ts`).

### Xóa tài khoản và xóa review (M5)

- Cascade `auth.users → profiles → reviews → review_photos` **không** xóa tệp trong Storage.
- `delete_review` (RPC) chỉ xóa hàng dữ liệu và **trả về danh sách `storage_paths`**; client gọi Storage API để xóa tệp. Không dùng `delete from storage.objects` bằng SQL vì Supabase Storage chặn và việc đó để lại tệp mồ côi.
- Edge Function `delete-account` thu thập `storage_path` của người dùng rồi gọi `storage.remove()` theo lô trước khi xóa user.

### Nhật ký audit của quản trị

- Chưa triển khai (thuộc M8). Khi làm, mọi truy cập danh tính thật của review ẩn danh phải ghi vào `admin_audit_log`.
