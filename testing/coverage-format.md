# BrikByteOS Normalized Coverage Format

> **Spec owner:** Governance & QA  
> **Implements:**  
> - [TASK] PIPE-TEST-COVERAGE-INTEG-003 — Coverage collection + export hooks  
> - [TASK] GOV-TEST-COVERAGE-POLICY-004 — Governance coverage gate  
> **Code:**  
> - `BrikByte-Studios/.github/.github/scripts/coverage-merge.mjs`  
> - `BrikByte-Studios/.github/.github/actions/coverage-merge`

---

## 1. Purpose

BrikByteOS standardizes test coverage across languages by emitting a **normalized JSON format** called `coverage.json`.

This document specifies:

- The **required fields** every `coverage.json` MUST contain.
- The **recommended fields** for per-file coverage.
- Language-specific expectations for:
  - Node
  - Python
  - Java (JVM)
  - Go
  - .NET (stubbed initially)
- How producers (test workflows) and consumers (governance gates, auditors) should use this file.

---

## 2. High-Level Overview

### 2.1 Producer → Consumer flow

1. Language-specific test workflow runs (e.g. `test-node.yml`).
2. Native coverage is generated (e.g. `coverage/coverage-final.json`, `coverage.xml`, `coverage.out`).
3. The **coverage merge layer** (`coverage-merge.mjs` + `coverage-merge` composite) runs and emits:

   ```text
   <PROJECT_PATH>/out/coverage.json
   ```
4. The test job uploads this as an artifact (`coverage-<language>-normalized-*`).
5. Governance / audit workflows **consume** `coverage.json`:
    - Coverage gate: `coverage-check.mjs` via `coverage-gate` composite.
    - Future: dashboards, audit bundles, reports.

---

## 3. Canonical JSON Format
### 3.1 Minimal schema (v1, required fields)

Every `coverage.json` MUST contain:
```json
{
  "language": "node",
  "tool": "jest+c8",
  "summary": {
    "line": 86.3
  },
  "generated_at": "2025-11-20T10:00:00.000Z",
  "meta": {
    "commit": "abc123",
    "ref": "refs/heads/main",
    "workflow": "CI — Node API Example",
    "job": "tests",
    "run_id": "123456789"
  }
}
```
**Fields:**
- `language` (string, required)
    - One of: `"node" | "python" | "java" | "go" | "dotnet"` (extensible).
- `tool` (string, required)
    - Short descriptor of the underlying coverage tool(s): e.g. `"jest+c8"`, `"pytest-cov"`, `"jacoco"`.
- `summary` (object, required)
    - `line` (number | null) — overall line coverage % (0–100, one decimal recommended).
- `generated_at` (string, required)
    - ISO 8601 timestamp when `coverage.json` was produced.
- `meta` (object, required)
    - `commit` (string | null) — `GITHUB_SHA`
    - `ref` (string | null) — `GITHUB_REF`
    - `workflow` (string | null) — `GITHUB_WORKFLOW`
    - `job` (string | null) — `GITHUB_JOB`
    - `run_id` (string | null) — `GITHUB_RUN_ID`
    - Additional metadata is allowed.

✅ Governance gates rely primarily on `summary.line` and `meta`.  
✅ If `coverage` cannot be computed, `summary.line` may be null, but the **file must still exist**.

### 3.2 Extended schema (per-file coverage, recommended)

When possible, `coverage.json` SHOULD include per-file entries:
```json
{
  "language": "node",
  "tool": "jest+c8",
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
    },
    {
      "path": "domain/model.ts",
      "line": {
        "covered": 80,
        "total": 100,
        "pct": 80.0
      }
    }
  ],
  "generated_at": "2025-11-20T10:00:00.000Z",
  "meta": {
    "commit": "abc123",
    "ref": "refs/heads/main",
    "workflow": "CI — Node API Example",
    "job": "tests",
    "run_id": "123456789"
  }
}
```

**Fields:**
- `files` (array, optional in v1, recommended for Node/Java/Go in v2+)
    - Each entry:
        - `path` (string, required) — repo-relative path.
        - `line` (object, required)
            - `covered` (integer)
            - `total` (integer)
            - `pct` (number)

ℹ️ Per-file coverage empowers:
- **Critical path coverage checks** (`core/`, `domain/`, etc.).
- **Fine-grained dashboards** and **hotspots**.

For early adopters or where native outputs make it hard, `files` may be omitted; the format is forward-compatible.

---

## 4. Language-Specific Mapping
### 4.1 Node (`language: "node"`)

**Native input (expected):**
- Tooling: `jest + c8` / `Istanbul`.
- File: `coverage/coverage-final.json`.

**Example snippet of native file:**
```json
{
  "total": {
    "lines": {
      "total": 120,
      "covered": 103,
      "pct": 85.83
    }
  },
  "src/core/service.ts": {
    "lines": {
      "total": 50,
      "covered": 46,
      "pct": 92
    }
  }
}
```

**Mapping:**
- `summary.line`:
    - Prefer `data.total.lines.pct` if present.
    - Else aggregate all `file-level lines.covered` and `lines.total`.
- `files[]`:
    - For each `file` entry:
        - `path`: key from the JSON (e.g. `"src/core/service.ts"`).
        - `line.covered`: `lines.covered`
        - `line.total`: `lines.total`
        - `line.pct`: `lines.pct`

**Result (example):**
```json
{
  "language": "node",
  "tool": "jest+c8",
  "summary": { "line": 85.8 },
  "files": [
    {
      "path": "src/core/service.ts",
      "line": { "covered": 46, "total": 50, "pct": 92.0 }
    }
  ],
  "generated_at": "...",
  "meta": { "...": "..." }
}
```

### 4.2 Python (`language: "python"`)

**Native input (expected):**
- Tooling: `pytest` + `pytest-cov`.
- File: `coverage.xml` (Cobertura format).

**Core element:**
```xml
<coverage line-rate="0.83" branch-rate="0.75" ...>
  ...
</coverage>
```

**Mapping:**
- `summary.line`:
    - Parse `<coverage ... line-rate="0.83">`.
    - `line_pct = line-rate * 100 → 83.0`.
- `files[]`: (optional v1)
    - Can be derived from `<class>` and `<line>` elements later.
    - For now, Python may emit `summary-only`.

**Result (summary-only example):**
```json
{
  "language": "python",
  "tool": "pytest-cov",
  "summary": { "line": 83.0 },
  "generated_at": "...",
  "meta": { "...": "..." }
}
```

If `coverage.xml` is missing:
```json
{
  "language": "python",
  "tool": "pytest-cov",
  "summary": { "line": null },
  "generated_at": "...",
  "meta": {
    "reason": "python-coverage-file-missing",
    "python_file": "coverage.xml"
  }
}
```

### 4.3 Java / JVM (`language: "java"`)

**Native input (expected):**
- Tooling: `Jacoco`.
- File (default): `target/site/jacoco/jacoco.xml`
  - Alternate: `target/jacoco-report/jacoco.xml`.

**Core element:**

```xml
<counter type="LINE" missed="10" covered="90" />
```

**Mapping:**

- `summary.line`:
    - Parse `<counter type="LINE" missed="X" covered="Y" />`.
    - `line_pct = covered / total * 100`.
- `files[]`:
    - Can be derived from `<package>`, `<sourcefile>`, etc.
    - Start with summary-only if necessary.

### 4.4 Go (`language: "go"`)

**Native input (expected):**
- Tooling: `go test -coverprofile=coverage.out`.
- File: `coverage.out`.

**Sample:**
```txt
mode: set
example.com/myapp/core/foo.go:11.12,15.2 4 1
example.com/myapp/core/foo.go:17.3,21.10 3 0
```

The format is:
```text
file:startLine.startCol,endLine.endCol numStatements count
```

**Mapping (approximation):**
- Treat each line (after header) as a “segment”.
- `totalSegments += 1` per line.
- `coveredSegments += 1` if `count > 0`.
- `line_pct = (coveredSegments / totalSegments) * 100`.
- `files[]`: can be added in later versions by aggregating per file path (before colon).

### 4.5 .NET (`language: "dotnet"`)

**Status:**
- v1: **stub** support in `coverage-merge.mjs`.
- Coverage file is optional and not yet parsed.

**Current behavior:**

If no `.NET` coverage file is provided:
```json
{
  "language": "dotnet",
  "tool": "dotnet-coverage (stub)",
  "summary": { "line": null },
  "generated_at": "...",
  "meta": {
    "dotnet_file": null
  }
}
```

When we later integrate `coverlet` / `opencover` (or `dotnet test --collect "Code Coverage"`), we will:
- Agree on an input format (e.g. `coverage.cobertura.xml`).
- Implement parsing in `parseDotnetCoverage`.
- Populate `summary.line` and `files[]`.

---

## 5. Error Handling & Resilience

The coverage merge script (`coverage-merge.mjs`) is designed to be non-breaking for test results:

- If a coverage file is missing:
    - Logs a **warning**.
    - Emits `coverage.json` with `summary.line = null` and a `reason` in `meta`.
    - Exits 0 (does not cause the CI job to fail).
- If parsing fails:
    - Logs a **clear error message**.
    - Fails the script with non-zero exit (so teams can fix misconfigurations).
✅ Tests themselves should be the source of failure; coverage merge is primarily a reporting layer.
❗ Governance gates can still choose to fail if summary.line is null (e.g., “no coverage data” is a policy violation).

---

## 6. Producer Guidelines (Test Workflows)

To produce a valid `coverage.json`:
1. **Generate native coverage** using the recommended tools:
    - Node: `jest + c8` → `coverage/coverage-final.json`.
    - Python: `pytest --cov=... --cov-report=xml:coverage.xml`.
    - Java: `Jacoco` integration → `target/site/jacoco/jacoco.xml`.
    - Go: `go test -coverprofile=coverage.out`.
    - .NET: (future) `coverlet`/`opencover`.
2. **Run the merge layer** via composite:
    ```yaml
    - name: Normalize coverage → `coverage.json`
      uses: BrikByte-Studios/.github/.github/actions/coverage-merge@main
      with:
        language: node           # node | python | java | go | dotnet
        working-directory: ./my-project
        out: out/coverage.json
    ```
3. **Upload artifacts**:

    ```yaml
    - name: Upload coverage artifacts
    if: always()
    uses: actions/upload-artifact@v4
    with:
        name: coverage-node
        path: |
        my-project/out/coverage.json
        my-project/coverage/
        if-no-files-found: ignore
    ```
---

## 7. Consumer Guidelines (Governance / Audit)

Consumers (e.g. coverage gate, audit workflows) should:

1. **Read `coverage.json`**.
2. **Treat missing or null `summary.line` as “no coverage”** unless explicitly waived.
3. **Optionally use**:
    - `files[]` for:
        - Critical path checks (`core/`, `domain/`, etc.).
        - Fine-grained reporting.
    - `meta` for:
        - Traceability (commit, branch, workflow, job).
        - Building `.audit` artifacts.

Example consumer — coverage gate CLI:
```bash
node .github/scripts/coverage-check.mjs \
  --coverage-file "out/coverage.json" \
  --policy-file ".governance/tests.yml" \
  --baseline-file ".audit/coverage-baseline.json"
```

---

## 8. Versioning & Evolution
### 8.1 Backwards compatibility
- **New fields are always additive.**
- Existing fields (`language`, `tool`, `summary`, `generated_at`, `meta`) will not be removed or renamed without a major version bump of the format.

### 8.2 Planned enhancements
- Full per-file population for:
    - Python (from Cobertura XML).
    - Java (from Jacoco details).
    - Go (aggregating per file).
    - .NET (once coverage tooling is standardized).
- Optional:
    - Branch coverage in `summary.branch`.
    - Condition coverage in `summary.condition`.
    - Multiple coverage “dimensions” for multi-module repos.

A format version field may be added in future (e.g. `"format_version": 1`), but is not required in v1.

---

## 9. Quick Reference
### Required fields (must exist)
- `language` — string
- `tool` — string
- `summary.line` — number | null
- `generated_at` — ISO 8601 string
- `meta` — object (with at least CI context)

### Recommended fields

- `files[]` with:
    - `path`
    - `line.covered`
    - `line.total`
    - `line.pct`