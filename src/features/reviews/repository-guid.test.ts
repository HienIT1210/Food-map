import { beforeEach, describe, expect, it, vi } from "vitest";
import { getMyReview, removeReview, saveReview } from "./repository";

const { mockRpc } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
}));

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    rpc: mockRpc,
    storage: { from: () => ({ remove: vi.fn() }) },
  }),
}));

const restaurantId = "dddd4444-4444-4444-4444-444444444444";
const dishId = "d2222222-2222-2222-2222-222222222222";
const reviewId = "e2222222-2222-2222-2222-222222222222";

beforeEach(() => {
  mockRpc.mockReset();
});

describe("review repository server UUID responses", () => {
  it("accepts PostgreSQL UUIDs in the my-review response", async () => {
    mockRpc.mockResolvedValue({
      data: [{ id: reviewId, rating: 5, content: null, is_anonymous: true }],
      error: null,
    });

    await expect(getMyReview(restaurantId, dishId)).resolves.toEqual({
      id: reviewId,
      rating: 5,
      content: null,
      is_anonymous: true,
    });
  });

  it("accepts PostgreSQL UUIDs in save-review inputs and return value", async () => {
    mockRpc.mockResolvedValue({ data: reviewId, error: null });

    await expect(saveReview({
      restaurantId,
      rating: 5,
      content: "",
      isAnonymous: true,
      dishId,
    })).resolves.toBe(reviewId);
    expect(mockRpc).toHaveBeenCalledWith("save_review", expect.objectContaining({
      p_restaurant_id: restaurantId,
      p_dish_id: dishId,
    }));
  });

  it("accepts PostgreSQL UUIDs in the delete-review response", async () => {
    mockRpc.mockResolvedValue({
      data: [{ deleted_review_id: reviewId, storage_paths: [] }],
      error: null,
    });

    await expect(removeReview(reviewId)).resolves.toBeUndefined();
  });
});
