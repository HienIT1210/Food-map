"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { usePathname, useRouter } from "@/i18n/navigation";
import { useMapView, type MapViewMode } from "@/features/map/components/MapViewContext";

export function BottomNav() {
  const pathname = usePathname();
  const router = useRouter();
  const t = useTranslations("nav");
  const { mode, setMode } = useMapView();
  const isProfile = pathname.includes("/profile");

  const selectView = (nextMode: MapViewMode) => {
    setMode(nextMode);
    if (isProfile) router.push("/");
  };

  const viewButtonClass = (active: boolean) =>
    `flex min-w-0 flex-col items-center gap-1 p-2 ${active ? "text-blue-600" : "text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100"}`;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex h-16 items-center justify-around border-t border-zinc-200 bg-white/90 pb-safe backdrop-blur-sm dark:border-zinc-800 dark:bg-zinc-900/90">
      <button
        type="button"
        aria-pressed={mode === "map" && !isProfile}
        className={viewButtonClass(mode === "map" && !isProfile)}
        onClick={() => selectView("map")}
      >
        <span className="text-xl" aria-hidden="true">🗺️</span>
        <span className="text-[10px] font-medium">{t("map")}</span>
      </button>
      <button
        type="button"
        aria-pressed={mode === "list" && !isProfile}
        className={viewButtonClass(mode === "list" && !isProfile)}
        onClick={() => selectView("list")}
      >
        <span className="text-xl" aria-hidden="true">☷</span>
        <span className="text-[10px] font-medium">{t("list")}</span>
      </button>
      <Link href="/" className={viewButtonClass(false)}>
        <span className="text-xl" aria-hidden="true">🔖</span>
        <span className="text-[10px] font-medium">{t("saved")}</span>
      </Link>
      <Link
        href="/profile"
        aria-current={isProfile ? "page" : undefined}
        className={viewButtonClass(isProfile)}
      >
        <span className="text-xl" aria-hidden="true">👤</span>
        <span className="text-[10px] font-medium">{t("profile")}</span>
      </Link>
    </nav>
  );
}
