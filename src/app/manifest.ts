import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Bản đồ món ăn",
    short_name: "Food map",
    description: "Bản đồ review món ăn quanh bạn",
    start_url: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#c2410c",
    lang: "vi",
    icons: [
      {
        src: "/favicon.ico",
        sizes: "any",
        type: "image/x-icon",
      },
    ],
  };
}
