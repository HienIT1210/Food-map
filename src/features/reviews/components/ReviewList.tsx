"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRestaurantReviews } from "../hooks/useRestaurantReviews";
import { reviewSortSchema, type ReviewSort } from "../types";
import { ReviewCard } from "./ReviewCard";
import { ReviewComposer } from "./ReviewComposer";
import type { RestaurantDish } from "@/features/restaurants/types";

const sortOptions: ReviewSort[] = ["newest", "helpful", "rating_high", "rating_low"];

export function ReviewList({ restaurantId, dishes }: { restaurantId: string; dishes: RestaurantDish[] }) {
  const t = useTranslations("restaurant.reviews");
  const [sort, setSort] = useState<ReviewSort>("newest");
  const { reviews, loading, loadingMore, error, hasMore, loadMore, retry } = useRestaurantReviews(restaurantId, sort);

  return (
    <>
    <ReviewComposer restaurantId={restaurantId} dishes={dishes} onChanged={retry} />
    <section aria-labelledby="restaurant-reviews-title" className="mt-8">
      <div className="flex items-center justify-between gap-3">
        <h2 id="restaurant-reviews-title" className="text-xl font-bold">{t("title")}</h2>
        <label className="sr-only" htmlFor="review-sort">{t("sortLabel")}</label>
        <select
          id="review-sort"
          className="min-h-10 max-w-44 rounded-lg border border-zinc-300 bg-white px-2 text-sm dark:border-zinc-700 dark:bg-zinc-900"
          value={sort}
          onChange={(event) => {
            const parsed = reviewSortSchema.safeParse(event.target.value);
            if (parsed.success) setSort(parsed.data);
          }}
        >
          {sortOptions.map((option) => <option key={option} value={option}>{t("sort." + option)}</option>)}
        </select>
      </div>

      {loading && <p role="status" className="py-8 text-center text-sm text-zinc-600">{t("loading")}</p>}
      {error && (
        <div role="alert" className="mt-4 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          <p>{t("error")}</p>
          <button type="button" onClick={retry} className="mt-2 font-semibold underline">{t("retry")}</button>
        </div>
      )}
      {!loading && !error && reviews.length === 0 && <p className="py-8 text-center text-sm text-zinc-600">{t("empty")}</p>}
      <ul className="mt-4 space-y-3">
        {reviews.map((review) => <li key={review.id}><ReviewCard review={review} /></li>)}
      </ul>
      {hasMore && !error && (
        <button type="button" onClick={() => void loadMore()} disabled={loadingMore} className="mt-4 min-h-11 w-full rounded-xl border border-zinc-300 bg-white px-4 text-sm font-semibold disabled:opacity-60 dark:border-zinc-700 dark:bg-zinc-900">
          {loadingMore ? t("loadingMore") : t("loadMore")}
        </button>
      )}
    </section>
    </>
  );
}
