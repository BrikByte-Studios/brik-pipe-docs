# E2E Artifacts & Retention (BrikPipe v1)

This doc explains:

- **What gets collected** for E2E runs (per tool: Playwright, Cypress, Selenium Grid)
- **Where artifacts land** in the canonical folder layout (`test-artifacts/e2e/**` + `.audit/**`)
- **How upload + retention works** (policy modes)
- **How to configure size controls** (max total MB / max file MB)
- **How to add your own extra artifacts** (custom globs)

---

## Canonical E2E Output Layout

All E2E workflows/actions converge into a consistent structure:

```text
test-artifacts/e2e/
reports/ # HTML reports + report-like outputs
artifacts/ # user artifacts (screenshots/videos/logs/etc)
traces/ # traces when available (tool-dependent)
raw/ # raw evidence + diagnostics
diagnostics/
runner.log
console/
grid/ # selenium-grid logs (hub/node/docker-ps)
test-results/ # raw test reports (JUnit/TRX/etc)
test-results.json # normalized results schema (test-results.json/v1)
```

```text
.audit/
YYYY-MM-DD/
e2e/
metadata.json
test-results.json
artifacts/
diagnostics/
reports/
traces/
```

> `.audit` is the long-lived “evidence bundle” format.  
> `test-artifacts/e2e/**` is the working “canonical scratchpad” that actions populate.

---

## What Gets Collected (Per Tool)

### Playwright

**Collected sources (typical):**
- HTML report directory (default: `playwright-report/`)
- Test results directory (default: `test-results/`)
- Traces/screenshots/videos (depending on Playwright config)
- Runner logs into `test-artifacts/e2e/raw/diagnostics/runner.log`
- Normalized results into `test-artifacts/e2e/test-results.json`
- Raw reports folder `test-artifacts/e2e/test-results/` (JUnit copy if available)

**Canonical mapping:**
- `playwright-report/**` → `test-artifacts/e2e/reports/**` (via collector)
- `test-results/**` → `test-artifacts/e2e/artifacts/**` and/or `test-artifacts/e2e/traces/**` (depending on collector config)
- `.audit/YYYY-MM-DD/e2e/**` includes:
  - `test-results.json`
  - `metadata.json`
  - `reports/`, `artifacts/`, `traces/` (best-effort mapped from canonical)

**Configure Playwright to emit artifacts:**
In `playwright.config.ts`, ensure you enable what you want collected:
- `trace: 'on-first-retry' | 'on' | 'retain-on-failure'`
- `screenshot: 'only-on-failure' | 'on'`
- `video: 'retain-on-failure' | 'on'`

---

### Cypress

**Collected sources (typical):**
- Screenshots dir (default: `cypress/screenshots/`)
- Videos dir (default: `cypress/videos/`)
- Report outputs dir (default: `cypress/results/`) if used
- Runner logs into `test-artifacts/e2e/raw/diagnostics/runner.log`
- Normalized results into `test-artifacts/e2e/test-results.json`
- Raw reports (JUnit) into `test-artifacts/e2e/test-results/` if present

**Canonical mapping:**
- Cypress screenshots/videos/reports → `test-artifacts/e2e/artifacts/**` (via collector)
- `.audit/YYYY-MM-DD/e2e/**` includes:
  - `test-results.json`
  - `metadata.json`
  - `artifacts/` with screenshots/videos/logs
  - `raw-reports/` (JUnit/TRX if copied)

**Important:** Cypress workflows often use `continue-on-error: true` for the runner step so that normalization + audit still run. The job fails at the end, based on exit code.

---

### Selenium Grid (Java/Python/etc runners)

**Collected sources (typical):**
- JUnit/TRX reports from runner (e.g. Maven Surefire XML)
- User artifacts if your runner writes them somewhere (screenshots/site/logs, etc)
- Runner log into `test-artifacts/e2e/raw/diagnostics/runner.log`
- Selenium Grid hub/node logs into `test-artifacts/e2e/raw/diagnostics/grid/**`
- Normalized results into `test-artifacts/e2e/test-results.json`

**Canonical mapping:**
- Raw reports copied into `test-artifacts/e2e/test-results/**`
- User artifacts (based on `artifact_globs`) copied into:
  - `test-artifacts/e2e/raw/artifacts-user/**` (optional pre-collector step)
  - `test-artifacts/e2e/artifacts/**` (collector output)
- `.audit/YYYY-MM-DD/e2e/**` includes:
  - `test-results.json`
  - `metadata.json`
  - `diagnostics/` (runner.log + grid logs if present)
  - `reports/`, `artifacts/`, `traces/` mapped from canonical `test-artifacts/e2e/**`

**Note:** Selenium doesn’t automatically produce screenshots/videos unless your runner/framework is configured to do so.

---

## Upload Policy & Retention

BrikPipe standardizes uploads using:

- **GitHub `actions/upload-artifact@v4`** (under the hood)
- A policy input: `artifact_mode`

### `artifact_mode`

- `never`  
  Never upload artifacts.
- `always`  
  Always upload artifacts, regardless of pass/fail.
- `on-failure` (default)  
  Upload only when tests fail.

### Retention

All workflows accept:

- `artifact_retention_days` (workflow-level) or `retention_days` (upload action-level)

Default: **7 days**.

---

## Upload Action: `upload-e2e-artifacts`

This action provides consistent policy handling.

**Key inputs:**
- `name`: artifact name
- `path`: newline-separated paths
- `artifact_mode`: `on-failure|always|never`
- `retention_days`: integer
- `exit_code` (recommended): authoritative pass/fail signal

> Using `exit_code` is strongly recommended because E2E workflows often “fail at the end” (after normalization/audit). Relying only on `failure()` can mis-detect.

**Recommended usage (policy based on exit code):**
```yaml
- name: Upload E2E artifacts
  if: always()
  uses: BrikByte-Studios/brik-pipe-actions/.github/actions/upload-e2e-artifacts@main
  with:
    name: e2e-playwright-artifacts
    artifact_mode: ${{ inputs.artifact_mode }}
    retention_days: ${{ inputs.artifact_retention_days }}
    exit_code: ${{ steps.run_pw.outputs.exit_code }}
    path: |
      test-artifacts/e2e/**
      .audit/**
```
---
## Size Controls (Max Total + Max File)

Size limits are enforced during **collection** (before upload) by:
- `collect-e2e-artifacts`

### Collector Inputs

Typical knobs:
- `max_total_mb` (default example: `500`)
- `max_file_mb` (default example: `200`)
- `reports_globs` (what counts as “reports”)
- `artifact_globs` (what counts as “artifacts”)

**Example: stricter limits**
```yaml
- name: Collect E2E artifacts
  if: always()
  uses: BrikByte-Studios/brik-pipe-actions/.github/actions/collect-e2e-artifacts@main
  with:
    tool: playwright
    working_directory: ${{ inputs.working_directory }}
    out_root: test-artifacts/e2e
    artifact_mode: ${{ inputs.artifact_mode }}
    max_total_mb: "200"
    max_file_mb: "50"
```
### What happens when limits are exceeded?

The collector:

- Copies files until `max_total_mb is reached
- Skips files larger than `max_file_mb`
- Outputs counts like:
  - `copied_files`
  - `skipped_files`
  - `total_mb`

This prevents “artifact upload too large” failures and keeps evidence predictable.

---
## Customizing What Gets Collected
### 1) Override `artifact_globs`

Useful when your project outputs artifacts to custom locations.

**Example (Selenium runner using Maven target/):**
```yaml
- name: Collect E2E artifacts
  if: always()
  uses: BrikByte-Studios/brik-pipe-actions/.github/actions/collect-e2e-artifacts@main
  with:
    tool: selenium
    working_directory: ${{ inputs.working_directory }}
    out_root: test-artifacts/e2e
    artifact_mode: ${{ inputs.artifact_mode }}
    artifact_globs: "target/screenshots/**,target/site/**,target/logs/**"
    reports_globs: "**/surefire-reports/*.xml"
    max_total_mb: "500"
    max_file_mb: "200"
```

### 2) Ensure your tool actually writes artifacts

If you see logs like:

`No user artifacts matched artifact_globs=...`

That means the files **weren’t created** (or your globs don’t match). Fix by either:

- updating your framework to output artifacts to those paths, or
- correcting the globs to match real output paths.

---
## Troubleshooting Quick Checks
### “Nothing uploaded even though tests failed”
- Ensure:
  - your upload step runs with `if: always()`
  - you pass `exit_code` from the runner action output
  - `artifact_mode` isn’t `never`

### “No screenshots/videos collected”
- The tool must be configured to produce them (Playwright/Cypress config, Selenium runner hooks).

### “Report dir not found”
- Don’t pass `report_dir/results_dir` unless they exist **relative to the expected base**.
- Preferred: rely on canonical `test-artifacts/e2e/**` mapping via `collect-e2e-artifacts` + `export-audit-e2e`.

---
## Recommended Defaults (v1)

- Keep `artifact_mode: on-failure` for cost control
- Keep `retention_days: 7`
- Use `max_total_mb: 500`, `max_file_mb: 200` (tune per repo)
- Always generate `.audit` and upload it on failure

