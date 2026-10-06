"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";

export function BottomNav() {
  const pathname = usePathname();
  const t = useTranslations("nav");

  // Xử lý đơn giản cho MVP: kiểm tra path chứa "profile" v.v.
  // /vi/profile, /en/profile
  const isProfile = pathname.includes("/profile");
  
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex h-16 items-center justify-around border-t border-zinc-200 bg-white/90 backdrop-blur-sm pb-safe dark:border-zinc-800 dark:bg-zinc-900/90">
      <Link href="/" className={`flex flex-col items-center gap-1 p-2 ${!isProfile ? "text-blue-600" : "text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100"}`}>
        <span className="text-xl">🗺️</span>
        <span className="text-[10px] font-medium">{t("map")}</span>
      </Link>
      <Link href="/" className="flex flex-col items-center gap-1 p-2 text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100">
        <span className="text-xl">📋</span>
        <span className="text-[10px] font-medium">{t("list")}</span>
      </Link>
      <Link href="/" className="flex flex-col items-center gap-1 p-2 text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100">
        <span className="text-xl">🔖</span>
        <span className="text-[10px] font-medium">{t("saved")}</span>
      </Link>
      <Link href="/profile" className={`flex flex-col items-center gap-1 p-2 ${isProfile ? "text-blue-600" : "text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-100"}`}>
        <span className="text-xl">👤</span>
        <span className="text-[10px] font-medium">{t("profile")}</span>
      </Link>
    </nav>
  );
}
