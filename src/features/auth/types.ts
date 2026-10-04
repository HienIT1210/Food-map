import { z } from "zod";

export const ProfileSchema = z.object({
  id: z.string().uuid(),
  display_name: z.string().min(1, "Tên hiển thị không được để trống").max(50, "Tên quá dài"),
  avatar_url: z.string().nullable().optional(),
  role: z.enum(["user", "admin"]).default("user"),
  is_banned: z.boolean().default(false),
  created_at: z.string(),
});

export type Profile = z.infer<typeof ProfileSchema>;

export const UpdateProfileInputSchema = z.object({
  display_name: z.string().min(1, "Tên hiển thị không được để trống").max(50, "Tên quá dài"),
  avatar_url: z.string().url("URL ảnh không hợp lệ").nullable().optional().or(z.literal("")),
});

export type UpdateProfileInput = z.infer<typeof UpdateProfileInputSchema>;

export const EmailAuthInputSchema = z.object({
  email: z.string().email("Email không hợp lệ"),
  password: z.string().min(6, "Mật khẩu tối thiểu 6 ký tự"),
});

export type EmailAuthInput = z.infer<typeof EmailAuthInputSchema>;
