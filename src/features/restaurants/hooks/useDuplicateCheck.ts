"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { checkDuplicateRestaurant } from "../repository";
import type { DuplicateRestaurant } from "../types";

const DEBOUNCE_MS = 350;

/**
 * Debounced RES-03 lookup. Keeps its own AbortController so a newer keystroke cancels the request
 * that is still in flight, and never runs while the name is empty.
 */
export function useDuplicateCheck() {
  const [suggestions, setSuggestions] = useState<DuplicateRestaurant[]>([]);
  const [checking, setChecking] = useState(false);
  const [error, setError] = useState(false);
  const [checked, setChecked] = useState(false);
  const controllerRef = useRef<AbortController | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cancel = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    controllerRef.current?.abort();
  }, []);

  useEffect(() => cancel, [cancel]);

  const run = useCallback(async (name: string, lat: number, lng: number) => {
    cancel();
    const trimmed = name.trim();
    if (trimmed.length === 0) {
      setSuggestions([]);
      setChecked(false);
      setChecking(false);
      setError(false);
      return;
    }
    setChecking(true);
    setError(false);
    const controller = new AbortController();
    controllerRef.current = controller;
    try {
      const rows = await checkDuplicateRestaurant(trimmed, lat, lng, controller.signal);
      if (controller.signal.aborted) return;
      setSuggestions(rows);
    } catch {
      if (!controller.signal.aborted) {
        setSuggestions([]);
        setError(true);
      }
    } finally {
      if (!controller.signal.aborted) {
        setChecking(false);
        setChecked(true);
      }
    }
  }, [cancel]);

  const schedule = useCallback((name: string, lat: number, lng: number) => {
    cancel();
    timerRef.current = setTimeout(() => {
      void run(name, lat, lng);
    }, DEBOUNCE_MS);
  }, [cancel, run]);

  const reset = useCallback(() => {
    cancel();
    setSuggestions([]);
    setChecking(false);
    setError(false);
    setChecked(false);
  }, [cancel]);

  return { suggestions, checking, error, checked, schedule, run, reset, cancel };
}
