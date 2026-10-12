import { beforeEach, describe, expect, it, vi } from "vitest";
import { createRestaurant } from "./repository";

const { mockRpc } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
}));

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({ rpc: mockRpc }),
}));

const restaurantId = "dddd4444-4444-4444-4444-444444444444";
const dishId = "d2222222-2222-2222-2222-222222222222";

beforeEach(() => {
  mockRpc.mockReset();
  mockRpc.mockResolvedValue({ data: restaurantId, error: null });
});

describe("restaurant repository server UUID responses", () => {
  it("accepts PostgreSQL UUIDs in create-restaurant inputs and return value", async () => {
    await expect(createRestaurant({
      name: "Quán mới",
      lat: 21.02,
      lng: 105.8,
      dishes: [{ dish_id: dishId, price_vnd: 50000 }],
    })).resolves.toBe(restaurantId);

    expect(mockRpc).toHaveBeenCalledWith("create_restaurant", expect.objectContaining({
      p_dishes: [{ dish_id: dishId, price_vnd: 50000 }],
    }));
  });
});
