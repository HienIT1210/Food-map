"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { listRestaurantReviews } from "../repository";
import type { PublicReview, ReviewCursor, ReviewSort } from "../types";

export function useRestaurantReviews(restaurantId: string, sort: ReviewSort) {
  const [reviews, setReviews] = useState<PublicReview[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [nextCursor, setNextCursor] = useState<ReviewCursor | null>(null);
  const requestRef = useRef<AbortController | null>(null);
  const cursorRef = useRef<ReviewCursor | null>(null);
  const loadingMoreRef = useRef(false);

  const loadFirstPage = useCallback(() => {
    requestRef.current?.abort();
    const controller = new AbortController();
    requestRef.current = controller;
    cursorRef.current = null;
    setReviews([]);
    setNextCursor(null);
    setLoading(true);
    setLoadingMore(false);
    loadingMoreRef.current = false;
    setError(null);
    void listRestaurantReviews(restaurantId, sort, null, controller.signal)
      .then((page) => {
        if (controller.signal.aborted) return;
        setReviews(page.reviews);
        cursorRef.current = page.nextCursor;
        setNextCursor(page.nextCursor);
      })
      .catch((requestError: unknown) => {
        if (controller.signal.aborted) return;
        setError(requestError instanceof Error ? requestError : new Error(String(requestError)));
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
  }, [restaurantId, sort]);

  useEffect(() => {
    let cancelled = false;
    queueMicrotask(() => {
      if (!cancelled) loadFirstPage();
    });
    return () => {
      cancelled = true;
      requestRef.current?.abort();
    };
  }, [loadFirstPage]);

  const loadMore = useCallback(async () => {
    const cursor = cursorRef.current;
    if (!cursor || loadingMoreRef.current) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    setError(null);
    const controller = new AbortController();
    requestRef.current = controller;
    try {
      const page = await listRestaurantReviews(restaurantId, sort, cursor, controller.signal);
      if (controller.signal.aborted) return;
      setReviews((current) => [...current, ...page.reviews]);
      cursorRef.current = page.nextCursor;
      setNextCursor(page.nextCursor);
    } catch (requestError: unknown) {
      if (!controller.signal.aborted) {
        setError(requestError instanceof Error ? requestError : new Error(String(requestError)));
      }
    } finally {
      if (!controller.signal.aborted) {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      }
    }
  }, [restaurantId, sort]);

  return { reviews, loading, loadingMore, error, hasMore: nextCursor !== null, loadMore, retry: loadFirstPage };
}
