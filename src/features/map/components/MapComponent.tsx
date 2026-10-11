"use client";

import React, { useState, useCallback, useMemo, useEffect } from "react";
import Map, { Source, Layer, MapRef, ViewStateChangeEvent, AttributionControl } from "react-map-gl/maplibre";
import { Link } from "@/i18n/navigation";
import type { CircleLayerSpecification, SymbolLayerSpecification } from "react-map-gl/maplibre";
import { GeoJSONSource, getVersion, setWorkerUrl } from "maplibre-gl";
import { useRestaurantsInBounds, RestaurantPin } from "../hooks/useRestaurantsInBounds";
import { useMapView } from "./MapViewContext";
import {
  distanceInMeters,
  hasMovedOutsideLoadedBounds,
  type MapBounds,
  type MapFilters,
} from "../map-utils";
import { useFormatter, useTranslations } from "next-intl";
import { RestaurantSearch } from "@/features/restaurants/components/RestaurantSearch";
import { AddRestaurantFlow } from "@/features/restaurants/components/AddRestaurantFlow";
import type { RestaurantSearchResult } from "@/features/restaurants/types";

if (typeof window !== "undefined") {
  setWorkerUrl(`/maplibre/maplibre-gl-worker.mjs?v=${getVersion()}`);
}

const MAP_STYLE = process.env.NEXT_PUBLIC_MAP_STYLE_URL;

// Tầng cấu hình cho cluster circles
const clusterLayer: CircleLayerSpecification = {
  id: "clusters",
  type: "circle",
  source: "restaurants",
  filter: ["has", "point_count"],
  paint: {
    "circle-color": [
      "step",
      ["get", "point_count"],
      "#51bbd6",
      10,
      "#f1f075",
      30,
      "#f28cb1"
    ],
    "circle-radius": [
      "step",
      ["get", "point_count"],
      20,
      10,
      30,
      30,
      40
    ]
  }
};

const clusterCountLayer: SymbolLayerSpecification = {
  id: "cluster-count",
  type: "symbol",
  source: "restaurants",
  filter: ["has", "point_count"],
  layout: {
    "text-field": "{point_count_abbreviated}",
    "text-font": ["DIN Offc Pro Medium", "Arial Unicode MS Bold"],
    "text-size": 12
  }
};

// Tầng pin lẻ: Đỏ (<4.0), Vàng (4.0-4.5), Xanh (>4.5)
const unclusteredPointLayer: CircleLayerSpecification = {
  id: "unclustered-point",
  type: "circle",
  source: "restaurants",
  filter: ["!", ["has", "point_count"]],
  paint: {
    "circle-color": [
      "case",
      ["<", ["get", "avg_rating"], 4.0],
      "#ef4444",
      ["<", ["get", "avg_rating"], 4.5],
      "#f59e0b",
      "#10b981"
    ],
    "circle-radius": 10,
    "circle-stroke-width": 2,
    "circle-stroke-color": "#fff"
  }
};

export function MapComponent() {
  const t = useTranslations("map");
  const format = useFormatter();
  const { mode, setMode } = useMapView();
  const {
    restaurants,
    dishTypes,
    provinces,
    loadedBounds,
    fetchInBounds,
    loading,
    error,
  } = useRestaurantsInBounds();
  const mapRef = React.useRef<MapRef>(null);

  const [selectedPin, setSelectedPin] = useState<RestaurantPin | null>(null);
  const [mapLoadError, setMapLoadError] = useState(false);
  const [filters, setFilters] = useState<MapFilters>({
    minRating: null,
    maxPrice: null,
    dishType: null,
    province: null,
  });
  const [currentBounds, setCurrentBounds] = useState<MapBounds | null>(null);
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  
  // Dữ liệu GeoJSON
  const geojsonSource = useMemo(() => {
    return {
      type: "FeatureCollection" as const,
      features: restaurants.map(r => ({
        type: "Feature" as const,
        properties: r,
        geometry: {
          type: "Point" as const,
          coordinates: [r.lng, r.lat]
        }
      }))
    };
  }, [restaurants]);

  const readBounds = useCallback((e: ViewStateChangeEvent | undefined): MapBounds | null => {
    const bounds = e?.target.getBounds() ?? mapRef.current?.getBounds();
    if (!bounds) return null;
    const sw = bounds.getSouthWest();
    const ne = bounds.getNorthEast();
    return { minLat: sw.lat, minLng: sw.lng, maxLat: ne.lat, maxLng: ne.lng };
  }, []);

  const onMoveEnd = useCallback((e: ViewStateChangeEvent) => {
    const bounds = readBounds(e);
    if (bounds) setCurrentBounds(bounds);
  }, [readBounds]);

  const onMapLoad = useCallback(() => {
    const bounds = readBounds(undefined);
    if (bounds) {
      setCurrentBounds(bounds);
      fetchInBounds(bounds, filters);
    }
  }, [fetchInBounds, filters, readBounds]);

  const onMapError = useCallback(() => {
    console.error("Map style load failed");
    setMapLoadError(true);
  }, []);

  const updateFilters = useCallback((nextFilters: MapFilters) => {
    setFilters(nextFilters);
    if (currentBounds) fetchInBounds(currentBounds, nextFilters);
  }, [currentBounds, fetchInBounds]);

  const onFindThisArea = useCallback(() => {
    if (currentBounds) fetchInBounds(currentBounds, filters);
  }, [currentBounds, fetchInBounds, filters]);

  const onRetry = useCallback(() => {
    if (currentBounds) fetchInBounds(currentBounds, filters);
  }, [currentBounds, fetchInBounds, filters]);

  useEffect(() => {
    if (mode === "list" && hasMovedOutsideLoadedBounds(currentBounds, loadedBounds) && currentBounds) {
      fetchInBounds(currentBounds, filters);
    }
  }, [currentBounds, fetchInBounds, filters, loadedBounds, mode]);

  const onClick = useCallback(async (event: import("react-map-gl/maplibre").MapLayerMouseEvent) => {
    const feature = event.features?.[0];
    if (!feature) {
      setSelectedPin(null);
      return;
    }
    const clusterId = feature.properties?.cluster_id;
    if (typeof clusterId === "number" && Number.isFinite(clusterId)) {
      const source = mapRef.current?.getSource("restaurants");
      if (!(source instanceof GeoJSONSource)) return;
      try {
        const zoom = await source.getClusterExpansionZoom(clusterId);
        if (feature.geometry.type === "Point") {
          const coords = feature.geometry.coordinates;
          mapRef.current?.easeTo({
            center: [coords[0], coords[1]],
            zoom,
            duration: 500
          });
        }
      } catch {
        // ignore
      }
      return;
    }
    const pin = restaurants.find(restaurant => restaurant.id === feature.properties?.id);
    if (pin) setSelectedPin(pin);
  }, [restaurants]);

  const locateUser = () => {
    if (!navigator.geolocation) {
      alert(t("locationNotSupported"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLocation({ lat: pos.coords.latitude, lng: pos.coords.longitude });
        mapRef.current?.flyTo({
          center: [pos.coords.longitude, pos.coords.latitude],
          zoom: 15
        });
      },
      () => {
        alert(t("locationDenied"));
      }
    );
  };

  const selectRestaurant = useCallback((restaurant: RestaurantPin) => {
    setSelectedPin(restaurant);
    mapRef.current?.flyTo({ center: [restaurant.lng, restaurant.lat], zoom: 15 });
    setMode("map");
  }, [setMode]);

  const selectSearchResult = useCallback((result: RestaurantSearchResult) => {
    mapRef.current?.flyTo({ center: [result.lng, result.lat], zoom: 15, duration: 800 });
    setSelectedPin({
      id: result.id,
      name: result.name,
      lat: result.lat,
      lng: result.lng,
      avg_rating: result.avg_rating,
      review_count: result.review_count,
      status: "active",
      province: null,
      dish_types: [],
    });
    setMode("map");
  }, [setMode]);

  const toggleRatingFilter = () => {
    updateFilters({ ...filters, minRating: filters.minRating === null ? 4 : null });
  };

  if (!MAP_STYLE) {
    return (
      <div className="flex flex-1 items-center justify-center p-4 text-center">
        <div className="rounded-xl border border-yellow-200 bg-yellow-50 p-4 text-sm text-yellow-800">
          {t("missingStyleUrl")}
        </div>
      </div>
    );
  }

  return (
    <div className="relative h-[calc(100dvh-4rem)] w-full">
      <RestaurantSearch onSelect={selectSearchResult} />
      <div className="absolute left-3 right-3 top-[4.25rem] z-20 flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
        <label className="sr-only" htmlFor="map-price-filter">{t("filters.maxPrice")}</label>
        <select
          id="map-price-filter"
          className="min-h-10 shrink-0 rounded-full border border-zinc-200 bg-white px-3 text-sm shadow-md dark:bg-zinc-900"
          value={filters.maxPrice ?? ""}
          onChange={(event) => updateFilters({ ...filters, maxPrice: event.target.value ? Number(event.target.value) : null })}
        >
          <option value="">{t("filters.anyPrice")}</option>
          <option value="50000">{t("filters.underPrice", { amount: format.number(50000) })}</option>
          <option value="100000">{t("filters.underPrice", { amount: format.number(100000) })}</option>
          <option value="200000">{t("filters.underPrice", { amount: format.number(200000) })}</option>
        </select>
        <button
          type="button"
          aria-pressed={filters.minRating !== null}
          onClick={toggleRatingFilter}
          className={`min-h-10 shrink-0 rounded-full px-4 text-sm font-medium shadow-md ${filters.minRating !== null ? "bg-blue-600 text-white" : "bg-white dark:bg-zinc-900"}`}
        >
          ⭐ {t("filters.minRating")}
        </button>
        <label className="sr-only" htmlFor="map-dish-filter">{t("filters.dishType")}</label>
        <select
          id="map-dish-filter"
          className="min-h-10 shrink-0 rounded-full border border-zinc-200 bg-white px-3 text-sm shadow-md dark:bg-zinc-900"
          value={filters.dishType ?? ""}
          onChange={(event) => updateFilters({ ...filters, dishType: event.target.value || null })}
        >
          <option value="">{t("filters.dishType")}</option>
          {dishTypes.map((dishType) => <option key={dishType} value={dishType}>{dishType}</option>)}
        </select>
        <label className="sr-only" htmlFor="map-province-filter">{t("filters.province")}</label>
        <select
          id="map-province-filter"
          className="min-h-10 shrink-0 rounded-full border border-zinc-200 bg-white px-3 text-sm shadow-md dark:bg-zinc-900"
          value={filters.province ?? ""}
          onChange={(event) => updateFilters({ ...filters, province: event.target.value || null })}
        >
          <option value="">{t("filters.province")}</option>
          {provinces.map((province) => <option key={province} value={province}>{province}</option>)}
        </select>
        <button
          type="button"
          onClick={() => setAddOpen(true)}
          className="min-h-10 shrink-0 rounded-full bg-blue-600 px-4 text-sm font-semibold text-white shadow-md"
        >
          + {t("addRestaurant")}
        </button>
      </div>

      {addOpen && <AddRestaurantFlow onClose={() => setAddOpen(false)} />}

      <Map
        ref={mapRef}
        initialViewState={{ longitude: 106.68, latitude: 10.78, zoom: 12 }}
        onLoad={onMapLoad}
        onMoveEnd={onMoveEnd}
        mapStyle={MAP_STYLE}
        interactiveLayerIds={["clusters", "unclustered-point"]}
        onClick={onClick}
        onError={onMapError}
        style={{ width: "100%", height: "100%" }}
      >
        <Source
          id="restaurants"
          type="geojson"
          data={geojsonSource}
          cluster={true}
          clusterMaxZoom={14}
          clusterRadius={50}
        >
          <Layer {...clusterLayer} />
          <Layer {...clusterCountLayer} />
          <Layer {...unclusteredPointLayer} />
        </Source>
        <AttributionControl position="bottom-right" />
      </Map>

      {mapLoadError && (
        <div
          role="alert"
          className="absolute left-4 right-4 top-1/2 z-30 -translate-y-1/2 rounded-xl border border-red-200 bg-white p-4 text-center text-sm text-red-800 shadow-lg"
        >
          {t("styleLoadError")}
        </div>
      )}

      {hasMovedOutsideLoadedBounds(currentBounds, loadedBounds) && !loading && (
        <button
          type="button"
          onClick={onFindThisArea}
          className="absolute left-1/2 top-16 z-30 -translate-x-1/2 rounded-full bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-lg"
        >
          {t("findThisArea")}
        </button>
      )}

      {mode === "list" && (
        <section
          aria-label={t("listTitle")}
          className="absolute inset-x-0 bottom-0 top-14 z-10 overflow-y-auto bg-white/95 px-3 pb-5 pt-2 backdrop-blur-sm dark:bg-zinc-950/95"
        >
          <h2 className="sr-only">{t("listTitle")}</h2>
          {loading && <p role="status" className="p-4 text-center text-sm">{t("loading")}</p>}
          {error && (
            <div role="alert" className="m-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
              <p>{t("loadError")}</p>
              <button type="button" onClick={onRetry} className="mt-2 font-semibold underline">{t("retry")}</button>
            </div>
          )}
          {!loading && !error && restaurants.length === 0 && (
            <p className="p-6 text-center text-sm text-zinc-600">{t("emptyList")}</p>
          )}
          <ul className="space-y-2">
            {restaurants.map((restaurant) => {
              const distance = userLocation ? distanceInMeters(userLocation, restaurant) : null;
              return (
                <li key={restaurant.id}>
                  <button
                    type="button"
                    onClick={() => selectRestaurant(restaurant)}
                    className="w-full rounded-xl border border-zinc-200 bg-white p-4 text-left shadow-sm dark:border-zinc-800 dark:bg-zinc-900"
                  >
                    <span className="block font-semibold">{restaurant.name}</span>
                    <span className="mt-1 block text-sm text-zinc-600 dark:text-zinc-300">
                      {restaurant.dish_types.length ? restaurant.dish_types.join(" · ") : t("noDishTypes")}
                    </span>
                    <span className="mt-1 block text-sm text-zinc-600 dark:text-zinc-300">
                      ⭐ {restaurant.avg_rating.toFixed(1)} · {restaurant.review_count} {t("reviews")}
                      {distance !== null && ` · ${distance < 1000 ? t("distanceMeters", { distance: Math.round(distance) }) : t("distanceKilometers", { distance: (distance / 1000).toFixed(1) })}`}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {/* Nút vị trí */}
      <button
        onClick={locateUser}
        className="absolute bottom-6 right-4 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-white shadow-lg text-zinc-700"
        aria-label={t("myLocation")}
      >
        📍
      </button>

      {loading && (
        <div className="absolute top-4 right-4 z-10 rounded-full bg-white p-2 shadow-md">
          <div className="h-4 w-4 animate-spin rounded-full border-2 border-zinc-900 border-t-transparent" />
        </div>
      )}

      {/* Thẻ tóm tắt kéo lên từ dưới */}
      {selectedPin && (
        <div className="absolute bottom-0 left-0 right-0 z-20 rounded-t-2xl bg-white p-4 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.1)] transition-transform dark:bg-zinc-900">
          <div className="mb-2 flex items-start justify-between">
            <div>
              <h3 className="text-lg font-bold text-zinc-900 dark:text-white">
                {selectedPin.name}
              </h3>
              <p className="text-sm text-zinc-500">
                ⭐ {selectedPin.avg_rating} ({selectedPin.review_count} {t("reviews")})
              </p>
              {selectedPin.dish_types.length > 0 && (
                <p className="mt-1 text-sm text-zinc-500">{selectedPin.dish_types.join(" · ")}</p>
              )}
              {userLocation && (
                <p className="mt-1 text-sm text-zinc-500">
                  {t("distanceMeters", { distance: Math.round(distanceInMeters(userLocation, selectedPin)) })}
                </p>
              )}
              <Link href={"/restaurants/" + selectedPin.id} className="mt-3 inline-flex min-h-10 items-center rounded-lg bg-blue-600 px-4 text-sm font-semibold text-white">
                {t("viewDetails")}
              </Link>
            </div>
            <button
              onClick={() => setSelectedPin(null)}
              className="text-zinc-400 hover:text-zinc-600"
            >
              ✕
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
