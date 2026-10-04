import { routing, type AppLocale } from "@/i18n/routing";

export function isAppLocale(value: string): value is AppLocale {
  return routing.locales.includes(value as AppLocale);
}
