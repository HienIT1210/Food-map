import { StrictMode, type ReactNode } from "react";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { NextIntlClientProvider } from "next-intl";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import viMessages from "@/messages/vi.json";
import { RestaurantDetail } from "./RestaurantDetail";

const {
  mockRpc,
  mockFrom,
  mockRpcAbortSignal,
  mockSelect,
  mockEq,
  mockDishesAbortSignal,
} = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockRpcAbortSignal: vi.fn(),
  mockSelect: vi.fn(),
  mockEq: vi.fn(),
  mockDishesAbortSignal: vi.fn(),
}));

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    rpc: mockRpc,
    from: mockFrom,
  }),
}));

vi.mock("@/i18n/navigation", () => ({
  Link: ({ href, children }: { href: string; children: ReactNode }) => <a href={href}>{children}</a>,
}));

vi.mock("@/features/reviews/components/ReviewList", () => ({
  ReviewList: () => null,
}));

vi.mock("./RestaurantReport", () => ({
  RestaurantReport: () => null,
}));

const restaurantId = "dddd4444-4444-4444-4444-444444444444";
const dishId = "d2222222-2222-2222-2222-222222222222";
const restaurantResponse = [{
  id: restaurantId,
  name: "Quán thử",
  address: "12 Lê Lợi",
  province: "Hà Nội",
  avg_rating: "4.50",
  lat: "21.0285",
  lng: "105.8542",
  review_count: 12,
}];
const dishesResponse = [{
  price_vnd: 65000,
  dish: { id: dishId, name: "Phở bò" },
}];

function renderDetail() {
  return render(
    <StrictMode>
      <NextIntlClientProvider locale="vi" messages={viMessages}>
        <RestaurantDetail restaurantId={restaurantId} />
      </NextIntlClientProvider>
    </StrictMode>,
  );
}

beforeEach(() => {
  mockRpc.mockReturnValue({ abortSignal: mockRpcAbortSignal });
  mockRpcAbortSignal.mockResolvedValue({ data: restaurantResponse, error: null });
  mockFrom.mockReturnValue({ select: mockSelect });
  mockSelect.mockReturnValue({ eq: mockEq });
  mockEq.mockReturnValue({ abortSignal: mockDishesAbortSignal });
  mockDishesAbortSignal.mockResolvedValue({ data: dishesResponse, error: null });
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.clearAllMocks();
});

describe("RestaurantDetail", () => {
  it("parses the RPC and nested dish responses and renders without a load error in Strict Mode", async () => {
    renderDetail();

    expect(await screen.findByRole("heading", { name: "Quán thử" })).toBeTruthy();
    expect(screen.getByText("Phở bò")).toBeTruthy();
    expect(screen.queryByRole("alert")).toBeNull();

    await waitFor(() => {
      expect(mockRpc).toHaveBeenCalledTimes(1);
      expect(mockFrom).toHaveBeenCalledTimes(1);
    });
    expect(mockRpc).toHaveBeenCalledWith("restaurant_detail", { p_restaurant_id: restaurantId });
    expect(mockEq).toHaveBeenCalledWith("restaurant_id", restaurantId);
    expect(mockRpcAbortSignal).toHaveBeenCalledWith(expect.any(AbortSignal));
    expect(mockDishesAbortSignal).toHaveBeenCalledWith(expect.any(AbortSignal));
  });

  it("logs Zod paths without logging invalid response values", async () => {
    const logError = vi.spyOn(console, "error").mockImplementation(() => undefined);
    mockDishesAbortSignal.mockResolvedValue({
      data: [{ price_vnd: "sensitive-value", dish: { id: dishId, name: "Phở bò" } }],
      error: null,
    });

    renderDetail();

    expect(await screen.findByRole("alert")).toBeTruthy();
    expect(logError).toHaveBeenCalledWith("Restaurant detail load failed", {
      name: "ZodError",
      issues: [{
        path: "0.price_vnd",
        code: "invalid_type",
        message: expect.any(String),
      }],
    });
    expect(JSON.stringify(logError.mock.calls)).not.toContain("sensitive-value");
  });
});
