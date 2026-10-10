// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, linting, and formatting for Deno.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Xử lý preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Thiếu authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return new Response(JSON.stringify({ error: "Thiếu cấu hình biến môi trường server" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Client dùng service role để thực hiện quyền admin (xóa user khỏi auth.users)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Xác thực người dùng gửi request từ token JWT
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Người dùng không hợp lệ hoặc phiên đã hết hạn" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = user.id;

    // SPEC AUTH-04: deleting the user cascades auth.users -> profiles -> reviews -> review_photos,
    // but a table cascade never removes Supabase Storage objects. Collect the paths first, then
    // delete the files before the metadata rows disappear.
    const { data: photoRows, error: photoError } = await supabaseAdmin
      .from("review_photos")
      .select("storage_path, reviews!inner(user_id)")
      .eq("reviews.user_id", userId);

    if (photoError) {
      console.error("delete-account: could not list review photos", photoError.message);
    }

    const photoPaths = (photoRows ?? [])
      .map((row) => (row as { storage_path: string | null }).storage_path)
      .filter((path): path is string => typeof path === "string" && path.length > 0);

    for (let start = 0; start < photoPaths.length; start += 100) {
      const batch = photoPaths.slice(start, start + 100);
      const { error: removeError } = await supabaseAdmin.storage.from("review-photos").remove(batch);
      if (removeError) {
        // Keep going: an orphaned file is preferable to keeping the account alive, but it must be visible.
        console.error("delete-account: could not remove review photos", removeError.message);
      }
    }

    // Thực hiện xóa user qua Admin Auth API:
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, message: "Tài khoản và dữ liệu liên quan đã được xóa thành công" }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
