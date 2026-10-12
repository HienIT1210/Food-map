import { describe, expect, it } from "vitest";
import {
  createRestaurantInputSchema,
  duplicateRestaurantSchema,
  restaurantDetailsSchema,
  restaurantDishSchema,
  restaurantReportReasonSchema,
  restaurantSearchResultSchema,
} from "./types";

const invalidLat = 91;
const invalidLng = 200;
const restaurantId = "dddd4444-4444-4444-4444-444444444444";
const dishId = "d2222222-2222-2222-2222-222222222222";

describe("restaurant server response schemas", () => {
  it("accepts PostgreSQL UUIDs from seed data in detail, search, and dish responses", () => {
    expect(restaurantDetailsSchema.parse({
      id: restaurantId,
      name: "Quán seed",
      address: null,
      province: "Hà Nội",
      avg_rating: "4.5",
      review_count: 2,
      lat: "21.02",
      lng: "105.8",
    }).id).toBe(restaurantId);
    expect(restaurantSearchResultSchema.parse({
      id: restaurantId,
      name: "Quán seed",
      address: null,
      avg_rating: 4.5,
      review_count: 2,
      lat: 21.02,
      lng: 105.8,
    }).id).toBe(restaurantId);
    expect(restaurantDishSchema.parse({
      id: dishId,
      name: "Cơm Tấm",
      priceVnd: 50000,
    }).id).toBe(dishId);
  });

  it("accepts a seed dish ID in the restaurant creation payload", () => {
    expect(createRestaurantInputSchema.parse({
      name: "Quán mới",
      lat: 21.02,
      lng: 105.8,
      dishes: [{ dish_id: dishId, price_vnd: 50000 }],
    }).dishes[0].dish_id).toBe(dishId);
  });
});

describe("M6 create-restaurant input", () => {
  it("accepts the fields the RPC takes and nothing that grants server-managed state", () => {
    const parsed = createRestaurantInputSchema.parse({
      name: "  Quán Mới  ",
      address: "12 Lê Lợi",
      province: "Hà Nội",
      lat: 21.01,
      lng: 105.81,
    });
    expect(parsed.name).toBe("Quán Mới");
    expect(parsed.dishes).toEqual([]);
    expect(parsed.confirmNew).toBe(false);
    // The schema has no status/source/created_by/avg_rating key at all, so a caller cannot smuggle one.
    const keys = Object.keys(parsed);
    for (const forbidden of ["status", "source", "created_by", "avg_rating", "review_count"]) {
      expect(keys).not.toContain(forbidden);
    }
  });

  it("strips unknown keys so a spoofed created_by never reaches the RPC payload", () => {
    const parsed = createRestaurantInputSchema.parse({
      name: "Quán Spoof",
      lat: 21.01,
      lng: 105.81,
      created_by: "a6060000-0000-4000-8000-000000000002",
      status: "removed",
      source: "seed",
      avg_rating: 5,
    } as unknown as Parameters<typeof createRestaurantInputSchema.parse>[0]);
    expect(parsed).not.toHaveProperty("created_by");
    expect(parsed).not.toHaveProperty("status");
    expect(parsed).not.toHaveProperty("source");
    expect(parsed).not.toHaveProperty("avg_rating");
  });

  it("rejects out-of-range coordinates, an empty name, and a negative price", () => {
    expect(createRestaurantInputSchema.safeParse({ name: "A", lat: invalidLat, lng: 105.8 }).success).toBe(false);
    expect(createRestaurantInputSchema.safeParse({ name: "A", lat: 21, lng: invalidLng }).success).toBe(false);
    expect(createRestaurantInputSchema.safeParse({ name: "   ", lat: 21, lng: 105.8 }).success).toBe(false);
    expect(
      createRestaurantInputSchema.safeParse({
        name: "A",
        lat: 21,
        lng: 105.8,
        dishes: [{ dish_id: "a6060000-0000-4000-8000-000000000020", price_vnd: -1 }],
      }).success,
    ).toBe(false);
  });
});

describe("M6 duplicate candidate", () => {
  it("carries no identity field and requires a numeric distance", () => {
    const parsed = duplicateRestaurantSchema.parse({
      id: restaurantId,
      name: "M6 Bún",
      address: null,
      distance_meters: "12.5",
    });
    expect(parsed.distance_meters).toBe(12.5);
    expect(Object.keys(parsed)).not.toContain("created_by");
    expect(duplicateRestaurantSchema.safeParse({ id: restaurantId, name: "x", address: null }).success).toBe(false);
  });
});

describe("M6 report reasons", () => {
  it("allows exactly the three reasons the database accepts", () => {
    expect(restaurantReportReasonSchema.options).toEqual(["closed", "wrong_location", "wrong_info"]);
    expect(restaurantReportReasonSchema.safeParse("closed").success).toBe(true);
    expect(restaurantReportReasonSchema.safeParse("spam").success).toBe(false);
  });
});
