import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

// En modo "demo" todo va en un solo HTML (para enseñarla sin servidor).
export default defineConfig(({ mode }) => ({
  base: "./",
  plugins: mode === "demo" ? [viteSingleFile()] : [],
  build: { outDir: mode === "demo" ? "dist-demo" : "dist", target: "es2020" },
}));
