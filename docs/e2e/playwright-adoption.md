# Playwright E2E — BrikByteOS (v1)

This document describes the BrikByteOS “golden path” for Playwright E2E.

## Required contract
- Provide `base_url` to the reusable workflow.
- Ensure your Playwright config:
  - writes HTML report to `playwright-report/`
  - writes test artifacts to `test-results/`
  - uses trace policy `on-first-retry` or `on-failure`

## Reusable workflow usage
```yaml
jobs:
  e2e:
    uses: BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-playwright.yml@main
    with:
      working_directory: "."
      base_url: "https://your-env.example.com"
```

## Evidence outputs
- `playwright-report/` → HTML report
- `test-results/` → traces/screenshots/videos
- `.audit/YYYY-MM-DD/e2e/` → audit bundle (always)