"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "@/features/auth/hooks/useAuth";
import type { RestaurantDish } from "@/features/restaurants/types";
import { getMyReview, removeReview, saveReview, uploadReviewPhotos } from "../repository";

type Props = { restaurantId: string; dishes: RestaurantDish[]; onChanged: () => void };

export function ReviewComposer(props: Props) {
  const { user } = useAuth();
  return <ReviewComposerForm key={user?.id ?? "guest"} {...props} />;
}

function ReviewComposerForm({ restaurantId, dishes, onChanged }: Props) {
  const t = useTranslations("restaurant.reviews.composer");
  const { user, isLoading: authLoading, setShowLoginModal } = useAuth();
  const [dishId, setDishId] = useState("");
  const [rating, setRating] = useState(5);
  const [content, setContent] = useState("");
  const [anonymous, setAnonymous] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const [reviewId, setReviewId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!user) {
      return;
    }
    let cancelled = false;
    void getMyReview(restaurantId, dishId || null).then((review) => {
      if (cancelled || !review) return;
      setReviewId(review?.id ?? null);
      setRating(review?.rating ?? 5);
      setContent(review?.content ?? "");
      setAnonymous(review?.is_anonymous ?? false);
    }).catch(() => {
      if (!cancelled) setMessage(t("loadError"));
    });
    return () => { cancelled = true; };
  }, [dishId, restaurantId, t, user]);

  const submit = async () => {
    setBusy(true);
    setMessage("");
    try {
      const id = await saveReview({ restaurantId, dishId: dishId || null, rating, content, isAnonymous: anonymous });
      setReviewId(id);
      if (files.length > 0) await uploadReviewPhotos(id, files);
      setFiles([]);
      onChanged();
      setMessage(t("saved"));
    } catch {
      setMessage(t("saveError"));
    } finally {
      setBusy(false);
    }
  };

  const onSave = () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    void submit();
  };

  const onDelete = async () => {
    if (!reviewId) return;
    setBusy(true);
    setMessage("");
    try {
      await removeReview(reviewId);
      onChanged();
      setReviewId(null);
      setRating(5);
      setContent("");
      setAnonymous(false);
      setMessage(t("deleted"));
    } catch {
      setMessage(t("deleteError"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <section aria-labelledby="write-review-title" className="mt-8 rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900 sm:p-5">
      <h2 id="write-review-title" className="text-xl font-bold">{reviewId ? t("editTitle") : t("title")}</h2>
      {!user && !authLoading && <p className="mt-2 text-sm text-zinc-600">{t("signInHint")}</p>}
      <div className="mt-4 grid gap-4">
        {dishes.length > 0 && (
          <label className="grid gap-1 text-sm font-medium">
            {t("dish")}
            <select value={dishId} onChange={(event) => {
              setDishId(event.target.value);
              setReviewId(null);
              setRating(5);
              setContent("");
              setAnonymous(false);
            }} className="min-h-11 rounded-lg border border-zinc-300 bg-white px-3 dark:border-zinc-700 dark:bg-zinc-950">
              <option value="">{t("restaurantOverall")}</option>
              {dishes.map((dish) => <option value={dish.id} key={dish.id}>{dish.name}</option>)}
            </select>
          </label>
        )}
        <label className="grid gap-1 text-sm font-medium">
          {t("rating")}
          <select value={rating} onChange={(event) => setRating(Number(event.target.value))} className="min-h-11 rounded-lg border border-zinc-300 bg-white px-3 dark:border-zinc-700 dark:bg-zinc-950">
            {[5, 4, 3, 2, 1].map((value) => <option value={value} key={value}>{value} {t("stars")}</option>)}
          </select>
        </label>
        <label className="grid gap-1 text-sm font-medium">
          {t("content")}
          <textarea value={content} onChange={(event) => setContent(event.target.value)} maxLength={2000} rows={4} className="rounded-lg border border-zinc-300 bg-white p-3 dark:border-zinc-700 dark:bg-zinc-950" />
          <span className="text-right text-xs font-normal text-zinc-500">{content.length}/2000</span>
        </label>
        <label className="grid gap-1 text-sm font-medium">
          {t("photos")}
          <input type="file" accept="image/*" multiple onChange={(event) => setFiles(Array.from(event.target.files ?? []).slice(0, 5))} className="min-h-11 text-sm file:mr-3 file:min-h-11 file:rounded-lg file:border-0 file:bg-zinc-100 file:px-3 dark:file:bg-zinc-800" />
          <span className="text-xs font-normal text-zinc-500">{t("photoHint", { count: files.length })}</span>
        </label>
        <label className="flex items-start gap-3 text-sm">
          <input type="checkbox" checked={anonymous} onChange={(event) => setAnonymous(event.target.checked)} className="mt-1 h-4 w-4" />
          <span><span className="font-semibold">{t("anonymous")}</span><span className="mt-1 block text-xs text-zinc-500">{t("anonymousHint")}</span></span>
        </label>
        <div className="flex flex-wrap gap-2">
          <button type="button" disabled={busy} onClick={onSave} className="min-h-11 rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white disabled:opacity-60">
            {busy ? t("saving") : reviewId ? t("saveEdit") : t("submit")}
          </button>
          {reviewId && <button type="button" disabled={busy} onClick={() => void onDelete()} className="min-h-11 rounded-xl border border-red-300 px-4 text-sm font-semibold text-red-700 disabled:opacity-60">{t("delete")}</button>}
        </div>
        {message && <p role="status" className="text-sm text-zinc-600">{message}</p>}
      </div>
    </section>
  );
}
