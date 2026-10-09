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

export type RestaurantDetails = z.infer<typeof restaurantDetailsSchema>;
export type RestaurantSearchResult = z.infer<typeof restaurantSearchResultSchema>;
export type RestaurantDish = z.infer<typeof restaurantDishSchema>;
