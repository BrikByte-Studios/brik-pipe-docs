# E2E Diagnostics (BrikPipe v1)

Diagnostics are **not** E2E artifacts (screenshots/videos/reports).
Diagnostics are for **failure triage + auditability**:
- Console logs
- Traces (Playwright)
- Network HAR (opt-in)
- Selenium Grid service logs

This doc covers where diagnostics land, how to enable them safely, and redaction risks.

---

## Canonical Layout

Diagnostics are written to:

```text
test-artifacts/e2e/diagnostics/
console/
traces/
network/
grid/
```

And exported into the audit bundle:

```text
.audit/YYYY-MM-DD/e2e/diagnostics/
```


---

## Defaults & Modes

`diagnostics_mode`:
- `off`: do nothing (still creates dirs)
- `minimal` (default):
  - runner.log
  - console logs (if present)
  - Playwright traces **on failure** (when exit_code is provided and non-zero)
- `full`:
  - everything in minimal
  - optional HAR capture (only if `network_har=true`)
  - Selenium Grid logs (hub/node/docker ps) when available

---

## Tool Notes

### Playwright
- Traces typically appear under `test-results/**/trace.zip` (config-dependent).
- To ensure traces exist, enable them in `playwright.config.ts`:
  - `trace: "retain-on-failure"` recommended
- HAR capture is **off by default** and must be opt-in.

### Cypress
- Browser console logs are not reliably exposed in all Cypress modes.
- If you need console logs, implement a plugin/task that writes logs to a file and the collector will pick them up.
- HAR requires a plugin (opt-in).

### Selenium Grid
- Grid logs are collected either by teardown actions or directly via Docker logs (full mode).
- Browser logs depend on the runner/framework.

---

## Security & Redaction Guidance

⚠️ HAR files can contain:
- Authorization headers
- session cookies
- tokens and PII

Safe defaults:
- `network_har=false`
- Use test accounts only
- Avoid printing request bodies with secrets
- Prefer minimal mode for public/shared runners

---

## Size Controls

Diagnostics collection supports:
- `max_total_mb`
- `max_file_mb`

If a file exceeds `max_file_mb`, it is skipped.
If the total exceeds `max_total_mb`, the collector stops copying further diagnostics.

Recommended defaults:
- `max_total_mb=250`
- `max_file_mb=50`

