"use client";

import { useEffect, useState } from "react";
import { searchRestaurants } from "../repository";
import type { RestaurantSearchResult } from "../types";

export function useRestaurantSearch(query: string, retryVersion: number) {
  const [state, setState] = useState<{
    query: string;
    results: RestaurantSearchResult[];
    loading: boolean;
    error: Error | null;
  }>({ query: "", results: [], loading: false, error: null });
  useEffect(() => {
    const normalizedQuery = query.trim();
    const controller = new AbortController();
    if (normalizedQuery.length < 2) return () => controller.abort();
    const timeout = setTimeout(async () => {
      setState({ query: normalizedQuery, results: [], loading: true, error: null });
      try {
        const results = await searchRestaurants(normalizedQuery, controller.signal);
        if (!controller.signal.aborted) setState({ query: normalizedQuery, results, loading: false, error: null });
      } catch (requestError: unknown) {
        if (controller.signal.aborted) return;
        setState({
          query: normalizedQuery,
          results: [],
          loading: false,
          error: requestError instanceof Error ? requestError : new Error(String(requestError)),
        });
      }
    }, 300);

    return () => {
      clearTimeout(timeout);
      controller.abort();
    };
  }, [query, retryVersion]);

  const isSearching = query.trim().length >= 2;
  const currentState = state.query === query.trim();
  return {
    results: currentState ? state.results : [],
    loading: isSearching && (!currentState || state.loading),
    error: currentState ? state.error : null,
  };
}
