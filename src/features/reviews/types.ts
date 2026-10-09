import { z } from "zod";

export const reviewSortSchema = z.enum(["newest", "helpful", "rating_high", "rating_low"]);
export type ReviewSort = z.infer<typeof reviewSortSchema>;

export const publicReviewSchema = z.object({
  id: z.string().uuid(),
  restaurant_id: z.string().uuid(),
  dish_id: z.string().uuid().nullable(),
  rating: z.number().int().min(1).max(5),
  content: z.string().nullable(),
  is_anonymous: z.boolean(),
  helpful_count: z.number().int().nonnegative(),
  created_at: z.string().datetime({ offset: true }),
  author_name: z.string().nullable(),
}).strict();

export type PublicReview = z.infer<typeof publicReviewSchema>;

export type ReviewCursor = Pick<PublicReview, "id" | "rating" | "helpful_count" | "created_at">;

export type ReviewPage = {
  reviews: PublicReview[];
  nextCursor: ReviewCursor | null;
};
