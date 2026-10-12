import { describe, it, expect } from "vitest";
import { ProfileSchema, UpdateProfileInputSchema, EmailAuthInputSchema } from "./types";

describe("Auth & Profile Schemas (M2)", () => {
  it("ProfileSchema validate đúng profile hợp lệ", () => {
    const validProfile = {
      id: "dddd4444-4444-4444-4444-444444444444",
      display_name: "Nguyen Van A",
      avatar_url: "https://example.com/avatar.jpg",
      role: "user",
      is_banned: false,
      created_at: new Date().toISOString(),
    };

    const parsed = ProfileSchema.safeParse(validProfile);
    if (!parsed.success) {
      console.error(parsed.error);
    }
    expect(parsed.success).toBe(true);
  });

  it("ProfileSchema từ chối display_name rỗng", () => {
    const invalidProfile = {
      id: "11111111-1111-1111-1111-111111111111",
      display_name: "",
      avatar_url: null,
      role: "user",
      is_banned: false,
      created_at: new Date().toISOString(),
    };

    const parsed = ProfileSchema.safeParse(invalidProfile);
    expect(parsed.success).toBe(false);
  });

  it("UpdateProfileInputSchema cho phép avatar_url null hoặc rỗng", () => {
    const inputWithEmptyAvatar = {
      display_name: "Tên mới",
      avatar_url: "",
    };

    const parsed = UpdateProfileInputSchema.safeParse(inputWithEmptyAvatar);
    expect(parsed.success).toBe(true);
  });

  it("EmailAuthInputSchema kiểm tra mật khẩu tối thiểu 6 ký tự", () => {
    const shortPassword = {
      email: "test@example.com",
      password: "123",
    };

    const parsed = EmailAuthInputSchema.safeParse(shortPassword);
    expect(parsed.success).toBe(false);

    const validAuth = {
      email: "test@example.com",
      password: "strongpassword123",
    };
    expect(EmailAuthInputSchema.safeParse(validAuth).success).toBe(true);
  });
});
