import { afterEach, describe, expect, it, vi } from "vitest";
import { hasExifMetadata, prepareReviewPhoto } from "./image-processing";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("review photo privacy processing", () => {
  it("re-encodes a GPS EXIF input into an output without EXIF segments", async () => {
    const gpsExifJpeg = new Uint8Array([
      0xff, 0xd8, 0xff, 0xe1, 0x00, 0x10,
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x47, 0x50, 0x53, 0x00, 0x00, 0x00,
      0xff, 0xda, 0x00, 0x02,
    ]);
    const cleanEncodedJpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xda, 0x00, 0x02]);
    const drawImage = vi.fn();
    const toBlob = vi.fn((callback: BlobCallback) => callback(new Blob([cleanEncodedJpeg], { type: "image/jpeg" })));
    const getContext = vi.fn(() => ({ drawImage }));
    const originalCreateElement = document.createElement.bind(document);
    vi.spyOn(document, "createElement").mockImplementation(((tagName: string) => {
      if (tagName === "canvas") return { width: 0, height: 0, getContext, toBlob } as unknown as HTMLCanvasElement;
      return originalCreateElement(tagName);
    }) as typeof document.createElement);
    vi.stubGlobal("createImageBitmap", vi.fn(async () => ({ width: 3200, height: 1600, close: vi.fn() })));

    expect(hasExifMetadata(gpsExifJpeg)).toBe(true);
    const output = await prepareReviewPhoto(new File([gpsExifJpeg], "dish.jpg", { type: "image/jpeg" }));
    expect(hasExifMetadata(new Uint8Array(await output.arrayBuffer()))).toBe(false);
    expect(getContext).toHaveBeenCalledOnce();
    expect(drawImage).toHaveBeenCalledWith(expect.any(Object), 0, 0, 1600, 800);
    expect(toBlob).toHaveBeenCalledWith(expect.any(Function), "image/jpeg", 0.8);
  });
});
