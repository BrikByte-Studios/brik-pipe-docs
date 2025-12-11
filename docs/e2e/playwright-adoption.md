# BrikByteOS E2E Playwright Adoption Guide

> **Spec:** PIPE-E2E-PLAYWRIGHT-BUILD-001  
> **Domain Deliverable:** D-002 – QA Automation Suite  
> **Scope:** Standardised UI E2E testing for BrikByteOS services

---

## 1. Purpose & Outcomes

This document explains how BrikByteOS services should:

1. **Adopt the reusable Playwright E2E workflow**  
   from `BrikByte-Studios/.github` (`.github/workflows/e2e-playwright.yml`).

2. **Structure their E2E UI tests**  
   under `tests/e2e/playwright/` using a shared baseline config.

3. **Integrate E2E evidence into `.audit/`**  
   so UI automation is first-class in the governance pipeline.

4. **(Optional) Measure sharding impact**  
   to show that parallelism yields meaningful speed gains.

Once adopted, a service should have:

- A **single golden-path E2E test** (Login → dashboard → logout) that is:
  - Deterministic.
  - CI-driven.
  - Multi-browser capable.

- A **service-scoped workflow** that runs on:
  - `pull_request` → against the service code.
  - `main` → as part of the core pipeline.

- **Audit bundles** for each run under:
  - `.audit/PIPE-E2E/<RUN-ID>/…`

---

## 2. Architecture Overview

### 2.1 Components

1. **Org-level reusable workflow**

   Repo: `BrikByte-Studios/.github`  
   File: `.github/workflows/e2e-playwright.yml`

   Responsibilities:

   - Install Node + dependencies.
   - Install Playwright browsers.
   - Start the UI app (for UI services).
   - Run `npx playwright test` with:
     - Multi-browser support (Chromium mandatory).
     - Workers/retries/trace mode driven via env.
   - Export:
     - **HTML report** → `playwright-report/`
     - **Test results + traces** → `test-results/`
     - **Audit bundle** → `.audit/PIPE-E2E/<RUN-ID>/…`

2. **Service-level Playwright wiring**

   Example service: `BrikByte-Studios/brik-pipe-examples` → `node-ui-example`

   - `node-ui-example/playwright.config.ts`  
   - `node-ui-example/tests/e2e/playwright/auth.spec.ts`  
   - `node-ui-example/.github/workflows/e2e-playwright-demo.yml` (or similar)

3. **Documentation & benchmark harness (this repo)**

   Repo: `BrikByte-Studios/brik-pipe-docs`  
   File: `docs/e2e/playwright-adoption.md` (this file)  
   Optional: `docs/e2e/e2e-playwright-benchmark.md` (if split out later)

---

## 3. Reusable Workflow: `e2e-playwright.yml`

### 3.1 Location

- **Repo:** `BrikByte-Studios/.github`  
- **File:** `.github/workflows/e2e-playwright.yml`  
- **Name:** `E2E - Playwright (Reusable)`

### 3.2 Inputs (Interface Contract)

```yaml
on:
  workflow_call:
    inputs:
      target_url:        # Base URL for tests (e.g., http://localhost:3000)
      enable_firefox:    # bool → include Firefox project
      enable_webkit:     # bool → include WebKit project
      workers:           # string → "1", "2", "50%" etc.
      retries:           # number → global retry count
      trace_mode:        # string → on | on-first-retry | retain-on-failure | off
      service_workdir:   # path → e.g. "node-ui-example"
      artifact_suffix:   # string → e.g. "-baseline" | "-sharded"
```

### 3.3 Behaviour (Key Points)

- Sets env vars:
    - `E2E_TARGET_URL`
    - `PW_ENABLE_FIREFOX`, `PW_ENABLE_WEBKIT`
    - `PW_WORKERS`, `PW_RETRIES`, `PW_TRACE_MODE`
    - `PW_BROWSER` (per matrix browser)
- Installs dependencies and Playwright browsers in `service_workdir`.
- Starts the UI app (for UI services) via:
```bash
node src/server.mjs &
```
- Waits for `http://localhost:3000/login` to respond (simple curl loop).

- Runs Playwright:
```bash
npx playwright test --project="$PW_BROWSER"
```

- Records run duration and exports to GitHub env & outputs.
- Creates an **audit slice** for each run:
```text
.audit/PIPE-E2E/<RUN-ID>/
  ├─ .audit-e2e-marker
  ├─ playwright-report/
  ├─ test-results/
  └─ metadata.json
```

- ploads:
  - `e2e-audit-<service_workdir>-<browser>-workers-<workers><suffix>`
  - `playwright-report-<service_workdir>-<browser><suffix>`

---

## 4. Baseline Playwright Config (Service-Level)

Every UI service using Playwright should have a config **based on**:
- **Repo**: `BrikByte-Studios/brik-pipe-examples`  
- **File**: `node-ui-example/playwright.config.ts`

### 4.1 Config Responsibilities
- Read **base URL** from:
```ts
const baseURL = process.env.E2E_TARGET_URL ?? 'https://staging.example.com';
```
- Configure **global timeouts**, retries, and workers from env:
```ts
const workersEnv = process.env.PW_WORKERS;
const retriesEnv = process.env.PW_RETRIES;

const workers: number | string = workersEnv ?? '50%';
const retries: number = parseIntEnv(retriesEnv, 1);
```

- Configure **trace mode** via `PW_TRACE_MODE` with safe defaults.
- Define projects:
```ts
const projects: PlaywrightTestConfig['projects'] = [
  { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
];

if (enableFirefox) {
  projects.push({ name: 'firefox', use: { ...devices['Desktop Firefox'] } });
}

if (enableWebkit) {
  projects.push({ name: 'webkit', use: { ...devices['Desktop Safari'] } });
}
```

- Configure reporter:
```ts
reporter: [
  ['list'],
  ['html', { outputFolder: 'playwright-report', open: 'never' }],
],
```

### 4.2 How Services Should Extend It

1. **Copy baseline into your repo** (adjust path):
     - `playwright.config.ts` at service root (e.g. `frontend-app/playwright.config.ts`).

2. **Customise**:
     - `testDir` to your structure (if different).
     - Add service-specific `use` options (e.g., `storageState`, `locale`).
     - Add additional projects (mobile viewport, etc.) when needed.
3. **Never hard-code** sensitive values:
    - Use env variables for tokens/special credentials.
    - Masks/secrets are handled at workflow level, not in config.

---

## 5. Example Service Integration: node-ui-example
### 5.1 Project Structure
```text
node-ui-example/
  src/
    server.mjs              # Simple Express-based login/dashboard UI
  tests/
    e2e/
      playwright/
        auth.spec.ts        # Login → dashboard → logout
        fixtures/
          testUsers.ts      # Non-secret demo test user
        helpers/
          routes.ts         # Centralized route paths
  playwright.config.ts
  package.json
  Dockerfile                # (not strictly required for Playwright CI flow)
```

### 5.2 Golden-Path Test

File: `node-ui-example/tests/e2e/playwright/auth.spec.ts`
- Uses **data-testid** selectors.
- Imports **routes** and **fixtures**:
```ts
import { routes } from './helpers/routes';
import { defaultStagingUser } from './fixtures/testUsers';
```
- Flow:
    1. `GET /login`
    2. Fill username + password from `defaultStagingUser`.
    3. Submit, expect redirect to `/dashboard`.
    4. Validate a `dashboard-welcome` element.
    5. Logout and assert redirect to `/login`.

### 5.3 Service-Level Workflow

File: `.github/workflows/e2e-playwright-demo.yml` in `brik-pipe-examples`
```yaml
name: "E2E - Playwright (node-ui-example)"

on:
  pull_request:
    branches: [ main, develop ]
    paths:
      - "node-ui-example/**"
      - ".github/workflows/e2e-playwright-demo.yml"
  push:
    branches: [ main ]
    paths:
      - "node-ui-example/**"
      - ".github/workflows/e2e-playwright-demo.yml"

jobs:
  e2e-ui:
    uses: BrikByte-Studios/.github/.github/workflows/e2e-playwright.yml@main
    with:
      target_url: "http://localhost:3000"
      enable_firefox: true
      enable_webkit: false
      workers: "50%"
      retries: 1
      trace_mode: "on-first-retry"
      service_workdir: "node-ui-example"
```
**Notes:**

- `target_url` is `http://localhost:3000` because the reusable workflow starts the app inside the runner.
- `service_workdir` tells the reusable workflow where `package.json` and `playwright.config.ts` live.

---

## 6. Governance & .audit Integration
### 6.1 Audit Directory Layout

Each run of the reusable workflow creates an audit slice:
```text
.audit/PIPE-E2E/<RUN-ID>/
  ├─ .audit-e2e-marker
  ├─ playwright-report/
  ├─ test-results/
  └─ metadata.json
```
- `<RUN-ID>` pattern:
```text
<GITHUB_RUN_ID>-playwright-e2e-<BROWSER>-workers-<PW_WORKERS>
```

### 6.2 Metadata Contract

`metadata.json` includes:
```json
{
  "type": "e2e-playwright",
  "spec": "PIPE-E2E-PLAYWRIGHT-BUILD-001",
  "run_id": "2012...",
  "run_attempt": "1",
  "job": "playwright-e2e",
  "browser": "chromium",
  "workers": "50%",
  "duration_seconds": 3,
  "repo": "BrikByte-Studios/brik-pipe-examples",
  "ref": "refs/heads/main",
  "sha": "abc123...",
  "status": "success",
  "workflow": "E2E - Playwright (Reusable)",
  "run_number": "42"
}
```

This enables:
- **Policy-as-code gates** to require:
  - At least one successful E2E run per critical service.
  - E2E evidence as part of release bundles.
- **Forensic analysis** after incidents:
  - What browser was used?
  - How long did tests take?
  - Which commit + branch?

---

## 7. Sharding Benchmark (Optional)

To validate that sharding is worth enforcing at policy level, a **benchmark workflow** exists (or can exist) in `brik-pipe-examples`:

File: `.github/workflows/e2e-playwright-benchmark.yml`

### 7.1 Workflow Shape
- **Jobs**:
  - `baseline`: `workers=1`, `artifact_suffix=-baseline`
  - `sharded`: `workers=50%`, `artifact_suffix=-sharded`
  - `compare`: downloads both audit artifacts and computes reduction

- **Script**: `.github/scripts/compute_sharding.py`
  - Reads `metadata.json` from both runs (baseline & sharded).
  - Computes reduction = `(baseline - sharded) / baseline * 100`.
  - Fails if reduction < configurable threshold (e.g., 20–30%).

This is:
- **Optional** – not required for day-to-day CI.
- **Useful for research & tuning** – informs how aggressive sharding should be.

---

## 8. How Other Services Should Adopt Playwright
### 8.1 Minimal Checklist

1. **Add Playwright dependencies** to your service `package.json`:
```json
"devDependencies": {
  "@playwright/test": "^1.x.x",
  // your existing dev dependencies
}
```
2. **Copy baseline `playwright.config.ts`** into your service:
    - Adjust `testDir` if needed.
    - Keep env-driven configuration intact.
3. **Create E2E test directory**:
```text
<service>/
  tests/
    e2e/
      playwright/
        auth.spec.ts
        fixtures/
        helpers/
```
4. **Implement at least one golden-path flow** (login → dashboard → logout).
5. **Add a service-scoped workflow** similar to `e2e-playwright-demo.yml`:
    - Point `service_workdir` to your service directory.
    - Configure `target_url` as `http://localhost:<port>` (if workflow starts app).
    - Keep `workers`, `retries`, `trace_mode` reasonably conservative at first.

6. **Run locally**:
```bash
cd <service>
npx playwright test
# or
E2E_TARGET_URL=http://localhost:3000 npx playwright test
```

7. **Validate `.audit` output in CI**:
     - Check that `.audit/PIPE-E2E/...` is being created.
     - Confirm `metadata.json` contains expected values.

---

## 9. Frequently Asked Questions
### Q1. Do we have to use the exact same folder structure?

**Recommended:** Yes, for consistency.
- `tests/e2e/playwright/` is the standard.
- `playwright.config.ts` at the service root is the default assumption.

If you need a different layout, you can adjust `testDir` in the config and keep everything else standard.

### Q2. Can a service extend Playwright config with custom projects?

Yes.
- You can add mobile, tablet, or region-specific projects.
- Keep the **baseline env-driven settings** intact:
  - `baseURL`
  - `workers` & `retries` from env
  - `trace` from env

### Q3. How do we handle secrets (e.g., login tokens)?
- Never hard-code real credentials in tests or config.
- Use environment variables and GitHub-encrypted secrets.
- For long-term, prefer **test-only accounts** with minimal privileges.

### Q4. How do E2E tests interact with feature flags / toggles?
- Treat feature flags as part of the **environment configuration**.
- Prefer toggling via env or config files used by the app (not by the test code).

---

## 10.  Next Steps / Roadmap

Future enhancements:
1. **Cross-service E2E dashboards**
    - Aggregate `.audit/PIPE-E2E` metadata across repos.
    - Provide pass-rate, duration, and flakiness insights.
2. **Policy Gates**
    - Hard-gate releases on critical E2E flows for selected services.
    - Require a minimum pass rate threshold.
3. **Fixtures & Test Data Standardisation**
    - Shared patterns for seeding test data.
    - Contract-based mocks for external dependencies in UI flows.

---

## 11.  Summary

Adopting the Playwright E2E standard means:
- **You get:**  
    A consistent, auditable, multi-browser UI test harness backed by .audit evidence and CI workflows.
- **You must:**
  - Wire your service into the reusable workflow.
  - Implement at least one high-value golden-path test.
  - Keep Playwright config env-driven and governance-aware.