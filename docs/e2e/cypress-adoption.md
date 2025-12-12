# Cypress Adoption Guide — BrikByteOS (E2E)

> **Purpose:** Help any BrikByte Studios UI repo adopt Cypress E2E quickly and consistently:
> - deterministic CI
> - fully offline (no Cypress Cloud)
> - strong artifacts (videos + screenshots)
> - reusable workflow integration

---

## 1) When You Should Use Cypress

Use Cypress if **any** of the following is true:

- The repo already has Cypress tests (keep investment).
- The team prefers Cypress Runner UX for day-to-day debugging.
- The UI is a dashboard/CRUD-style app (forms, tables, basic auth).
- You want a very fast local feedback loop in-browser.

If you are starting fresh and want a default choice, see:
- `docs/testing/e2e-selection.md`

---

## 2) Standard Folder Layout (Required)

In the UI repo (or in the UI package directory), create:
```text
<service_workdir>/
cypress.config.cjs
tsconfig.json # required if you write *.ts specs/support
tests/
e2e/
cypress/
e2e/
smoke.cy.ts
fixtures/
testUser.json
support/
e2e.ts
screenshots/ # generated (gitignored)
videos/ # generated (gitignored)
```

### Why this layout?
- Keeps E2E code in a predictable location
- Matches the reusable workflow’s default artifact upload paths
- Prevents “Cypress can’t find config/specs/fixtures” problems

---

## 3) Local Setup

### 3.1 Install dependencies

Ensure the UI package has:

- `cypress`
- `typescript` (only if you use `.ts`)
- a `tsconfig.json`

Example `package.json` scripts:

```json
{
  "scripts": {
    "cy:open": "cypress open",
    "cy:run": "cypress run"
  }
}
```
### 3.2 Run your UI app locally

Start your app (example):
```bash
npm run dev
# or
npm start
```
Add a `/health` endpoint if possible so readiness checks are explicit.

### 3.3 Run Cypress locally

**Run headless (preferred for quick checks):**
```bash
CYPRESS_BASE_URL=http://localhost:3000 npm run cy:run
```

**Open the Cypress runner:**
```bash
CYPRESS_BASE_URL=http://localhost:3000 npm run cy:open
```
---

## 4) Required Files (Copy/Paste Ready)
### 4.1 `cypress.config.cjs` (recommended)

We recommend **CJS** (`.cjs`) to avoid TS/ESM loader issues inside Docker images.
```js
/**
 * Baseline Cypress configuration (BrikByteOS standard).
 *
 * Goals:
 * - Deterministic in CI
 * - Fully offline (no Cypress Cloud)
 * - Artifacts always generated (videos + screenshots on failure)
 * - Base URL driven by env:
 *   - CYPRESS_BASE_URL (preferred)
 *   - E2E_TARGET_URL  (shared with other tools)
 */

function parseIntEnv(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

const baseUrl =
  process.env.CYPRESS_BASE_URL ||
  process.env.E2E_TARGET_URL ||
  "http://localhost:3000";

const runModeRetries = parseIntEnv(process.env.CYPRESS_RUN_MODE_RETRIES, 2);
const openModeRetries = parseIntEnv(process.env.CYPRESS_OPEN_MODE_RETRIES, 0);

module.exports = {
  e2e: {
    baseUrl,

    specPattern: "tests/e2e/cypress/e2e/**/*.cy.{js,jsx,ts,tsx}",
    supportFile: "tests/e2e/cypress/support/e2e.ts",
    fixturesFolder: "tests/e2e/cypress/fixtures",

    screenshotsFolder: "tests/e2e/cypress/screenshots",
    videosFolder: "tests/e2e/cypress/videos",

    video: true,
    screenshotOnRunFailure: true,

    retries: {
      runMode: runModeRetries,
      openMode: openModeRetries,
    },

    setupNodeEvents(on, config) {
      // Placeholder for future reporters/tasks.
      return config;
    },
  },
};
```

### 4.2 `tests/e2e/cypress/support/e2e.ts`
```ts
// Global Cypress support file for BrikByteOS E2E.
//
// Responsibilities:
// - Shared hooks
// - Debug logging
// - Future custom commands

/// <reference types="cypress" />

before(() => {
  // Shows up in CI logs; useful when switching staging/local.
  // eslint-disable-next-line no-console
  console.log("[CYPRESS] baseUrl:", Cypress.config("baseUrl"));
});

afterEach(function () {
  if (this.currentTest?.state === "failed") {
    // Cypress will capture screenshots automatically on failure if enabled.
    // eslint-disable-next-line no-console
    console.log("[CYPRESS] Test failed — expect screenshot + video artifacts.");
  }
});
```

### 4.3 `tsconfig.json` (required for TS specs)

Put in `<service_workdir>/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["cypress", "node"],
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["tests/e2e/cypress/**/*.ts", "cypress.config.*"]
}
```

---

## 5) Fixtures (Avoid “fixture not found” errors)
### 5.1 Example fixture

Create:

`tests/e2e/cypress/fixtures/testUser.json`
```json
{
  "email": "test.user@brikbyteos.local",
  "password": "password123!",
  "displayName": "Test User"
}
```

### 5.2 Use it correctly

In tests:
```ts
cy.fixture("testUser").then((user) => {
  cy.get('[data-testid="login-email"]').type(user.email);
});
```

Cypress resolves fixtures relative to `fixturesFolder`.
If `fixturesFolder` is set to `tests/e2e/cypress/fixtures`, then `cy.fixture("testUser")` maps to `.../fixtures/testUser.json`.

---

## 6) CI Adoption (Recommended: Reusable Workflow)
### 6.1 In your UI repo workflow

Create `.github/workflows/e2e-cypress.yml`:
```yml
name: "E2E - Cypress"

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main ]

jobs:
  e2e-cypress:
    uses: BrikByte-Studios/.github/.github/workflows/e2e-cypress.yml@main
    with:
      # Option A: test an existing staging URL
      # target_url: "https://staging.example.com"

      # Option B: start the app in Docker inside CI:
      start_with_docker: true
      docker_image_name: "my-ui-app"
      docker_port: 3000

      # In Docker-network mode, Cypress should target the container host `app`
      target_url: "http://app:3000"
      health_path: "/health"

      # Where the Cypress config/tests live:
      service_workdir: "."

      artifact_name: "cypress-artifacts"
```

### 6.2 Docker mode requirements

To use `start_with_docker: true`, your `<service_workdir>` must contain a valid `Dockerfile`.

**Important:** the container must listen on `PORT` (or whichever env your Dockerfile uses).
The reusable workflow assumes:
- container name: `app`
- network name: `e2e-net`
- health check hits `http://app:<docker_port><health_path>`

---

## 7) Artifacts & Git Hygiene
### 7.1 Gitignore (recommended)

Add to `.gitignore` in the UI package:
```gitignore
# Cypress artifacts (generated)
tests/e2e/cypress/videos/
tests/e2e/cypress/screenshots/
```

**Why:** These are generated per-run and can be large/noisy.

### 7.2 Why you might not see screenshots locally

Cypress only creates screenshots automatically when:
- a test fails **and**
- `screenshotOnRunFailure: true` is enabled (we enable it)

If all tests pass, you’ll typically see videos but not screenshots.

To force screenshot generation, you can do:
```ts
cy.screenshot("manual-checkpoint");
```
---

## 8) Common Pitfalls & Fixes
### 8.1 “Cypress verification timed out” (Linux)

This often happens in local environments when Cypress needs dependencies or sandbox config.

**Fix options:**
- Use Docker-based Cypress for CI (recommended).
- Ensure system deps for Cypress are present (GUI libs, etc.).
- Prefer `cypress/included:<version>` for deterministic CI runs.

### 8.2 “Unknown file extension .ts for cypress.config.ts”

In Docker, TypeScript config files can fail depending on Node/loader settings.

**Fix:** use `cypress.config.cjs` (recommended standard).

### 8.3 “No tsconfig.json found”

If you run `.ts` specs/support files, Cypress needs a `tsconfig.json`.

**Fix:** add `<service_workdir>/tsconfig.json` as in Section 4.3.

### 8.4 “Could not resolve host: app”

This means the process trying to call `http://app:3000` is not on the same Docker network.

**Fix:**
- Ensure readiness check runs inside Docker with `--network e2e-net`
- Ensure Cypress runner container uses `--network e2e-net`
- Ensure UI container is on `--network e2e-net` and is named `app`

---

## 9) Adoption Checklist (Definition of Done)
- [ ] `cypress.config.cjs` exists in `<service_workdir>`
- [ ] `tests/e2e/cypress/e2e/` contains at least `smoke.cy.*`
- [ ] `tests/e2e/cypress/fixtures/testUser.json` exists (if needed)
- [ ] `tests/e2e/cypress/support/e2e.ts` exists
- [ ] `tsconfig.json` exists if you use TypeScript tests
- [ ] `.gitignore` excludes screenshots/videos
- [ ] CI workflow calls the reusable Cypress workflow
- [ ] Artifacts upload works (videos + screenshots on failure)

---

## 10)  References
- `docs/e2e/e2e-selection.md` — when to choose Cypress vs Playwright
- `.github/workflows/e2e-cypress.yml` — reusable Cypress workflow (org-level)