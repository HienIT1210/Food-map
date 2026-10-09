import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  restaurantDetailsSchema,
  restaurantDishSchema,
  restaurantSearchResultSchema,
  type RestaurantDish,
  type RestaurantDetails,
  type RestaurantSearchResult,
} from "./types";

const restaurantDishesSchema = z.array(z.object({
  price_vnd: z.number().int().nonnegative().nullable(),
  dish: z.union([z.object({ name: z.string() }), z.array(z.object({ name: z.string() }))]).nullable(),
}));

function throwIfError(error: { message: string } | null): void {
  if (error) throw new Error(error.message);
}

export async function searchRestaurants(
  query: string,
  signal: AbortSignal,
): Promise<RestaurantSearchResult[]> {
  const supabase = createClient();
  const { data, error } = await supabase
    .rpc("search_restaurants", { q: query, lim: 10 })
    .abortSignal(signal);
  throwIfError(error);
  return restaurantSearchResultSchema.array().parse(data ?? []);
}

export async function getRestaurantDetails(
  restaurantId: string,
  signal: AbortSignal,
): Promise<RestaurantDetails | null> {
  const supabase = createClient();
  const { data, error } = await supabase
    .rpc("restaurant_detail", { p_restaurant_id: restaurantId })
    .abortSignal(signal);
  throwIfError(error);
  const rows = restaurantDetailsSchema.array().parse(data ?? []);
  return rows[0] ?? null;
}

export async function getRestaurantDishes(
  restaurantId: string,
  signal: AbortSignal,
): Promise<RestaurantDish[]> {
  const supabase = createClient();
  const { data, error } = await supabase
    .from("restaurant_dishes")
    .select("price_vnd, dish:dishes(name)")
    .eq("restaurant_id", restaurantId)
    .abortSignal(signal);
  throwIfError(error);
  return restaurantDishesSchema.parse(data ?? []).flatMap((row) => {
    const dish = Array.isArray(row.dish) ? row.dish[0] : row.dish;
    return dish ? [restaurantDishSchema.parse({ name: dish.name, priceVnd: row.price_vnd })] : [];
  });
}
