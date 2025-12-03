# BrikByteOS Coverage Governance Policy

> **Spec owner:** Governance & QA  
> **Implements:**  
> - [TASK] PIPE-TEST-COVERAGE-INTEG-003 — Coverage collection + export hooks  
> - [TASK] GOV-TEST-COVERAGE-POLICY-004 — Coverage governance coverage gate  
> **Repos:**  
> - Implemented in: `BrikByte-Studios/.github`  
> - Consumed by: Product repos & `brik-pipe-examples/*`

---

## 1. Purpose

This document defines **how BrikByteOS enforces minimum test coverage** using:

- A **normalized coverage report**: `coverage.json`  
- A **repo-local coverage policy file**: `.governance/tests.yml`  
- A **governance gate**: `BrikByte-Studios/.github/.github/workflows/coverage-check.yml`  
  and the composite action `BrikByte-Studios/.github/.github/actions/coverage-gate`

The goal is to turn coverage from a **“nice metric”** into a **governed quality gate** that:

- Ensures **overall coverage never drops below a minimum**.
- Enforces **stricter coverage for critical code paths** (`core/`, `domain/`, etc.).
- Provides **clear failure messages** that show *previous → new → delta* coverage.

---

## 2. High-Level Flow

1. **Tests run** via language-specific workflows (e.g. `test-node.yml`, `test-python.yml`).
2. Each test workflow generates native coverage (e.g. `coverage/coverage-final.json`, `coverage.xml`, `coverage.out`, etc.).
3. The **coverage merge layer** (`coverage-merge.mjs` / `coverage-merge` composite) produces:
   - A **normalized** `out/coverage.json` with (at minimum) overall line coverage.
4. The test job uploads coverage artifacts (native + `coverage.json`) as a CI artifact.
5. The **coverage governance gate** workflow (`coverage-check.yml`) runs on PRs:
   - Downloads coverage artifact.
   - Reads:
     - `coverage.json` (actual current coverage)
     - `.governance/tests.yml` (policy)
     - Optional baseline (`.audit/coverage-baseline.json`)
   - Evaluates thresholds and deltas.
   - **Passes or fails** the PR with a clear message.

On protected branches (e.g. `main`, `release/*`), this gate is configured as a **required status check**.

---

## 3. Coverage Policy File

### 3.1 Location

Each repo that opts into coverage governance must define:

```text
.governance/tests.yml
```

This file is tracked with the code and reviewed like any other config.

### 3.2 Schema (YAML)
```yaml
# .governance/tests.yml

# Minimum overall line coverage (0.0 – 1.0).
# Example: 0.80 = 80%
coverage_min: 0.80

# Minimum line coverage for critical paths (0.0 – 1.0).
# Example: 0.90 = 90%
critical_min: 0.90

# Paths considered "critical" and held to stricter thresholds.
# These are prefix matches on file paths in coverage.json.
critical_paths:
  - "core/"
  - "domain/"

# Paths to ignore when computing aggregates.
# Use this for generated or not-meaningful code.
ignore_patterns:
  - "migrations/"
  - "generated/"
  - "build/"
```
⚠️ Values are **fractions** (0.80), not percentages (80).

### 3.3 Defaults (Org-Wide)
If a repo does not override a field, the **default governance stance** is:
- `coverage_min`: 0.80 **(80%)**
- `critical_min`: 0.90 **(90%)**
- `critical_paths`: `["core/", "domain/"]`
- `ignore_patterns`: `["migrations/", "generated/"]`

Repos may:
- **Tighten** thresholds (e.g. `coverage_min: 0.85`).
- **Add more critical paths** (e.g. `services/payments/`).
- **Extend ignore patterns** for generated code.

Repos **may not** lower thresholds **without governance approval**.

---

## 4. Normalized Coverage Format (`coverage.json`)

`coverage.json` is produced by the coverage merge layer (`coverage-merge.mjs`) and must follow this schema (minimal):
```json
{
  "language": "node | python | java | go | dotnet",
  "tool": "jest+c8 | pytest-cov | jacoco | go-cover | ...",
  "summary": {
    "line": 86.3
  },
  "files": [
    {
      "path": "core/service.ts",
      "line": {
        "covered": 120,
        "total": 130,
        "pct": 92.3
      }
    }
  ],
  "generated_at": "2025-11-20T10:00:00.000Z",
  "meta": {
    "commit": "abc123",
    "ref": "refs/heads/feature/xyz",
    "workflow": "CI — Node API Example",
    "job": "tests",
    "run_id": "123456789"
  }
}
```
Note: Some runtimes may initially only populate `summary.line` and `meta`. Per-file details (`files[]`) can be added progressively.

---

## 5. How the Coverage Gate Evaluates

The governance gate uses `.github/scripts/coverage-check.mjs` (wrapped in the `coverage-gate` composite) to:

1. **Read policy** from `.governance/tests.yml`.
2. **Read current coverage** from `out/coverage.json`.
3. **Optionally read a baseline** from `.audit/coverage-baseline.json`.
4. **Compute**:
   - **Overall coverage**.
   - **Critical path coverage**.
   - **Delta vs previous baseline** (if available).
5. **Enforce thresholds** and exit with appropriate status.


### 5.1 Overall Coverage
- Taken primarily from:
```json
coverage.summary.line
```

- If `summary.line` is missing, the gate may fall back to aggregating `files[]`:
  - Sum all covered lines and totals.
  - `line_pct = covered / total * 100`.
- Ignores files whose path matches any `ignore_patterns`.

### 5.2 Critical Coverage
- Filters `files[]` where `path` starts with any entry in `critical_paths`.
- Computes:
```text
critical_line_pct = sum(covered_critical) / sum(total_critical) * 100
```
- If no files match `critical_paths`, the gate:
  - Logs a warning.
  - Either:
    - Treats critical coverage as “not applicable” (does not block), or
    - Follows a stricter governance stance (configurable in future). 

Initial stance is: **do not block if no critical files are present**, but log this clearly.

Logs a warning.

Either:

Treats critical coverage as “not applicable” (does not block), or

Follows a stricter governance stance (configurable in future).

Initial stance is: do not block if no critical files are present, but log this clearly.

### 5.3 Baseline & Delta
- If `.audit/coverage-baseline.json` exists and contains a previous `summary.line`, the gate will:
  - Read `previous_pct` and compare to `current_pct`.
  - Compute:
```text
delta_pct = current_pct - previous_pct
```
  - Log a message such as:
```text
Overall coverage: 83.2% → 77.5% (Δ -5.7pp) — below minimum 80.0%.
```
If no baseline is found:
- The gate logs:
```text
No prior coverage baseline found; using current coverage only.
```
- Thresholds are still enforced against **current** coverage.

---

## 6. Failure Conditions & Messages

The gate **fails** (exit code ≠ 0) when:

1. **Overall coverage below minimum**
```text
❌ Coverage gate failed: overall coverage 77.3% below minimum 80.0%.
Overall coverage: 83.2% → 77.3% (Δ -5.9pp)
```

2. **Critical coverage below minimum**
```text
❌ Coverage gate failed: critical coverage for core/ 84.0% below minimum 90.0%.
Critical coverage (core/): 92.0% → 84.0% (Δ -8.0pp)
```

3. **Invalid or missing coverage file**
```text
❌ Coverage gate failed: coverage.json not found at out/coverage.json.
Did you run coverage-merge.mjs / coverage-merge action in your tests job?
```

4. **Invalid policy file (malformed YAML / missing keys)**
```text
❌ Coverage gate failed: invalid .governance/tests.yml (missing 'coverage_min').
```

All failures are designed to be **actionable**: developers see _what_ failed, _expected_ vs _actual_, and where to fix it (_tests_ vs _config_).

---

## 7. Wiring the Gate in CI
### 7.1 In Test Workflows (Producer)

Example Node test workflow (`.github/workflows/test-node.yml` in `.github` repo):
- After tests & coverage:
    ```yaml
      - name: Normalize coverage → coverage.json
        uses: BrikByte-Studios/.github/.github/actions/coverage-merge@main
        with:
          language: node
          working-directory: ${{ env.WORKING_DIRECTORY }}
          out: out/coverage.json

      - name: Upload Node coverage artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-node
          path: |
            ${{ env.WORKING_DIRECTORY }}/out/coverage.json
            ${{ env.WORKING_DIRECTORY }}/coverage/
          if-no-files-found: ignore
    ```
### 7.2 In Governance Workflow (Consumer)

Central gate workflow (`BrikByte-Studios/.github/.github/workflows/coverage-check.yml`):
```yaml
name: "BrikByteOS — Coverage Governance Gate"

on:
  workflow_call:
    inputs:
      working-directory:
        default: "."
        type: string
      coverage-file:
        default: "out/coverage.json"
        type: string
      policy-file:
        default: ".governance/tests.yml"
        type: string
      baseline-file:
        default: ".audit/coverage-baseline.json"
        type: string
      coverage-artifact-name:
        default: "coverage-node"
        type: string

jobs:
  coverage-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download coverage artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.coverage-artifact-name }}
          path: .   # restores node-api-example/out/coverage.json, etc.

      - name: Run coverage governance gate
        uses: BrikByte-Studios/.github/.github/actions/coverage-gate@main
        with:
          working-directory: ${{ inputs.working-directory }}
          coverage-file: ${{ inputs.coverage-file }}
          policy-file: ${{ inputs.policy-file }}
          baseline-file: ${{ inputs.baseline-file }}
          node-version: "20"
```

### 7.3 Example Consumer (Node API Example)

In `brik-pipe-examples/.github/workflows/ci-node-api-example.yml`:
```yaml
jobs:
  tests:
    uses: BrikByte-Studios/.github/.github/workflows/test-node.yml@main
    with:
      node-version: "20"
      working-directory: "node-api-example"

  coverage-gate:
    needs: tests
    uses: BrikByte-Studios/.github/.github/workflows/coverage-check.yml@main
    with:
      working-directory: "node-api-example"
      coverage-file: "out/coverage.json"
      policy-file: ".governance/tests.yml"
      baseline-file: ".audit/coverage-baseline.json"
      coverage-artifact-name: "coverage-node"
```

Then configure branch protection for `main` and `release/*` to require the status check:
```text
BrikByteOS — Coverage Governance Gate / coverage-gate
```
---

## 8. Onboarding a Repo to Coverage Governance
1. **Ensure tests + coverage exist**
    - Language-specific workflow wired (`test-node.yml`, `test-python.yml`, etc.).
    - `coverage-merge` is producing `out/coverage.json`.
2. **Add a coverage policy file**
```bash
mkdir -p .governance
cat > .governance/tests.yml << 'EOF'
coverage_min: 0.80
critical_min: 0.90
critical_paths:
  - "core/"
  - "domain/"
ignore_patterns:
  - "migrations/"
  - "generated/"
EOF
```
3. **Wire in the coverage gate**
    - Add a job that uses `coverage-check.yml` as shown above.
    - Ensure it has `needs: tests`.
4. **Configure branch protection**
    - Add the gate job as a required status check on `main` and relevant `release/*` branches.
5. **(Optional) Seed a baseline**
    - After a “good” run, copy `out/coverage.json` into `.audit/coverage-baseline.json` so deltas are meaningful from day one.

---

## 9. FAQs
### Q1. What if coverage.json is missing?

The gate fails with an explicit message pointing to the missing file and reminding you to run `coverage-merge` in the tests job.

### Q2. Can we temporarily relax coverage?

Short answer: **generally no**, but governance can:
- Add a **waiver mechanism** in a future unified policy gate, or
- Approve a temporary lower threshold in `.governance/tests.yml` for specific repos/branches.

All such changes must be reviewed.

### Q3. How do ignore patterns work?

Any file path in `coverage.files[].path` that matches an `ignore_patterns` entry (prefix match or simple substring) is excluded from aggregate calculations. It is still visible in coverage.json for inspection.

### Q4. Does this support multiple languages per repo?

Yes:
- Each language’s test job produces its own `coverage.json`.
- You can:
  - Run separate gates per language, or
  - Later introduce a **multi-language aggregator** if needed.
- For now, the example uses one `coverage.json` per project.

---

## 10.  Future Extensions
- **Unified policy-gate framework** (coverage + lint + static analysis).
- **More sophisticated baseline handling** (e.g. ignoring tiny positive/negative deltas).
- **Rich per-file reporting** back to PR comments (annotating weak areas).
- **Dashboard integration** for cross-repo coverage trends.

---

For implementation details, see:
- `.github/scripts/coverage-merge.mjs`
- `.github/scripts/coverage-check.mjs`
- `.github/actions/coverage-merge`
- `.github/actions/coverage-gate`
- `.github/workflows/test-*.yml`
- `.github/workflows/coverage-check.yml`
- `.github/actions/coverage-gate`