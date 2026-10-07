export type MapBounds = {
  minLat: number;
  minLng: number;
  maxLat: number;
  maxLng: number;
};

export type MapFilters = {
  minRating: number | null;
  maxPrice: number | null;
  dishType: string | null;
  province: string | null;
};

export type RestaurantRpcFilters = Record<string, number | string>;

export function buildRestaurantRpcFilters(filters: MapFilters): RestaurantRpcFilters {
  return {
    ...(filters.minRating === null ? {} : { min_rating: filters.minRating }),
    ...(filters.maxPrice === null ? {} : { max_price: filters.maxPrice }),
    ...(filters.dishType === null ? {} : { dish_type: filters.dishType }),
    ...(filters.province === null ? {} : { province: filters.province }),
  };
}

export function hasMovedOutsideLoadedBounds(
  current: MapBounds | null,
  loaded: MapBounds | null,
): boolean {
  if (!current || !loaded) return false;

  const latitudeMargin = (loaded.maxLat - loaded.minLat) * 0.15;
  const longitudeMargin = (loaded.maxLng - loaded.minLng) * 0.15;

  return (
    current.minLat < loaded.minLat - latitudeMargin ||
    current.maxLat > loaded.maxLat + latitudeMargin ||
    current.minLng < loaded.minLng - longitudeMargin ||
    current.maxLng > loaded.maxLng + longitudeMargin
  );
}

export function distanceInMeters(
  from: { lat: number; lng: number },
  to: { lat: number; lng: number },
): number {
  const earthRadiusMeters = 6_371_000;
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const latitudeDelta = toRadians(to.lat - from.lat);
  const longitudeDelta = toRadians(to.lng - from.lng);
  const fromLatitude = toRadians(from.lat);
  const toLatitude = toRadians(to.lat);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(fromLatitude) *
      Math.cos(toLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;

  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(haversine));
}
