import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sourceDirectory = resolve(repositoryRoot, "node_modules/maplibre-gl/dist");
const destinationDirectory = resolve(repositoryRoot, "public/maplibre");
const workerFiles = ["maplibre-gl-worker.mjs", "maplibre-gl-shared.mjs"];

await mkdir(destinationDirectory, { recursive: true });
for (const file of workerFiles) {
  const sourcePath = resolve(sourceDirectory, file);
  const destinationPath = resolve(destinationDirectory, file);
  let alreadyCurrent = false;
  try {
    const [source, destination] = await Promise.all([
      readFile(sourcePath),
      readFile(destinationPath),
    ]);
    alreadyCurrent = source.equals(destination);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  if (!alreadyCurrent) await copyFile(sourcePath, destinationPath);
}

console.log(`Verified ${workerFiles.length} MapLibre worker files in public/maplibre.`);