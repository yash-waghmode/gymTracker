import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  workers: 1,
  timeout: 360000,
  expect: { timeout: 45000 },
  use: {
    baseURL: "http://localhost:3100",
    viewport: { width: 390, height: 844 },
    trace: "retain-on-failure",
  },
  webServer: {
    stdout: "pipe",
    command: "npx tsx tests/support/local-stack.mts",
    url: "http://localhost:3100/auth",
    reuseExistingServer: false,
    timeout: 300000,
  },
});
