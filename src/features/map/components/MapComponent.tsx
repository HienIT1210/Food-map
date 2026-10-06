"use client";

import React, { useState, useCallback, useMemo } from "react";
import Map, { Source, Layer, MapRef, ViewStateChangeEvent } from "react-map-gl/maplibre";
import type { CircleLayer, SymbolLayer } from "react-map-gl/maplibre";
import { useRestaurantsInBounds, RestaurantPin } from "../hooks/useRestaurantsInBounds";
import { useTranslations } from "next-intl";

const MAP_STYLE = process.env.NEXT_PUBLIC_MAP_STYLE_URL;

// Tầng cấu hình cho cluster circles
const clusterLayer: CircleLayer = {
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

const clusterCountLayer: SymbolLayer = {
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
const unclusteredPointLayer: CircleLayer = {
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
  const { restaurants, fetchInBounds, loading } = useRestaurantsInBounds();
  const mapRef = React.useRef<MapRef>(null);

  const [selectedPin, setSelectedPin] = useState<RestaurantPin | null>(null);
  const [viewState, setViewState] = useState({
    longitude: 106.68,
    latitude: 10.78,
    zoom: 12
  });
  
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

  const onMoveEnd = useCallback((e: ViewStateChangeEvent) => {
    const bounds = e.target.getBounds();
    if (bounds) {
      const sw = bounds.getSouthWest();
      const ne = bounds.getNorthEast();
      fetchInBounds(sw.lat, sw.lng, ne.lat, ne.lng);
    }
  }, [fetchInBounds]);

  const onClick = useCallback((event: import("react-map-gl/maplibre").MapLayerMouseEvent) => {
    const feature = event.features?.[0];
    if (!feature) {
      setSelectedPin(null);
      return;
    }
    const clusterId = feature.properties?.cluster_id;
    if (clusterId) {
      const source = mapRef.current?.getSource("restaurants") as import("maplibre-gl").GeoJSONSource;
      source.getClusterExpansionZoom(clusterId, (err: Error | null | undefined, zoom: number) => {
        if (err) return;
        const coords = feature.geometry.coordinates;
        mapRef.current?.easeTo({
          center: [coords[0], coords[1]],
          zoom,
          duration: 500
        });
      });
      return;
    }
    if (feature.properties) {
      setSelectedPin(feature.properties as RestaurantPin);
    }
  }, []);

  const locateUser = () => {
    if (!navigator.geolocation) {
      alert(t("locationNotSupported"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
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
    <div className="relative h-[calc(100vh-4rem)] w-full">
      {/* Bộ lọc dạng chip (Demo tĩnh) */}
      <div className="absolute top-4 left-4 right-16 z-10 flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
        <button className="whitespace-nowrap rounded-full bg-white px-4 py-1.5 text-sm font-medium shadow-md">
          ⭐ 4.0+
        </button>
        <button className="whitespace-nowrap rounded-full bg-white px-4 py-1.5 text-sm font-medium shadow-md">
          {t("filters.openNow")}
        </button>
        <button className="whitespace-nowrap rounded-full bg-white px-4 py-1.5 text-sm font-medium shadow-md">
          {t("filters.dishType")}
        </button>
      </div>

      <Map
        ref={mapRef}
        {...viewState}
        onMove={evt => setViewState(evt.viewState)}
        onMoveEnd={onMoveEnd}
        mapStyle={MAP_STYLE}
        interactiveLayerIds={["clusters", "unclustered-point"]}
        onClick={onClick}
        attributionControl={true}
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
      </Map>

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
            </div>
            <button
              onClick={() => setSelectedPin(null)}
              className="text-zinc-400 hover:text-zinc-600"
            >
              ✕
            </button>
          </div>
          <button className="mt-4 w-full rounded-xl bg-blue-600 py-3 text-sm font-semibold text-white hover:bg-blue-700">
            {t("viewDetails")}
          </button>
        </div>
      )}
    </div>
  );
}
