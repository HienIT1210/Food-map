"use client";

import React, { useState } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "@/features/auth/hooks/useAuth";
import { authRepository } from "@/features/auth/repository";
import { MyReviews } from "@/features/reviews/components/MyReviews";

export function ProfileView() {
  const t = useTranslations("profile");
  const tAuth = useTranslations("auth");
  const { user, profile, refreshProfile, setShowLoginModal } = useAuth();

  if (!user) {
    return (
      <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
        <h2 className="text-xl font-bold text-zinc-900 dark:text-zinc-100">{t("guestTitle")}</h2>
        <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
          {t("guestDescription")}
        </p>
        <button
          onClick={() => setShowLoginModal(true)}
          className="mt-4 rounded-xl bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-800 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200"
        >
          {tAuth("signInBtn")}
        </button>
      </div>
    );
  }

  // Khi có user, render form chỉnh sửa hồ sơ
  return (
    <>
      <ProfileForm
        user={user}
        initialDisplayName={profile?.display_name || ""}
        initialAvatarUrl={profile?.avatar_url || ""}
        onUpdated={refreshProfile}
      />
      <MyReviews />
    </>
  );
}

function ProfileForm({
  user,
  initialDisplayName,
  initialAvatarUrl,
  onUpdated,
}: {
  user: { id: string; email?: string };
  initialDisplayName: string;
  initialAvatarUrl: string;
  onUpdated: () => Promise<void>;
}) {
  const t = useTranslations("profile");
  const tAuth = useTranslations("auth");

  const [displayName, setDisplayName] = useState(initialDisplayName);
  const [avatarUrl, setAvatarUrl] = useState(initialAvatarUrl);
  const [isUpdating, setIsUpdating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [showConfirmDelete, setShowConfirmDelete] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsUpdating(true);
    setMessage(null);

    try {
      await authRepository.updateProfile(user.id, {
        display_name: displayName,
        avatar_url: avatarUrl || undefined,
      });
      await onUpdated();
      setMessage({ type: "success", text: t("updateSuccess") });
    } catch (err) {
      setMessage({ type: "error", text: (err as Error).message || t("updateFailed") });
    } finally {
      setIsUpdating(false);
    }
  };

  const handleSignOut = async () => {
    try {
      await authRepository.signOut();
    } catch (err) {
      console.error(err);
    }
  };

  const handleDeleteAccount = async () => {
    setIsDeleting(true);
    setMessage(null);
    try {
      await authRepository.deleteAccount();
    } catch (err) {
      setMessage({ type: "error", text: (err as Error).message || t("deleteFailed") });
      setIsDeleting(false);
      setShowConfirmDelete(false);
    }
  };

  return (
    <div className="rounded-2xl border border-zinc-200 bg-white p-6 shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
      <div className="flex items-center justify-between border-b border-zinc-200 pb-4 dark:border-zinc-800">
        <div>
          <h2 className="text-xl font-bold text-zinc-900 dark:text-zinc-100">{t("title")}</h2>
          <p className="text-xs text-zinc-500">{user.email}</p>
        </div>
        <button
          onClick={handleSignOut}
          className="rounded-lg border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 dark:border-zinc-700 dark:text-zinc-300 dark:hover:bg-zinc-800"
        >
          {tAuth("signOut")}
        </button>
      </div>

      {message && (
        <div
          className={`mt-4 rounded-xl p-3 text-sm ${
            message.type === "success"
              ? "bg-green-50 text-green-700 dark:bg-green-950/50 dark:text-green-400"
              : "bg-red-50 text-red-700 dark:bg-red-950/50 dark:text-red-400"
          }`}
        >
          {message.text}
        </div>
      )}

      {/* Form sửa hồ sơ (AUTH-03) */}
      <form onSubmit={handleUpdate} className="mt-6 space-y-4">
        <div>
          <label className="block text-xs font-medium text-zinc-700 dark:text-zinc-300 mb-1">
            {t("displayName")}
          </label>
          <input
            type="text"
            required
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className="w-full rounded-xl border border-zinc-300 bg-transparent px-3 py-2 text-sm text-zinc-900 outline-none focus:border-zinc-900 dark:border-zinc-700 dark:text-zinc-100 dark:focus:border-zinc-400"
          />
        </div>

        <div>
          <label className="block text-xs font-medium text-zinc-700 dark:text-zinc-300 mb-1">
            {t("avatarUrl")}
          </label>
          <input
            type="url"
            value={avatarUrl}
            onChange={(e) => setAvatarUrl(e.target.value)}
            placeholder="https://..."
            className="w-full rounded-xl border border-zinc-300 bg-transparent px-3 py-2 text-sm text-zinc-900 outline-none focus:border-zinc-900 dark:border-zinc-700 dark:text-zinc-100 dark:focus:border-zinc-400"
          />
        </div>

        <button
          type="submit"
          disabled={isUpdating}
          className="rounded-xl bg-zinc-900 px-5 py-2 text-sm font-semibold text-white shadow-xs hover:bg-zinc-800 dark:bg-zinc-100 dark:text-zinc-900 dark:hover:bg-zinc-200 disabled:opacity-50"
        >
          {isUpdating ? t("saving") : t("save")}
        </button>
      </form>

      {/* Khu vực xoá tài khoản (AUTH-04) */}
      <div className="mt-10 border-t border-red-100 pt-6 dark:border-red-950">
        <h3 className="text-sm font-semibold text-red-600 dark:text-red-400">{t("dangerZone")}</h3>
        <p className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
          {t("deleteWarning")}
        </p>

        {!showConfirmDelete ? (
          <button
            type="button"
            onClick={() => setShowConfirmDelete(true)}
            className="mt-3 rounded-lg border border-red-300 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-50 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950/50"
          >
            {t("deleteAccountBtn")}
          </button>
        ) : (
          <div className="mt-3 rounded-xl border border-red-200 bg-red-50 p-4 dark:border-red-900 dark:bg-red-950/30">
            <p className="text-xs font-medium text-red-800 dark:text-red-300">
              {t("confirmDeleteMsg")}
            </p>
            <div className="mt-3 flex gap-2">
              <button
                type="button"
                disabled={isDeleting}
                onClick={handleDeleteAccount}
                className="rounded-lg bg-red-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-red-700 disabled:opacity-50"
              >
                {isDeleting ? "..." : t("confirmDeleteBtn")}
              </button>
              <button
                type="button"
                onClick={() => setShowConfirmDelete(false)}
                className="rounded-lg border border-zinc-300 px-3 py-1.5 text-xs font-medium text-zinc-700 dark:border-zinc-700 dark:text-zinc-300"
              >
                {t("cancel")}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
