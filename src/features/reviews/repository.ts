import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  publicReviewSchema,
  reviewSortSchema,
  type ReviewCursor,
  type ReviewPage,
  type ReviewSort,
} from "./types";

export const REVIEW_PAGE_SIZE = 10;

export function reviewCursorFilter(sort: ReviewSort, cursor: ReviewCursor): string {
  const createdAt = cursor.created_at;
  const id = cursor.id;
  if (sort === "newest") {
    return `created_at.lt.${createdAt},and(created_at.eq.${createdAt},id.lt.${id})`;
  }
  const field = sort === "helpful" ? "helpful_count" : "rating";
  const value = sort === "helpful" ? cursor.helpful_count : cursor.rating;
  const comparison = sort === "rating_low" ? "gt" : "lt";
  return [
    `${field}.${comparison}.${value}`,
    `and(${field}.eq.${value},created_at.lt.${createdAt})`,
    `and(${field}.eq.${value},created_at.eq.${createdAt},id.lt.${id})`,
  ].join(",");
}

export async function listRestaurantReviews(
  restaurantId: string,
  sortValue: ReviewSort,
  cursor: ReviewCursor | null,
  signal: AbortSignal,
): Promise<ReviewPage> {
  const sort = reviewSortSchema.parse(sortValue);
  const supabase = createClient();
  let query = supabase
    .from("public_reviews")
    .select("id, restaurant_id, dish_id, rating, content, is_anonymous, helpful_count, created_at, author_name")
    .eq("restaurant_id", restaurantId);

  if (cursor) query = query.or(reviewCursorFilter(sort, cursor));
  if (sort === "helpful") query = query.order("helpful_count", { ascending: false });
  if (sort === "rating_high") query = query.order("rating", { ascending: false });
  if (sort === "rating_low") query = query.order("rating", { ascending: true });
  query = query.order("created_at", { ascending: false }).order("id", { ascending: false });

  const { data, error } = await query.limit(REVIEW_PAGE_SIZE + 1).abortSignal(signal);
  if (error) throw new Error(error.message);
  const rows = z.array(publicReviewSchema).parse(data ?? []);
  const hasMore = rows.length > REVIEW_PAGE_SIZE;
  const reviews = rows.slice(0, REVIEW_PAGE_SIZE);
  const last = reviews.at(-1);
  return {
    reviews,
    nextCursor: hasMore && last
      ? { id: last.id, rating: last.rating, helpful_count: last.helpful_count, created_at: last.created_at }
      : null,
  };
}
