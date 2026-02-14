import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "io.speakwrite.app",
  appName: "Speakwrite",
  // Points to the built web app
  webDir: "../web/dist",
  ios: {
    scheme: "Speakwrite",
  },
  server: {
    // In dev, load from Vite dev server
    // url: "http://127.0.0.1:3000",
  },
};

export default config;
