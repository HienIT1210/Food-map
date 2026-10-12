import { z } from "zod";

export const reviewSortSchema = z.enum(["newest", "helpful", "rating_high", "rating_low"]);
export type ReviewSort = z.infer<typeof reviewSortSchema>;

export const publicReviewSchema = z.object({
  id: z.string().guid(),
  restaurant_id: z.string().guid(),
  dish_id: z.string().guid().nullable(),
  rating: z.number().int().min(1).max(5),
  content: z.string().nullable(),
  is_anonymous: z.boolean(),
  helpful_count: z.number().int().nonnegative(),
  created_at: z.string().datetime({ offset: true }),
  author_name: z.string().nullable(),
  photo_paths: z.array(z.string()),
}).strict();

export type PublicReview = z.infer<typeof publicReviewSchema>;

export type ReviewCursor = Pick<PublicReview, "id" | "rating" | "helpful_count" | "created_at">;

export type ReviewPage = {
  reviews: PublicReview[];
  nextCursor: ReviewCursor | null;
};

export const ownReviewSchema = z.object({
  id: z.string().guid(),
  restaurant_id: z.string().guid(),
  restaurant_name: z.string(),
  dish_id: z.string().guid().nullable(),
  rating: z.number().int().min(1).max(5),
  content: z.string().nullable(),
  is_anonymous: z.boolean(),
  created_at: z.string().datetime({ offset: true }),
}).strict();
export type OwnReview = z.infer<typeof ownReviewSchema>;
