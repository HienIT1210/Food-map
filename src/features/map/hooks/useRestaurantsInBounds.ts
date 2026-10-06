import { useState, useRef } from "react";
import { createClient } from "@/lib/supabase/client";

export type RestaurantPin = {
  id: string;
  name: string;
  lat: number;
  lng: number;
  avg_rating: number;
  review_count: number;
  status: string;
};

export function useRestaurantsInBounds() {
  const [restaurants, setRestaurants] = useState<RestaurantPin[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  
  const abortControllerRef = useRef<AbortController | null>(null);
  const supabase = createClient();
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);

  const fetchInBounds = (minLat: number, minLng: number, maxLat: number, maxLng: number) => {
    // Hủy request cũ
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    const controller = new AbortController();
    abortControllerRef.current = controller;

    // Debounce 300ms
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    setLoading(true);
    timeoutRef.current = setTimeout(async () => {
      try {
        const { data, error: err } = await supabase.rpc("restaurants_in_bounds", {
          min_lat: minLat,
          min_lng: minLng,
          max_lat: maxLat,
          max_lng: maxLng,
          filters: {},
          lim: 500
        }).abortSignal(controller.signal);

        if (err) throw err;
        setRestaurants(data || []);
        setError(null);
      } catch (err: unknown) {
        if (err instanceof Error && err.name === "AbortError") return;
        setError(err instanceof Error ? err : new Error(String(err)));
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
        }
      }
    }, 300);
  };

  return { restaurants, loading, error, fetchInBounds };
}
