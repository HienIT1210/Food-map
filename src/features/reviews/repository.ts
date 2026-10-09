import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  publicReviewSchema,
  ownReviewSchema,
  reviewSortSchema,
  type ReviewCursor,
  type ReviewPage,
  type ReviewSort,
} from "./types";
import { MAX_REVIEW_PHOTOS, prepareReviewPhoto } from "./image-processing";

export const REVIEW_PAGE_SIZE = 10;

export type ReviewDraft = {
  restaurantId: string;
  rating: number;
  content: string;
  isAnonymous: boolean;
  dishId: string | null;
};

export type OwnReviewDraft = { id: string; rating: number; content: string | null; is_anonymous: boolean };

export async function getMyReview(restaurantId: string, dishId: string | null): Promise<OwnReviewDraft | null> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("my_review_for_target", {
    p_restaurant_id: restaurantId,
    p_dish_id: dishId,
  });
  if (error) throw new Error(error.message);
  const rows = z.array(z.object({
    id: z.string().uuid(),
    rating: z.number().int().min(1).max(5),
    content: z.string().nullable(),
    is_anonymous: z.boolean(),
  }).strict()).parse(data ?? []);
  return rows[0] ?? null;
}

export async function listMyReviews(): Promise<z.infer<typeof ownReviewSchema>[]> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("my_reviews");
  if (error) throw new Error(error.message);
  return z.array(ownReviewSchema).parse(data ?? []);
}

export async function saveReview(draft: ReviewDraft): Promise<string> {
  const parsed = z.object({
    rating: z.number().int().min(1).max(5),
    restaurantId: z.string().uuid(),
    content: z.string().max(2000),
    isAnonymous: z.boolean(),
    dishId: z.string().uuid().nullable(),
  }).strict().parse(draft);
  const supabase = createClient();
  const { data, error } = await supabase.rpc("save_review", {
    p_restaurant_id: parsed.restaurantId,
    p_dish_id: parsed.dishId,
    p_rating: parsed.rating,
    p_content: parsed.content,
    p_is_anonymous: parsed.isAnonymous,
  });
  if (error) throw new Error(error.message);
  return z.string().uuid().parse(data);
}

export async function uploadReviewPhotos(reviewId: string, files: File[]): Promise<void> {
  if (files.length > MAX_REVIEW_PHOTOS) throw new Error("At most five photos are allowed");
  const supabase = createClient();
  for (const [index, file] of files.entries()) {
    const photo = await prepareReviewPhoto(file);
    const path = `${reviewId}/${crypto.randomUUID()}.jpg`;
    const { error: uploadError } = await supabase.storage.from("review-photos").upload(path, photo, {
      contentType: "image/jpeg",
      upsert: false,
    });
    if (uploadError) throw new Error(uploadError.message);
    const { error: metadataError } = await supabase.rpc("add_review_photo", {
      p_review_id: reviewId,
      p_storage_path: path,
      p_position: index,
    });
    if (metadataError) {
      await supabase.storage.from("review-photos").remove([path]);
      throw new Error(metadataError.message);
    }
  }
}

export async function removeReview(reviewId: string): Promise<void> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("delete_review", { p_review_id: reviewId });
  if (error) throw new Error(error.message);
  if (data !== true) throw new Error("Review not found");
}

export async function toggleHelpful(reviewId: string): Promise<boolean> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("toggle_review_helpful", { p_review_id: reviewId });
  if (error) throw new Error(error.message);
  return z.boolean().parse(data);
}

export function getReviewPhotoUrl(path: string): string {
  const supabase = createClient();
  return supabase.storage.from("review-photos").getPublicUrl(path).data.publicUrl;
}

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
    .select("id, restaurant_id, dish_id, rating, content, is_anonymous, helpful_count, created_at, author_name, photo_paths")
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
