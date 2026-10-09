"use client";

import { useFormatter, useTranslations } from "next-intl";
import type { PublicReview } from "../types";

export function ReviewCard({ review }: { review: PublicReview }) {
  const t = useTranslations("restaurant.reviews");
  const format = useFormatter();
  const author = review.is_anonymous ? t("anonymous") : review.author_name ?? t("unknownAuthor");

  return (
    <article className="rounded-xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          {review.is_anonymous ? (
            <span aria-hidden="true" className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-zinc-100 text-lg dark:bg-zinc-800">👤</span>
          ) : (
            <span aria-hidden="true" className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-zinc-100 text-lg dark:bg-zinc-800">👤</span>
          )}
          <p className="truncate text-sm font-semibold">{author}</p>
        </div>
        <time className="shrink-0 text-xs text-zinc-500" dateTime={review.created_at}>
          {format.dateTime(new Date(review.created_at), { dateStyle: "medium" })}
        </time>
      </div>
      <p className="mt-3 text-sm font-medium" aria-label={t("rating", { rating: review.rating })}>{"★".repeat(review.rating)}{"☆".repeat(5 - review.rating)}</p>
      {review.content && <p className="mt-2 whitespace-pre-wrap text-sm leading-6 text-zinc-700 dark:text-zinc-200">{review.content}</p>}
      <p className="mt-3 text-xs text-zinc-500">{t("helpfulCount", { count: review.helpful_count })}</p>
    </article>
  );
}
