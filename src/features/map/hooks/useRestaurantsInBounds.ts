import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";
import {
  buildRestaurantRpcFilters,
  type MapBounds,
  type MapFilters,
} from "../map-utils";

export const restaurantPinSchema = z.object({
  id: z.string().guid(),
  name: z.string(),
  lat: z.coerce.number(),
  lng: z.coerce.number(),
  avg_rating: z.coerce.number(),
  review_count: z.coerce.number().int().nonnegative(),
  status: z.string(),
  province: z.string().nullable(),
  dish_types: z.array(z.string()),
});

export type RestaurantPin = z.infer<typeof restaurantPinSchema>;

export function useRestaurantsInBounds() {
  const [restaurants, setRestaurants] = useState<RestaurantPin[]>([]);
  const [dishTypes, setDishTypes] = useState<string[]>([]);
  const [provinces, setProvinces] = useState<string[]>([]);
  const [loadedBounds, setLoadedBounds] = useState<MapBounds | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const abortControllerRef = useRef<AbortController | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const supabase = useMemo(() => createClient(), []);

  const fetchInBounds = useCallback(
    (bounds: MapBounds, filters: MapFilters) => {
      abortControllerRef.current?.abort();
      const controller = new AbortController();
      abortControllerRef.current = controller;

      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      setLoading(true);
      setError(null);
      timeoutRef.current = setTimeout(async () => {
        try {
          const { data, error: requestError } = await supabase
            .rpc("restaurants_in_bounds", {
              min_lat: bounds.minLat,
              min_lng: bounds.minLng,
              max_lat: bounds.maxLat,
              max_lng: bounds.maxLng,
              filters: buildRestaurantRpcFilters(filters),
              lim: 500,
            })
            .abortSignal(controller.signal);

          if (requestError) throw requestError;
          const parsedRestaurants = restaurantPinSchema.array().parse(data ?? []);
          setRestaurants(parsedRestaurants);
          setLoadedBounds(bounds);
          if (filters.dishType === null) {
            setDishTypes(
              Array.from(new Set(parsedRestaurants.flatMap((place) => place.dish_types))).sort(),
            );
          }
          if (filters.province === null) {
            setProvinces(
              Array.from(
                new Set(
                  parsedRestaurants
                    .map((place) => place.province)
                    .filter((province): province is string => province !== null),
                ),
              ).sort(),
            );
          }
        } catch (requestError: unknown) {
          if (controller.signal.aborted) return;
          setError(
            requestError instanceof Error
              ? requestError
              : new Error(String(requestError)),
          );
        } finally {
          if (!controller.signal.aborted) setLoading(false);
        }
      }, 300);
    },
    [supabase],
  );

  useEffect(
    () => () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      abortControllerRef.current?.abort();
    },
    [],
  );

  return {
    restaurants,
    dishTypes,
    provinces,
    loadedBounds,
    loading,
    error,
    fetchInBounds,
  };
}
