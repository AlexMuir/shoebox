import { defineConfig, devices } from "@playwright/test"

/**
 * Playwright configuration for Photos E2E tests
 * Targets localhost:3000 with console capture for debugging
 */
export default defineConfig({
  testDir: "./spec/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: "http://localhost:3000",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    logger: {
      log: (message) => console.log(`[PW:LOG] ${message}`),
      debug: (message) => console.debug(`[PW:DEBUG] ${message}`),
      info: (message) => console.info(`[PW:INFO] ${message}`),
      warn: (message) => console.warn(`[PW:WARN] ${message}`),
    },
  },

  projects: [
    {
      name: "chromium",
      use: {
        ...devices.chromiumLinux,
        launchArgs: ["--enable-logging"],
      },
    },
  ],

  /* Uncomment to auto-start webServer during tests
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
  */
})
