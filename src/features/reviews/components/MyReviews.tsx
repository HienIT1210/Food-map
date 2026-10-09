"use client";

import { useCallback, useEffect, useState } from "react";
import { Link } from "@/i18n/navigation";
import { useTranslations } from "next-intl";
import { listMyReviews, removeReview } from "../repository";
import type { OwnReview } from "../types";

export function MyReviews() {
  const t = useTranslations("profile.myReviews");
  const [reviews, setReviews] = useState<OwnReview[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(false);
    try {
      setReviews(await listMyReviews());
    } catch {
      setError(true);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let active = true;
    queueMicrotask(() => { if (active) void load(); });
    return () => { active = false; };
  }, [load]);

  const deleteReview = async (id: string) => {
    setDeletingId(id);
    try {
      await removeReview(id);
      setReviews((current) => current.filter((review) => review.id !== id));
    } catch {
      setError(true);
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <section aria-labelledby="my-reviews-title" className="rounded-2xl border border-zinc-200 bg-white p-5 shadow-xs dark:border-zinc-800 dark:bg-zinc-900">
      <h2 id="my-reviews-title" className="text-xl font-bold">{t("title")}</h2>
      {loading && <p role="status" className="py-5 text-sm text-zinc-500">{t("loading")}</p>}
      {error && <div role="alert" className="mt-3 text-sm text-red-700"><p>{t("error")}</p><button type="button" onClick={() => void load()} className="mt-1 underline">{t("retry")}</button></div>}
      {!loading && !error && reviews.length === 0 && <p className="py-5 text-sm text-zinc-500">{t("empty")}</p>}
      <ul className="mt-3 space-y-3">
        {reviews.map((review) => (
          <li key={review.id} className="rounded-xl border border-zinc-200 p-4 dark:border-zinc-700">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="truncate font-semibold">{review.restaurant_name}</p>
                <p className="mt-1 text-sm text-zinc-600">{"★".repeat(review.rating)} · {review.is_anonymous ? t("anonymous") : t("public")}</p>
              </div>
              <button type="button" disabled={deletingId === review.id} onClick={() => void deleteReview(review.id)} className="min-h-10 shrink-0 rounded-lg border border-red-300 px-3 text-xs font-semibold text-red-700 disabled:opacity-60">{deletingId === review.id ? t("deleting") : t("delete")}</button>
            </div>
            {review.content && <p className="mt-2 whitespace-pre-wrap text-sm">{review.content}</p>}
            <Link href={`/restaurants/${review.restaurant_id}`} className="mt-3 inline-flex min-h-10 items-center text-sm font-semibold text-blue-700 underline dark:text-blue-300">{t("edit")}</Link>
          </li>
        ))}
      </ul>
    </section>
  );
}
