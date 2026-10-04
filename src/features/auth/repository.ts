import { createClient } from "@/lib/supabase/client";
import { Profile, ProfileSchema, UpdateProfileInput, UpdateProfileInputSchema } from "./types";

export class AuthRepository {
  private supabase = createClient();

  async getSession() {
    const { data, error } = await this.supabase.auth.getSession();
    if (error) throw error;
    return data.session;
  }

  async getUser() {
    const { data, error } = await this.supabase.auth.getUser();
    if (error) return null;
    return data.user;
  }

  async getProfile(userId: string): Promise<Profile | null> {
    const { data, error } = await this.supabase
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .single();

    if (error) {
      if (error.code === "PGRST116") return null;
      throw error;
    }

    return ProfileSchema.parse(data);
  }

  async updateProfile(userId: string, input: UpdateProfileInput): Promise<Profile> {
    const validated = UpdateProfileInputSchema.parse(input);
    const { data, error } = await this.supabase
      .from("profiles")
      .update({
        display_name: validated.display_name,
        avatar_url: validated.avatar_url || null,
      })
      .eq("id", userId)
      .select()
      .single();

    if (error) throw error;
    return ProfileSchema.parse(data);
  }

  async signInWithGoogle(redirectTo?: string) {
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || window.location.origin;
    const { data, error } = await this.supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: redirectTo || `${siteUrl}/auth/callback`,
      },
    });
    if (error) throw error;
    return data;
  }

  async signInWithPassword(email: string, password: string) {
    const { data, error } = await this.supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
    return data;
  }

  async signUpWithPassword(email: string, password: string, displayName?: string) {
    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || window.location.origin;
    const { data, error } = await this.supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: displayName || email.split("@")[0],
        },
        emailRedirectTo: `${siteUrl}/auth/callback`,
      },
    });
    if (error) throw error;
    return data;
  }

  async signOut() {
    const { error } = await this.supabase.auth.signOut();
    if (error) throw error;
  }

  async deleteAccount(): Promise<void> {
    const {
      data: { session },
    } = await this.supabase.auth.getSession();
    if (!session) {
      throw new Error("Người dùng chưa đăng nhập");
    }

    const { data, error } = await this.supabase.functions.invoke("delete-account", {
      headers: {
        Authorization: `Bearer ${session.access_token}`,
      },
    });

    if (error) {
      throw new Error(error.message || "Xóa tài khoản thất bại");
    }

    if (data && !data.success) {
      throw new Error(data.error || "Xóa tài khoản thất bại");
    }

    // Đăng xuất khỏi client sau khi xoá thành công
    await this.supabase.auth.signOut();
  }
}

export const authRepository = new AuthRepository();
