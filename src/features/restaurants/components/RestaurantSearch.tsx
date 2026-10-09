"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useRestaurantSearch } from "../hooks/useRestaurantSearch";
import type { RestaurantSearchResult } from "../types";

type RestaurantSearchProps = {
  onSelect: (result: RestaurantSearchResult) => void;
};

export function RestaurantSearch({ onSelect }: RestaurantSearchProps) {
  const t = useTranslations("search");
  const [query, setQuery] = useState("");
  const [retryVersion, setRetryVersion] = useState(0);
  const [isOpen, setIsOpen] = useState(false);
  const { results, loading, error } = useRestaurantSearch(query, retryVersion);
  const hasQuery = query.trim().length >= 2;

  return (
    <div className="absolute left-3 right-3 top-3 z-30 mx-auto max-w-xl">
      <label className="sr-only" htmlFor="restaurant-search">{t("label")}</label>
      <input
        id="restaurant-search"
        type="search"
        autoComplete="off"
        value={query}
        onFocus={() => setIsOpen(true)}
        onChange={(event) => {
          setQuery(event.target.value);
          setIsOpen(true);
        }}
        onKeyDown={(event) => {
          if (event.key === "Escape") setIsOpen(false);
        }}
        placeholder={t("placeholder")}
        className="min-h-12 w-full rounded-xl border border-zinc-200 bg-white/95 px-4 text-base shadow-lg outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:border-zinc-700 dark:bg-zinc-900/95"
      />
      {isOpen && hasQuery && (
        <div className="mt-2 max-h-[45dvh] overflow-y-auto rounded-xl border border-zinc-200 bg-white shadow-xl dark:border-zinc-700 dark:bg-zinc-900">
          {loading && <p role="status" className="p-4 text-sm text-zinc-600">{t("loading")}</p>}
          {error && (
            <div role="alert" className="p-4 text-sm">
              <p>{t("error")}</p>
              <button type="button" className="mt-2 font-semibold underline" onClick={() => setRetryVersion((value) => value + 1)}>{t("retry")}</button>
            </div>
          )}
          {!loading && !error && results.length === 0 && <p className="p-4 text-sm text-zinc-600">{t("empty")}</p>}
          {!loading && !error && results.length > 0 && (
            <ul>
              {results.map((result) => (
                <li key={result.id} className="border-b border-zinc-100 last:border-0 dark:border-zinc-800">
                  <button
                    type="button"
                    className="w-full px-4 py-3 text-left hover:bg-zinc-50 focus:bg-zinc-50 dark:hover:bg-zinc-800 dark:focus:bg-zinc-800"
                    onClick={() => {
                      onSelect(result);
                      setQuery("");
                      setIsOpen(false);
                    }}
                  >
                    <span className="block font-semibold">{result.name}</span>
                    <span className="mt-1 block truncate text-sm text-zinc-600 dark:text-zinc-300">{result.address || t("noAddress")}</span>
                    <span className="mt-1 block text-xs text-zinc-500">★ {result.avg_rating.toFixed(1)} · {result.review_count}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      {isOpen && !hasQuery && query.length > 0 && <p className="mt-2 rounded-lg bg-white p-3 text-sm shadow dark:bg-zinc-900">{t("minimumQuery")}</p>}
    </div>
  );
}
