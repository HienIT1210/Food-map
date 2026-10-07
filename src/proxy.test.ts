import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { unstable_doesMiddlewareMatch } from "next/experimental/testing/server";
import { describe, expect, it } from "vitest";

const proxySource = await readFile(resolve(process.cwd(), "src/proxy.ts"), "utf8");
const matcher = proxySource.match(/matcher:\s*"([^"]+)"/)?.[1];
if (!matcher) throw new Error("Could not find the proxy matcher string");
const config = { matcher };

describe("next-intl proxy matcher", () => {
  it("does not intercept MapLibre worker assets", () => {
    for (const url of [
      "/maplibre/maplibre-gl-worker.mjs",
      "/maplibre/maplibre-gl-shared.mjs",
      "/maplibre/health",
    ]) {
      expect(unstable_doesMiddlewareMatch({ config, url })).toBe(false);
    }
  });

  it("continues to run for localized app pages", () => {
    expect(unstable_doesMiddlewareMatch({ config, url: "/vi" })).toBe(true);
  });
});