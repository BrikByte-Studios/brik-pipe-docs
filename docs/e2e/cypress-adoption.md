# Cypress E2E Stage (BrikByteOS v1)

The Cypress E2E stage provides a **standardized, auditable, and reproducible**
end-to-end testing pipeline for UI-focused web applications.

It enforces:
- deterministic CI execution
- consistent evidence capture (screenshots, videos, logs)
- normalized `test-results.json`
- canonical `.audit` evidence bundles

This stage is part of the **BrikByteOS E2E v1 contract**.

---

## What You Get

| Capability | Description |
|-----------|-------------|
| Reproducible Runs | Locked Node + Cypress runner with consistent env contracts |
| Diagnostics | `runner.log`, screenshots, videos |
| Evidence Bundles | `.audit/YYYY-MM-DD/e2e/**` |
| Normalized Results | `test-artifacts/e2e/test-results.json` |
| Artifact Retention | Configurable (`on-failure`, `always`, `never`) |

---

## Required Contract

### `base_url` (**required**)

The workflow exports:

```text
CYPRESS_baseUrl=<base_url>
BASE_URL=<base_url>
```

Your tests **must rely on Cypress baseUrl**, not hardcoded URLs.

---

## Recommended Repository Layout
```text
tests/e2e/cypress/
├─ e2e/*.cy.js
├─ fixtures/testUsers.json
cypress.config.cjs
```


---

## Cypress Configuration (Required)

To enable normalization and `.audit` export, **JUnit must exist**.

### Required reporter configuration

```js
reporter: "junit",
reporterOptions: {
  mochaFile: "test-artifacts/e2e/test-results/junit.xml",
  toConsole: false
}
```
This guarantees:
```bash
test-artifacts/e2e/test-results/junit.xml
```

exists on every run.

---

## Evidence Outputs
| Path | Purpose |
|------|---------|
| `cypress/screenshots/**` | Failure screenshots |
| `cypress/videos/**`	| Test run videos |
| `test-artifacts/e2e/raw/diagnostics/runner.log` | Cypress stdout/stderr |
| `test-artifacts/e2e/test-results.json` |	Normalized results |
| `.audit/YYYY-MM-DD/e2e/**` |	Canonical audit bundle |

---

## Workflow Usage

Caller repositories use:
```swift
BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-cypress.yml
```

Example:
```yaml
uses: BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-cypress.yml@main
with:
  working_directory: node-ui-example
  base_url: http://localhost:3000
  browser: chromium
```

---

## Artifact Policy
| Mode | Behavior |
|------|----------|
| on-failure (default) | Upload screenshots/videos only on failure |
| always | Upload everything |
| never | No Cypress artifacts uploaded |

`.audit` is **always produced** regardless of test outcome.

---

## Troubleshooting
### Chrome not found

GitHub runners expose **chromium** by default.

Use:
```yaml
browser: chromium
```

---

### No screenshots or videos

Ensure Cypress config:
```js
video: true,
screenshotsFolder: "cypress/screenshots",
videosFolder: "cypress/videos"
```

---

### Normalization fails

Verify:
```bash
test-artifacts/e2e/test-results/junit.xml
```

exists and is not empty.

---

### Where to look first on failures

1. `.audit/**/diagnostics/runner.log`
2. `.audit/**/artifacts/screenshots`
3. `.audit/**/artifacts/videos`
4. `.audit/**/test-results.json`

---

## Contract References
- PIPE-CORE-2.3 — E2E Test Stage
- ADR-AUDIT-003 — .audit Evidence Schema
- ADR-OBS-005 — Diagnostics Standard
- RTM-TEST-E2E-001 — E2E Baseline