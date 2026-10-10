"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Map, { type MapRef, type ViewStateChangeEvent } from "react-map-gl/maplibre";
import { useForm } from "react-hook-form";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { useAuth } from "@/features/auth/hooks/useAuth";
import { createRestaurant, RestaurantWriteError, RESTAURANT_ERROR_HINTS } from "../repository";
import { createRestaurantInputSchema, type CreateRestaurantInput } from "../types";
import { useDuplicateCheck } from "../hooks/useDuplicateCheck";

const MAP_STYLE = process.env.NEXT_PUBLIC_MAP_STYLE_URL;

type FormValues = { name: string; address: string; province: string };
type Step = "pin" | "form" | "duplicate";

export function AddRestaurantFlow({ onClose }: { onClose: () => void }) {
  const t = useTranslations("addRestaurant");
  const { user, setShowLoginModal } = useAuth();
  const mapRef = useRef<MapRef | null>(null);
  const { suggestions, checking, error: checkError, schedule, reset } = useDuplicateCheck();

  const [step, setStep] = useState<Step>("pin");
  const [pin, setPin] = useState<{ lat: number; lng: number } | null>(null);
  const [busy, setBusy] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [createdId, setCreatedId] = useState<string | null>(null);

  const { register, handleSubmit, watch, getValues, formState } = useForm<FormValues>({
    defaultValues: { name: "", address: "", province: "" },
  });
  // react-hook-form exposes watch() as a non-memoizable function; the React Compiler therefore
  // skips memoizing this component. That is deliberate: the debounced duplicate check needs the
  // live name value, and the lint rule cannot be satisfied without dropping the debounce.
  // eslint-disable-next-line react-hooks/incompatible-library
  const nameValue = watch("name");

  // Debounced RES-03 check while the user types; the same rule is re-checked inside create_restaurant.
  useEffect(() => {
    if (step !== "form" || !pin) return;
    schedule(nameValue, pin.lat, pin.lng);
  }, [nameValue, pin, schedule, step]);

  const readCenter = useCallback((event?: ViewStateChangeEvent) => {
    const map = event?.target ?? mapRef.current;
    if (!map) return;
    const center = map.getCenter();
    setPin({ lat: center.lat, lng: center.lng });
  }, []);

  const buildInput = useCallback((confirmNew: boolean): CreateRestaurantInput | null => {
    if (!pin) {
      setSubmitError(t("errors.missingPin"));
      return null;
    }
    const parsed = createRestaurantInputSchema.safeParse({
      ...getValues(),
      lat: pin.lat,
      lng: pin.lng,
      dishes: [],
      confirmNew,
    });
    if (!parsed.success) {
      setSubmitError(t("errors.invalidInput"));
      return null;
    }
    return parsed.data;
  }, [getValues, pin, t]);

  const send = useCallback(async (input: CreateRestaurantInput) => {
    if (!user) {
      // AUTH-02: ask for sign-in only at the moment of writing; the filled form stays on screen.
      setShowLoginModal(true);
      return;
    }
    setBusy(true);
    setSubmitError(null);
    try {
      setCreatedId(await createRestaurant(input));
    } catch (caught: unknown) {
      if (caught instanceof RestaurantWriteError) {
        // Only the stable hint is matched; the message text is server-owned and may be reworded.
        if (caught.hint === RESTAURANT_ERROR_HINTS.duplicate) {
          setStep("duplicate");
          setSubmitError(t("errors.duplicate"));
        } else if (caught.hint === RESTAURANT_ERROR_HINTS.dailyLimit) {
          setSubmitError(t("errors.quota"));
        } else {
          setSubmitError(t("errors.save"));
        }
      } else {
        setSubmitError(t("errors.save"));
      }
    } finally {
      setBusy(false);
    }
  }, [setShowLoginModal, t, user]);

  const onSubmit = handleSubmit(async () => {
    const input = buildInput(false);
    if (!input) return;
    if (suggestions.length > 0) {
      setStep("duplicate");
      return;
    }
    await send(input);
  });

  const confirmDifferent = useCallback(async () => {
    const input = buildInput(true);
    if (!input) return;
    await send(input);
  }, [buildInput, send]);

  if (!MAP_STYLE) {
    return (
      <div className="fixed inset-0 z-40 flex items-center justify-center bg-white p-4 dark:bg-zinc-950">
        <div className="rounded-xl border border-yellow-200 bg-yellow-50 p-4 text-sm text-yellow-800">
          {t("missingStyleUrl")}
          <button type="button" onClick={onClose} className="mt-3 block font-semibold underline">{t("cancel")}</button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-40 flex flex-col bg-white dark:bg-zinc-950">
      <header className="flex items-center justify-between border-b border-zinc-200 px-4 py-3 dark:border-zinc-800">
        <h1 className="text-lg font-bold">
          {step === "pin" && t("pinTitle")}
          {step === "form" && t("formTitle")}
          {step === "duplicate" && t("duplicateTitle")}
        </h1>
        <button type="button" onClick={onClose} aria-label={t("close")} className="min-h-10 px-2 text-xl">✕</button>
      </header>

      {createdId && (
        <div className="flex flex-1 flex-col items-center justify-center gap-4 p-6 text-center">
          <p role="status" className="text-base font-semibold text-emerald-700">{t("created")}</p>
          <Link href={`/restaurants/${createdId}`} className="min-h-11 rounded-xl bg-blue-600 px-5 py-3 text-sm font-semibold text-white">
            {t("viewCreated")}
          </Link>
          <button type="button" onClick={onClose} className="min-h-11 text-sm font-semibold underline">{t("backToMap")}</button>
        </div>
      )}

      {!createdId && step === "pin" && (
        <div className="relative flex-1">
          <Map
            ref={mapRef}
            initialViewState={{ longitude: 106.68, latitude: 10.78, zoom: 14 }}
            mapStyle={MAP_STYLE}
            onLoad={() => readCenter()}
            onMoveEnd={readCenter}
            style={{ width: "100%", height: "100%" }}
          />
          {/* The pin is fixed at the centre; the user drags the map underneath it (no geolocation prompt). */}
          <div className="pointer-events-none absolute left-1/2 top-1/2 z-10 -translate-x-1/2 -translate-y-full text-3xl" aria-hidden="true">📍</div>
          <div className="pointer-events-none absolute inset-x-0 top-3 z-10 text-center">
            <p className="inline-block rounded-full bg-white/95 px-3 py-1 text-sm font-medium shadow dark:bg-zinc-900/95">{t("pinHint")}</p>
          </div>
          {pin && (
            <p className="pointer-events-none absolute inset-x-0 bottom-28 z-10 text-center text-xs text-zinc-600 dark:text-zinc-300">
              {t("pinCoordinates", { lat: pin.lat.toFixed(5), lng: pin.lng.toFixed(5) })}
            </p>
          )}
          <button
            type="button"
            onClick={() => { readCenter(); setSubmitError(null); setStep("form"); }}
            className="absolute inset-x-4 bottom-6 z-10 min-h-12 rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white"
          >
            {t("placeHere")}
          </button>
        </div>
      )}

      {!createdId && step === "form" && (
        <form onSubmit={onSubmit} className="flex-1 space-y-4 overflow-y-auto p-4">
          {pin && (
            <p className="rounded-xl bg-zinc-100 p-3 text-sm dark:bg-zinc-900">
              {t("pinCoordinates", { lat: pin.lat.toFixed(5), lng: pin.lng.toFixed(5) })}
            </p>
          )}
          <div>
            <label htmlFor="restaurant-name" className="block text-sm font-semibold">{t("fields.name")}</label>
            <input
              id="restaurant-name"
              {...register("name", { required: true, maxLength: 120 })}
              className="mt-1 min-h-11 w-full rounded-xl border border-zinc-300 px-3 dark:border-zinc-700 dark:bg-zinc-900"
            />
            {formState.errors.name && <p role="alert" className="mt-1 text-sm text-red-700">{t("errors.nameRequired")}</p>}
          </div>
          <div>
            <label htmlFor="restaurant-address" className="block text-sm font-semibold">{t("fields.address")}</label>
            <input
              id="restaurant-address"
              {...register("address", { maxLength: 300 })}
              className="mt-1 min-h-11 w-full rounded-xl border border-zinc-300 px-3 dark:border-zinc-700 dark:bg-zinc-900"
            />
          </div>
          <div>
            <label htmlFor="restaurant-province" className="block text-sm font-semibold">{t("fields.province")}</label>
            <input
              id="restaurant-province"
              {...register("province", { maxLength: 120 })}
              className="mt-1 min-h-11 w-full rounded-xl border border-zinc-300 px-3 dark:border-zinc-700 dark:bg-zinc-900"
            />
          </div>
          <p className="text-xs text-zinc-500">{t("dishLater")}</p>

          <div aria-live="polite" className="rounded-xl border border-zinc-200 p-3 text-sm dark:border-zinc-800">
            {checking && <p role="status">{t("checking")}</p>}
            {!checking && checkError && <p className="text-amber-700">{t("checkFailed")}</p>}
            {!checking && !checkError && suggestions.length === 0 && <p className="text-zinc-600">{t("noSimilar")}</p>}
            {!checking && suggestions.length > 0 && <p className="font-semibold text-amber-800">{t("similarFound", { count: suggestions.length })}</p>}
          </div>

          {submitError && <p role="alert" className="text-sm text-red-700">{submitError}</p>}
          <div className="flex gap-2">
            <button type="button" onClick={() => setStep("pin")} className="min-h-11 rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700">
              {t("back")}
            </button>
            <button type="submit" disabled={busy} className="min-h-11 flex-1 rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white disabled:opacity-60">
              {busy ? t("saving") : t("submit")}
            </button>
          </div>
        </form>
      )}

      {!createdId && step === "duplicate" && (
        <div className="flex-1 space-y-4 overflow-y-auto p-4">
          <p className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950/40">{t("duplicateNotice")}</p>
          {checking && <p role="status" className="text-sm">{t("checking")}</p>}
          {suggestions.length === 0 && !checking && <p className="text-sm text-zinc-600">{t("noSimilar")}</p>}
          <ul className="space-y-2">
            {suggestions.map((item) => (
              <li key={item.id} className="rounded-xl border border-zinc-200 p-4 dark:border-zinc-800">
                <p className="font-semibold">{item.name}</p>
                <p className="text-sm text-zinc-600 dark:text-zinc-300">{item.address || t("noAddress")}</p>
                <p className="text-sm text-zinc-500">{t("distanceMeters", { distance: Math.round(item.distance_meters) })}</p>
                <Link href={`/restaurants/${item.id}`} className="mt-2 inline-flex min-h-10 items-center text-sm font-semibold text-blue-700 underline dark:text-blue-300">
                  {t("viewThis")}
                </Link>
              </li>
            ))}
          </ul>
          {submitError && <p role="alert" className="text-sm text-red-700">{submitError}</p>}
          <div className="flex flex-col gap-2">
            <button type="button" disabled={busy} onClick={() => void confirmDifferent()} className="min-h-11 rounded-xl bg-blue-600 px-4 text-sm font-semibold text-white disabled:opacity-60">
              {busy ? t("saving") : t("confirmDifferent")}
            </button>
            <button type="button" onClick={() => { reset(); setSubmitError(null); setStep("form"); }} className="min-h-11 rounded-xl border border-zinc-300 px-4 text-sm font-semibold dark:border-zinc-700">
              {t("back")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
