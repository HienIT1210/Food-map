import { cleanup, render, screen } from "@testing-library/react";
import { NextIntlClientProvider } from "next-intl";
import { afterEach, describe, expect, it, vi } from "vitest";
import viMessages from "@/messages/vi.json";
import { ReviewCard } from "./components/ReviewCard";
import { listRestaurantReviews } from "./repository";
import type { PublicReview } from "./types";

const anonymousReview: PublicReview = {
  id: "a4040000-0000-4000-8000-000000000005",
  restaurant_id: "a4040000-0000-4000-8000-000000000004",
  dish_id: null,
  rating: 5,
  content: "Nước dùng ngon.",
  is_anonymous: true,
  helpful_count: 3,
  created_at: "2026-10-09T10:00:00.000Z",
  author_name: null,
};

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

describe("anonymous public review privacy", () => {
  it("shows the anonymous label without a profile link or user id in the UI", () => {
    const { container } = render(
      <NextIntlClientProvider locale="vi" messages={viMessages}>
        <ReviewCard review={anonymousReview} />
      </NextIntlClientProvider>,
    );

    expect(screen.getByText("Thực khách ẩn danh")).toBeTruthy();
    expect(container.querySelector("a")).toBeNull();
    expect(container.innerHTML).not.toContain("user_id");
    expect(container.innerHTML).not.toContain("bbbb2222");
  });

  it("requests only public_reviews columns and the network response has no user_id", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://localhost:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "test-anon-key");
    const requestUrls: string[] = [];
    const responseBodies: string[] = [];
    vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL) => {
      requestUrls.push(input instanceof Request ? input.url : String(input));
      const body = JSON.stringify([anonymousReview]);
      responseBodies.push(body);
      return new Response(body, {
        status: 200,
        headers: {
          "content-type": "application/json",
          "content-range": "0-0/1",
        },
      });
    }));

    const page = await listRestaurantReviews(
      anonymousReview.restaurant_id,
      "newest",
      null,
      new AbortController().signal,
    );

    expect(requestUrls).toHaveLength(1);
    const requestUrl = new URL(requestUrls[0]);
    expect(requestUrl.pathname).toBe("/rest/v1/public_reviews");
    expect(requestUrl.searchParams.get("select")).not.toContain("user_id");
    expect(requestUrl.searchParams.get("select")).not.toContain("author_id");
    expect(responseBodies[0]).not.toContain("user_id");
    expect(JSON.stringify(page.reviews)).not.toContain("user_id");
    expect(JSON.stringify(page.reviews)).not.toContain("bbbb2222");
  });
});
