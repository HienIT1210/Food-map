import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  createRestaurantInputSchema,
  duplicateRestaurantSchema,
  restaurantDetailsSchema,
  restaurantDishSchema,
  restaurantReportReasonSchema,
  restaurantSearchResultSchema,
  type DuplicateRestaurant,
  type RestaurantDish,
  type RestaurantDetails,
  type RestaurantReportReason,
  type RestaurantSearchResult,
  type CreateRestaurantInput,
} from "./types";

const restaurantDishesSchema = z.array(z.object({
  price_vnd: z.number().int().nonnegative().nullable(),
  dish: z.union([z.object({ id: z.string().uuid(), name: z.string() }), z.array(z.object({ id: z.string().uuid(), name: z.string() }))]).nullable(),
}));

function throwIfError(error: { message: string } | null): void {
  if (error) throw new Error(error.message);
}

/** A create refusal the UI must explain specifically instead of showing a generic failure. */
export class RestaurantWriteError extends Error {
  constructor(
    message: string,
    public readonly code: string | null,
    public readonly hint: string | null,
    public readonly detail: string | null,
  ) {
    super(message);
    this.name = "RestaurantWriteError";
  }
}

/** Stable identifiers the database raises with, so the UI never matches on message text. */
export const RESTAURANT_ERROR_HINTS = {
  duplicate: "duplicate_restaurant",
  dailyLimit: "restaurant_daily_limit",
} as const;

function writeError(error: { message: string; code?: string | null; hint?: string | null; details?: string | null } | null): Error | null {
  if (!error) return null;
  return new RestaurantWriteError(error.message, error.code ?? null, error.hint ?? null, error.details ?? null);
}

export async function checkDuplicateRestaurant(
  name: string,
  lat: number,
  lng: number,
  signal: AbortSignal,
): Promise<DuplicateRestaurant[]> {
  const supabase = createClient();
  // The RPC signature is (name text, lat float, lng float); a bare JSON number resolves to double
  // precision on the PostgREST side, which is what the float parameters accept.
  const { data, error } = await supabase
    .rpc("check_duplicate_restaurant", { name, lat, lng })
    .abortSignal(signal);
  throwIfError(error);
  return duplicateRestaurantSchema.array().parse(data ?? []);
}

export async function createRestaurant(input: CreateRestaurantInput): Promise<string> {
  const parsed = createRestaurantInputSchema.parse(input);
  const supabase = createClient();
  const { data, error } = await supabase.rpc("create_restaurant", {
    p_name: parsed.name,
    p_address: parsed.address,
    p_lat: parsed.lat,
    p_lng: parsed.lng,
    p_province: parsed.province,
    p_dishes: parsed.dishes,
    p_confirm_new: parsed.confirmNew,
  });
  const mapped = writeError(error);
  if (mapped) throw mapped;
  return z.string().uuid().parse(data);
}

export async function reportRestaurant(
  restaurantId: string,
  reason: RestaurantReportReason,
): Promise<void> {
  const parsedReason = restaurantReportReasonSchema.parse(reason);
  const supabase = createClient();
  const { data, error } = await supabase.rpc("report_restaurant", {
    p_restaurant_id: restaurantId,
    p_reason: parsedReason,
  });
  const mapped = writeError(error);
  if (mapped) throw mapped;
  if (data !== true) throw new RestaurantWriteError("Report not recorded", null, null, null);
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
    .select("price_vnd, dish:dishes(id, name)")
    .eq("restaurant_id", restaurantId)
    .abortSignal(signal);
  throwIfError(error);
  return restaurantDishesSchema.parse(data ?? []).flatMap((row) => {
    const dish = Array.isArray(row.dish) ? row.dish[0] : row.dish;
    return dish ? [restaurantDishSchema.parse({ id: dish.id, name: dish.name, priceVnd: row.price_vnd })] : [];
  });
}
