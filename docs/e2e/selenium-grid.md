# Selenium Grid E2E (brik: e2e-selenium-grid v1)

This doc explains how to run **Selenium E2E** tests via the reusable workflow:

- `BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-selenium-grid.yml@main`

It provisions a **Selenium Grid (Hub + Nodes)** using Docker, runs your repo’s Selenium command, collects evidence, normalizes results, and exports a `.audit` bundle.

---

## What this workflow is for

Use this when:

- You have **Selenium tests** (Java, Python, .NET, etc.)
- You want **grid-based execution** with a browser matrix
- You want consistent artifacts and audit evidence via `.audit`

---

## How networking works (IMPORTANT)

Your Selenium browser runs **inside Docker containers** (Grid nodes). That means:

- `http://localhost:3000` works **from the GitHub runner host**
- but **does not work inside Grid containers**

✅ Use **`http://host.docker.internal:3000`** as your `base_url` for Selenium tests.

You can still poll app readiness from the runner with `http://localhost:3000/health`.

---

## Inputs

### Required
- `base_url` (string): Base URL reachable by Grid nodes (recommended: `http://host.docker.internal:3000`)
- `command` (string): Command to run your Selenium suite (e.g., `mvn -q test -Pe2e`, `pytest -q`)

### Common
- `working_directory` (string, default `"."`): Where your selenium project lives
- `browser_matrix` (string JSON array, default `["chrome","firefox"]`)
- `diagnostics` (`minimal|full`, default `full`)
- `evidence_dir` (default `test-artifacts/e2e/raw`)
- `raw_results_dir` (default `test-artifacts/e2e/test-results`)
- `normalized_results_out` (default `test-artifacts/e2e/test-results.json`)
- `artifact_mode` (`on-failure|always|never`, default `on-failure`)
- `timeout_minutes` (default `30`)

### Optional: Start the app under test inside the workflow
If your E2E needs the app running, you can have the workflow start it.

- `app_working_directory` (default `"."`)
- `app_install_command` (default `npm ci`)
- `app_start_command` (default `""`)
- `app_health_url` (default `""`)
- `app_start_timeout_seconds` (default `90`)
- `app_start_poll_seconds` (default `2`)

> If `app_start_command` is empty, the workflow assumes your app is already reachable.

---

## Example: Java Selenium runner (Maven)

**Caller workflow** (in your repo):

```yml
name: "E2E UI (Java • Selenium Grid)"

on:
  push:
  pull_request:

jobs:
  selenium-grid-e2e:
    uses: BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-selenium-grid.yml@main
    with:
      working_directory: java-selenium-runner-example

      # IMPORTANT: reachable from Grid nodes
      base_url: http://host.docker.internal:3000

      command: mvn -q test -Pe2e
      browser_matrix: '["chrome","firefox"]'

      # Optional: start app
      app_working_directory: node-ui-example
      app_install_command: npm ci
      app_start_command: npm start
      app_health_url: http://localhost:3000/health

      # Evidence + artifacts
      evidence_dir: test-artifacts/e2e/raw
      raw_results_dir: test-artifacts/e2e/test-results
      normalized_results_out: test-artifacts/e2e/test-results.json
      report_globs: "**/surefire-reports/*.xml"
      artifact_globs: "target/screenshots/**,target/site/**,target/logs/**"

      artifact_mode: on-failure
      artifact_retention_days: 7
      timeout_minutes: 30
```

---

## Example: Python Selenium runner (pytest)

### Caller workflow:
```yml
name: "E2E UI (Python • Selenium Grid)"

on:
  push:
  pull_request:

jobs:
  selenium-grid-e2e:
    uses: BrikByte-Studios/brik-pipe-actions/.github/workflows/e2e-selenium-grid.yml@main
    with:
      working_directory: python-selenium-runner-example

      # IMPORTANT: reachable from Grid nodes
      base_url: http://host.docker.internal:3000

      command: pytest -q
      browser_matrix: '["chrome"]'

      # Optional: start app
      app_working_directory: node-ui-example
      app_install_command: npm ci
      app_start_command: npm start
      app_health_url: http://localhost:3000/health

      evidence_dir: test-artifacts/e2e/raw
      raw_results_dir: test-artifacts/e2e/test-results
      normalized_results_out: test-artifacts/e2e/test-results.json

      artifact_mode: on-failure
      timeout_minutes: 30
```
### Python env var convention (recommended)

If your Python tests expect `E2E_TARGET_URL`, ensure your runner exports it from `base_url`.  

If you’re using `run-e2e-selenium@main`, it should export:
- `BASE_URL`
- `APP_BASE_URL`
- `E2E_TARGET_URL` ✅ (recommended for Python)

---
## Outputs & Artifacts

The workflow produces:

- `.audit/**` bundle (always exported)
- Evidence directory (screenshots/logs/etc)
- Raw reports collected into `raw_results_dir`
- Normalized results JSON at `normalized_results_out`

Artifacts uploaded depending on:
- `upload_artifacts` (default true)
- `artifact_mode` (`on-failure|always|never`)

---

## Troubleshooting
### 1) `ERR_CONNECTION_REFUSED` / `ERR_NAME_NOT_RESOLVED`

Cause: the browser is inside Docker and cannot reach `localhost`.

Fix:
- Set `base_url` to `http://host.docker.internal:3000`
- Keep `app_health_url` as `http://localhost:3000/health` (runner-side readiness check)

### 2) App health check fails

Check the captured `e2e-app.log` (the workflow tails it on failure).  
Common causes:
- missing dependencies (e.g., `Cannot find package 'express'`)
- wrong `app_working_directory`
- wrong `install command` (use `npm ci` where `package-lock.json` exists)

### 3) Java: `invalid target release: 21`

Fix:
- Ensure `actions/setup-java@v4` uses the same version required by your `maven-compiler-plugin`
- Or adjust `inputs.java_version`

### 4) Pytest warnings: unknown mark `e2e`

Add to `pytest.ini`:
```ini
[pytest]
markers =
  e2e: end-to-end tests
```

---

## Recommended repo layout (examples)
- `node-ui-example/` → app under test (optional to start in workflow)
- `java-selenium-runner-example/` → Java Selenium suite
- `python-selenium-runner-example/` → Python Selenium suite

Each runner uses the same reusable workflow; only `working_directory` and `command` change.

---

## Versioning

This doc refers to:
- `brik: e2e-selenium-grid (v1)`

Future versions may add:
- language-specific setup helpers (python/node/dotnet)
- auto-rewriting `localhost` → `host.docker.internal` when remote grid is detected
- richer diagnostics and browser/video exports