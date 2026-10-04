"use client";

import React, { useState } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "@/features/auth/hooks/useAuth";

export function GuestActionDemo() {
  const tAuth = useTranslations("auth");
  const tDemo = useTranslations("demo");
  const { user, isGuest, requireAuth, setShowLoginModal } = useAuth();
  const [successActionMsg, setSuccessActionMsg] = useState("");

  const handleWriteAction = () => {
    // Yêu cầu xác thực trước khi thực hiện hành động ghi:
    // Nếu là Khách -> bật Login Modal và lưu action chờ đăng nhập xong sẽ tự gọi.
    // Nếu đã đăng nhập -> chạy ngay lập tức.
    requireAuth(() => {
      setSuccessActionMsg(
        `Thực hiện hành động ghi thành công với tư cách: ${user?.email || "Người dùng"}!`
      );
    });
  };

  return (
    <div className="rounded-2xl border border-dashed border-zinc-300 p-6 dark:border-zinc-700 bg-zinc-50/50 dark:bg-zinc-900/50">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
          Chế độ hiện tại:{" "}
          <span
            className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
              isGuest
                ? "bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-300"
                : "bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300"
            }`}
          >
            {isGuest ? tAuth("guestMode") : `Đã đăng nhập (${user?.email})`}
          </span>
        </h3>

        {isGuest && (
          <button
            onClick={() => setShowLoginModal(true)}
            className="text-xs font-semibold text-zinc-700 underline dark:text-zinc-300"
          >
            {tAuth("signInBtn")}
          </button>
        )}
      </div>

      <p className="text-xs text-zinc-500 dark:text-zinc-400 mb-4">
        {tDemo("guestActionNotice")}
      </p>

      <button
        onClick={handleWriteAction}
        className="rounded-xl bg-zinc-900 px-4 py-2 text-xs font-semibold text-white shadow-xs hover:bg-zinc-800 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
      >
        ✏️ {tDemo("writeReviewBtn")}
      </button>

      {successActionMsg && (
        <div className="mt-3 rounded-lg bg-emerald-50 p-3 text-xs text-emerald-700 dark:bg-emerald-950/50 dark:text-emerald-400">
          {successActionMsg}
        </div>
      )}
    </div>
  );
}
