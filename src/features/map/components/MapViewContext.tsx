"use client";

import { createContext, useContext, useMemo, useState } from "react";

export type MapViewMode = "map" | "list";

type MapViewContextValue = {
  mode: MapViewMode;
  setMode: (mode: MapViewMode) => void;
};

const MapViewContext = createContext<MapViewContextValue | null>(null);

export function MapViewProvider({ children }: { children: React.ReactNode }) {
  const [mode, setMode] = useState<MapViewMode>("map");
  const value = useMemo(() => ({ mode, setMode }), [mode]);

  return <MapViewContext.Provider value={value}>{children}</MapViewContext.Provider>;
}

export function useMapView() {
  const context = useContext(MapViewContext);
  if (!context) throw new Error("useMapView must be used inside MapViewProvider");
  return context;
}
