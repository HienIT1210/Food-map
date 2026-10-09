"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Link } from "@/i18n/navigation";
import { useFormatter, useTranslations } from "next-intl";
import { getRestaurantDetails, getRestaurantDishes } from "../repository";
import type { RestaurantDetails, RestaurantDish } from "../types";
import { ReviewList } from "@/features/reviews/components/ReviewList";

function directionsUrl(lat: number, lng: number): string {
  return "https://www.google.com/maps/dir/?api=1&destination=" + lat + "," + lng;
}

function appleMapsUrl(lat: number, lng: number): string {
  return "https://maps.apple.com/?daddr=" + lat + "," + lng;
}

export function RestaurantDetail({ restaurantId }: { restaurantId: string }) {
  const t = useTranslations("restaurant");
  const format = useFormatter();
  const [restaurant, setRestaurant] = useState<RestaurantDetails | null>(null);
  const [dishes, setDishes] = useState<RestaurantDish[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [shareMessage, setShareMessage] = useState("");
  const requestRef = useRef<AbortController | null>(null);

  const load = useCallback(async (signal: AbortSignal) => {
    setLoading(true);
    setError(false);
    try {
      const [detail, menu] = await Promise.all([
        getRestaurantDetails(restaurantId, signal),
        getRestaurantDishes(restaurantId, signal),
      ]);
      if (signal.aborted) return;
      setRestaurant(detail);
      setDishes(menu);
    } catch {
      if (!signal.aborted) setError(true);
    } finally {
      if (!signal.aborted) setLoading(false);
    }
  }, [restaurantId]);

  useEffect(() => {
    const controller = new AbortController();
    requestRef.current = controller;
    let cancelled = false;
    queueMicrotask(() => {
      if (!cancelled) void load(controller.signal);
    });
    return () => {
      cancelled = true;
      controller.abort();
    };
  }, [load]);

  const share = async () => {
    const url = window.location.href;
    try {
      if (navigator.share) {
        await navigator.share({ title: restaurant?.name ?? t("title"), url });
      } else {
        await navigator.clipboard.writeText(url);
      }
      setShareMessage(t("shareSuccess"));
    } catch (shareError: unknown) {
      if (shareError instanceof Error && shareError.name === "AbortError") return;
      setShareMessage(t("shareError"));
    }
  };

  const retry = () => {
    requestRef.current?.abort();
    const controller = new AbortController();
    requestRef.current = controller;
    void load(controller.signal);
  };

  return (
    <main className="mx-auto min-h-[calc(100dvh-4rem)] w-full max-w-3xl px-4 pb-24 pt-4 sm:px-6">
      <Link href="/" className="inline-flex min-h-10 items-center text-sm font-semibold text-blue-700 underline dark:text-blue-300">
        ← {t("backToMap")}
      </Link>
      {loading && <p role="status" className="py-16 text-center text-sm text-zinc-600">{t("loading")}</p>}
      {error && (
        <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
          <p>{t("error")}</p>
          <button type="button" onClick={retry} className="mt-2 font-semibold underline">{t("retry")}</button>
        </div>
      )}
      {!loading && !error && !restaurant && <p className="py-16 text-center text-sm text-zinc-600">{t("notFound")}</p>}
      {!loading && !error && restaurant && (
        <>
          <header className="mt-4 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm dark:border-zinc-800 dark:bg-zinc-900">
            <h1 className="text-2xl font-bold">{restaurant.name}</h1>
            <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-300">{restaurant.address || restaurant.province || t("noAddress")}</p>
            {restaurant.province && restaurant.address && <p className="mt-1 text-sm text-zinc-500">{restaurant.province}</p>}
            <p className="mt-3 text-sm font-semibold">★ {restaurant.avg_rating.toFixed(1)} · {t("reviewCount", { count: restaurant.review_count })}</p>
            <div className="mt-4 flex flex-wrap gap-2">
              <a
                href={directionsUrl(restaurant.lat, restaurant.lng)}
                target="_blank"
                rel="noreferrer"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white"
              >
                {t("directionsGoogle")}
              </a>
              <a
                href={appleMapsUrl(restaurant.lat, restaurant.lng)}
                className="inline-flex min-h-11 items-center justify-center rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700"
              >
                {t("directionsApple")}
              </a>
              <button type="button" onClick={() => void share()} className="inline-flex min-h-11 items-center justify-center rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700">
                {t("share")}
              </button>
            </div>
            {shareMessage && <p role="status" className="mt-2 text-sm text-zinc-600">{shareMessage}</p>}
          </header>

          <section aria-labelledby="restaurant-menu-title" className="mt-7">
            <h2 id="restaurant-menu-title" className="text-xl font-bold">{t("menuTitle")}</h2>
            {dishes.length === 0 ? (
              <p className="py-5 text-sm text-zinc-600">{t("menuEmpty")}</p>
            ) : (
              <ul className="mt-3 divide-y divide-zinc-200 rounded-xl border border-zinc-200 bg-white px-4 dark:divide-zinc-800 dark:border-zinc-800 dark:bg-zinc-900">
                {dishes.map((dish, index) => (
                  <li key={dish.name + "-" + index} className="flex items-center justify-between gap-4 py-3 text-sm">
                    <span>{dish.name}</span>
                    <span className="shrink-0 text-zinc-600 dark:text-zinc-300">
                      {dish.priceVnd === null ? t("priceMissing") : format.number(dish.priceVnd, { style: "currency", currency: "VND", maximumFractionDigits: 0 })}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <ReviewList restaurantId={restaurant.id} dishes={dishes} />
        </>
      )}
    </main>
  );
}
