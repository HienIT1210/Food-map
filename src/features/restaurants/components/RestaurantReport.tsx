"use client";

import { useCallback, useState } from "react";
import { useTranslations } from "next-intl";
import { useAuth } from "@/features/auth/hooks/useAuth";
import { reportRestaurant, RestaurantWriteError } from "../repository";
import { restaurantReportReasonSchema, type RestaurantReportReason } from "../types";

const REASONS: RestaurantReportReason[] = ["closed", "wrong_location", "wrong_info"];

export function RestaurantReport({ restaurantId }: { restaurantId: string }) {
  const t = useTranslations("restaurant.report");
  const { requireAuth } = useAuth();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState<RestaurantReportReason | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const send = useCallback(async (selected: RestaurantReportReason) => {
    setBusy(true);
    setError(null);
    try {
      await reportRestaurant(restaurantId, selected);
      setDone(true);
    } catch (caught: unknown) {
      if (caught instanceof RestaurantWriteError) {
        // 23505 is the reports unique key: this account already reported this restaurant.
        if (caught.code === "23505") setDone(true);
        else if (caught.code === "42501") setError(t("errors.notAllowed"));
        else setError(t("errors.save"));
      } else {
        setError(t("errors.save"));
      }
    } finally {
      setBusy(false);
    }
  }, [restaurantId, t]);

  const submit = useCallback(async () => {
    if (!reason || !restaurantReportReasonSchema.safeParse(reason).success) {
      setError(t("errors.reasonRequired"));
      return;
    }
    // AUTH-02: the sign-in prompt appears here, when the user actually sends the report.
    await requireAuth(async () => {
      await send(reason);
    });
  }, [reason, requireAuth, send, t]);

  return (
    <section aria-labelledby="report-title" className="mt-6 rounded-2xl border border-zinc-200 bg-white p-5 dark:border-zinc-800 dark:bg-zinc-900">
      <h2 id="report-title" className="text-base font-bold">{t("title")}</h2>
      <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-300">{t("description")}</p>

      {done && <p role="status" className="mt-3 rounded-xl bg-emerald-50 p-3 text-sm text-emerald-800 dark:bg-emerald-950/40">{t("done")}</p>}

      {!done && !open && (
        <button
          type="button"
          onClick={() => { setOpen(true); setError(null); }}
          className="mt-3 min-h-11 rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700"
        >
          {t("open")}
        </button>
      )}

      {!done && open && (
        <div className="mt-3 space-y-3">
          <fieldset className="space-y-2">
            <legend className="text-sm font-semibold">{t("reasonLabel")}</legend>
            {REASONS.map((value) => (
              <label key={value} className="flex min-h-10 items-center gap-2 text-sm">
                <input
                  type="radio"
                  name="report-reason"
                  value={value}
                  checked={reason === value}
                  onChange={() => setReason(value)}
                />
                {t(`reasons.${value}`)}
              </label>
            ))}
          </fieldset>
          {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
          <div className="flex gap-2">
            <button type="button" onClick={() => setOpen(false)} className="min-h-11 rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700">
              {t("cancel")}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => void submit()}
              className="min-h-11 flex-1 rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white disabled:opacity-60"
            >
              {busy ? t("sending") : t("send")}
            </button>
          </div>
        </div>
      )}
    </section>
  );
}
