import { describe, expect, it } from "vitest";
import {
  buildRestaurantRpcFilters,
  distanceInMeters,
  hasMovedOutsideLoadedBounds,
  type MapBounds,
} from "./map-utils";
import { restaurantPinSchema } from "./hooks/useRestaurantsInBounds";

const loadedBounds: MapBounds = {
  minLat: 10,
  minLng: 106,
  maxLat: 11,
  maxLng: 107,
};

describe("map request helpers", () => {
  it("accepts PostgreSQL UUIDs from seed data in map pin responses", () => {
    expect(restaurantPinSchema.parse({
      id: "dddd4444-4444-4444-4444-444444444444",
      name: "Quán seed",
      lat: "21.02",
      lng: "105.8",
      avg_rating: "4.5",
      review_count: 2,
      status: "active",
      province: "Hà Nội",
      dish_types: ["Cơm"],
    }).id).toBe("dddd4444-4444-4444-4444-444444444444");
  });

  it("sends only active filters to restaurants_in_bounds", () => {
    expect(
      buildRestaurantRpcFilters({
        minRating: 4,
        maxPrice: 100_000,
        dishType: "Phở",
        province: null,
      }),
    ).toEqual({ min_rating: 4, max_price: 100_000, dish_type: "Phở" });
  });

  it("shows find-in-area only after the viewport moves outside loaded bounds", () => {
    expect(hasMovedOutsideLoadedBounds(null, loadedBounds)).toBe(false);
    expect(hasMovedOutsideLoadedBounds(loadedBounds, loadedBounds)).toBe(false);
    expect(
      hasMovedOutsideLoadedBounds(
        { ...loadedBounds, maxLng: 107.3 },
        loadedBounds,
      ),
    ).toBe(true);
  });

  it("calculates distance in meters for the list", () => {
    expect(distanceInMeters({ lat: 0, lng: 0 }, { lat: 0, lng: 1 })).toBeCloseTo(
      111_195,
      -1,
    );
  });
});
