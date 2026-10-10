import { z } from "zod";

export const restaurantDetailsSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  address: z.string().nullable(),
  province: z.string().nullable(),
  avg_rating: z.coerce.number(),
  review_count: z.coerce.number().int().nonnegative(),
  lat: z.coerce.number(),
  lng: z.coerce.number(),
});

export const restaurantSearchResultSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  address: z.string().nullable(),
  avg_rating: z.coerce.number(),
  review_count: z.coerce.number().int().nonnegative(),
  lat: z.coerce.number(),
  lng: z.coerce.number(),
});

export const restaurantDishSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  priceVnd: z.number().int().nonnegative().nullable(),
});

// M6: a server-side duplicate candidate. created_by is deliberately absent; the RPC never returns it.
export const duplicateRestaurantSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  address: z.string().nullable(),
  distance_meters: z.coerce.number().nonnegative(),
});

// M6 create form. The RPC accepts no status/source/created_by/avg_rating field, so the schema cannot
// smuggle one either.
export const createRestaurantInputSchema = z.object({
  name: z.string().trim().min(1, "name-required").max(120, "name-too-long"),
  address: z.string().trim().max(300, "address-too-long").default(""),
  province: z.string().trim().max(120, "province-too-long").default(""),
  lat: z.number().min(-90, "lat-range").max(90, "lat-range"),
  lng: z.number().min(-180, "lng-range").max(180, "lng-range"),
  dishes: z
    .array(z.object({ dish_id: z.string().uuid(), price_vnd: z.number().int().nonnegative().nullable() }))
    .max(10, "too-many-dishes")
    .default([]),
  confirmNew: z.boolean().default(false),
});

export const restaurantReportReasonSchema = z.enum(["closed", "wrong_location", "wrong_info"]);

export type RestaurantDetails = z.infer<typeof restaurantDetailsSchema>;
export type RestaurantSearchResult = z.infer<typeof restaurantSearchResultSchema>;
export type RestaurantDish = z.infer<typeof restaurantDishSchema>;
export type DuplicateRestaurant = z.infer<typeof duplicateRestaurantSchema>;
export type CreateRestaurantInput = z.input<typeof createRestaurantInputSchema>;
export type RestaurantReportReason = z.infer<typeof restaurantReportReasonSchema>;
