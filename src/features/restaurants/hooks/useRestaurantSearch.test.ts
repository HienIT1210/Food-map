import { act, renderHook } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { RestaurantSearchResult } from "../types";
import { useRestaurantSearch } from "./useRestaurantSearch";

const mockSearchRestaurants = vi.hoisted(() => vi.fn());
vi.mock("../repository", () => ({ searchRestaurants: mockSearchRestaurants }));

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe("useRestaurantSearch", () => {
  it("debounces input and aborts the previous in-flight RPC when the query changes", async () => {
    vi.useFakeTimers();
    const signals: AbortSignal[] = [];
    mockSearchRestaurants.mockImplementation((_query: string, signal: AbortSignal) => {
      signals.push(signal);
      return new Promise<RestaurantSearchResult[]>(() => undefined);
    });
    const { rerender, unmount } = renderHook(
      ({ query }) => useRestaurantSearch(query, 0),
      { initialProps: { query: "pho" } },
    );

    await act(async () => { await vi.advanceTimersByTimeAsync(299); });
    expect(mockSearchRestaurants).not.toHaveBeenCalled();
    await act(async () => { await vi.advanceTimersByTimeAsync(1); });
    expect(mockSearchRestaurants).toHaveBeenCalledTimes(1);
    expect(mockSearchRestaurants).toHaveBeenCalledWith("pho", expect.any(AbortSignal));

    rerender({ query: "pho bo" });
    expect(signals[0].aborted).toBe(true);
    await act(async () => { await vi.advanceTimersByTimeAsync(300); });
    expect(mockSearchRestaurants).toHaveBeenCalledTimes(2);
    expect(mockSearchRestaurants).toHaveBeenLastCalledWith("pho bo", expect.any(AbortSignal));
    unmount();
  });
});
