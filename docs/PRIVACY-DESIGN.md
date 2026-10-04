# PRIVACY-DESIGN

Agent ghi cách thiết kế ẩn danh và quyền riêng tư: dữ liệu nào được lưu, ai đọc được gì,
cách chặn lộ `user_id` của review ẩn danh, cách xóa EXIF, cách xóa tài khoản, nhật ký audit của quản trị.

## Cơ chế Ẩn danh tại Database (M1)
1. **RLS Mặc định**: Bảng `reviews` được khóa, người dùng chỉ đọc được bài của mình qua API bảng.
2. **View Công khai chạy bằng quyền Chủ sở hữu**: Tính năng ẩn danh không chỉ phụ thuộc vào UI hay API Server chặn. View `public_reviews` được tạo để đọc bảng `reviews` bằng quyền chủ sở hữu DB (Bypass RLS), nhưng nội bộ View đã sử dụng biểu thức `CASE WHEN r.is_anonymous THEN null ELSE r.user_id END` để đảm bảo `user_id` không bao giờ rời khỏi database đối với các review ẩn danh. Điều này nghĩa là dù client dùng bất kỳ công cụ nào để query GraphQL hay REST endpoint của view này, họ vẫn chỉ nhận được giá trị null thay vì id thật của người dùng.