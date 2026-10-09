export const MAX_REVIEW_PHOTOS = 5;
const MAX_EDGE = 1600;
const JPEG_QUALITY = 0.8;

export async function prepareReviewPhoto(file: File): Promise<Blob> {
  if (!file.type.startsWith("image/")) throw new Error("Unsupported image type");
  const bitmap = await createImageBitmap(file);
  try {
    const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvas.getContext("2d");
    if (!context) throw new Error("Canvas is unavailable");
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error("Could not encode image"));
      }, "image/jpeg", JPEG_QUALITY);
    });
  } finally {
    bitmap.close();
  }
}

export function hasExifMetadata(bytes: Uint8Array): boolean {
  if (bytes.length < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return false;
  let offset = 2;
  while (offset + 4 <= bytes.length && bytes[offset] === 0xff) {
    const marker = bytes[offset + 1];
    if (marker === 0xda || marker === 0xd9) return false;
    const segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (segmentLength < 2 || offset + 2 + segmentLength > bytes.length) return false;
    if (marker === 0xe1) return true;
    offset += 2 + segmentLength;
  }
  return false;
}
