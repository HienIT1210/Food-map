import { describe, expect, it } from "vitest";
import { isAppLocale } from "./locale";

describe("isAppLocale", () => {
  it("accepts Vietnamese and English", () => {
    expect(isAppLocale("vi")).toBe(true);
    expect(isAppLocale("en")).toBe(true);
  });

  it("rejects unsupported locales", () => {
    expect(isAppLocale("fr")).toBe(false);
    expect(isAppLocale("")).toBe(false);
  });
});
