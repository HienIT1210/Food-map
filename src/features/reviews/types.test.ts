import { describe, expect, it } from "vitest";
import { ownReviewSchema, publicReviewSchema } from "./types";

const restaurantId = "dddd4444-4444-4444-4444-444444444444";
const dishId = "d2222222-2222-2222-2222-222222222222";
const reviewId = "e2222222-2222-2222-2222-222222222222";
const createdAt = "2026-10-12T10:00:00.000Z";

describe("review server response schemas", () => {
  it("accepts PostgreSQL UUIDs from seed data in public reviews", () => {
    expect(publicReviewSchema.parse({
      id: reviewId,
      restaurant_id: restaurantId,
      dish_id: dishId,
      rating: 5,
      content: null,
      is_anonymous: true,
      helpful_count: 0,
      created_at: createdAt,
      author_name: null,
      photo_paths: [],
    })).toMatchObject({
      id: reviewId,
      restaurant_id: restaurantId,
      dish_id: dishId,
    });
  });

  it("accepts PostgreSQL UUIDs from seed data in own reviews", () => {
    expect(ownReviewSchema.parse({
      id: reviewId,
      restaurant_id: restaurantId,
      restaurant_name: "Quán seed",
      dish_id: dishId,
      rating: 5,
      content: null,
      is_anonymous: true,
      created_at: createdAt,
    })).toMatchObject({
      id: reviewId,
      restaurant_id: restaurantId,
      dish_id: dishId,
    });
  });
});
