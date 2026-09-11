import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "GymTracker",
    short_name: "GymTracker",
    description: "Personal and shared training progress.",
    start_url: "/",
    display: "standalone",
    background_color: "#f4f6f3",
    theme_color: "#3d7f57",
  };
}
