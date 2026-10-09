"use client";

import { useFormatter, useTranslations } from "next-intl";
import { useState } from "react";
import Image from "next/image";
import { getReviewPhotoUrl, toggleHelpful } from "../repository";
import type { PublicReview } from "../types";

export function ReviewCard({ review }: { review: PublicReview }) {
  const t = useTranslations("restaurant.reviews");
  const format = useFormatter();
  const author = review.is_anonymous ? t("anonymous") : review.author_name ?? t("unknownAuthor");
  const [helpfulCount, setHelpfulCount] = useState(review.helpful_count);
  const [voted, setVoted] = useState(false);
  const [voteError, setVoteError] = useState(false);

  const onHelpful = async () => {
    setVoteError(false);
    try {
      const added = await toggleHelpful(review.id);
      setVoted(added);
      setHelpfulCount((count) => Math.max(0, count + (added ? 1 : -1)));
    } catch {
      setVoteError(true);
    }
  };

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
      {review.photo_paths.length > 0 && (
        <div className="mt-3 flex gap-2 overflow-x-auto" aria-label={t("photosLabel")}>
          {review.photo_paths.map((path) => <Image key={path} src={getReviewPhotoUrl(path)} alt={t("photoAlt")} width={96} height={96} unoptimized className="h-24 w-24 shrink-0 rounded-lg object-cover" />)}
        </div>
      )}
      <div className="mt-3 flex items-center justify-between gap-3">
        <p className="text-xs text-zinc-500">{t("helpfulCount", { count: helpfulCount })}</p>
        <button type="button" aria-pressed={voted} onClick={() => void onHelpful()} className="min-h-10 rounded-lg border border-zinc-300 px-3 text-xs font-semibold dark:border-zinc-700">
          {voted ? t("removeHelpful") : t("markHelpful")}
        </button>
      </div>
      {voteError && <p role="alert" className="mt-2 text-xs text-red-700">{t("helpfulError")}</p>}
    </article>
  );
}
