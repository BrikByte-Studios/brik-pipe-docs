<!--
  =============================================================================
  BrikByteOS — Caching Playbook & Troubleshooting Guide
  -----------------------------------------------------------------------------
  WBS ID: DOC-CACHE-GUIDE-DOCS-006
  Owner : Tech Writer + DevOps
  Scope : Official caching documentation for BrikByteOS CI templates.
  Repos :
    - Implemented in:
        • BrikByte-Studios/.github
    - Referenced by:
        • BrikByte-Studios/brik-pipe-examples (benchmark suite, examples)
  =============================================================================
-->

# BrikByteOS Caching Playbook

> **Audience:** Engineers using BrikByteOS CI templates  
> **Goal:** New engineer should understand cache usage in **\<15 minutes**.

BrikByteOS CI templates use **GitHub Actions cache** + **BrikByte composite actions** to speed up builds across multiple runtimes:

- Node.js
- Python
- JVM (Maven / Gradle)
- Go
- .NET

Caching is an **optimization**, not a dependency:  
> **Builds must never fail _because_ a cache is missing.**

---

## 1. Philosophy & High-Level Overview

- **Cache != Source of Truth**  
  Dependencies, artifacts, and build outputs are still resolved from package managers and source. Cache is only a **snapshot** used to avoid re-downloading or re-compiling.

- **No cache, no problem**  
  On a cache MISS, the build runs as a normal clean build. Pipelines **must not** hard-fail just because a cache key was not found.

- **Version-aware keys**  
  Cache keys include:
  - OS (e.g., `Linux`)
  - Runtime version (Node, Python, Java, Go, .NET)
  - Package manager / tool
  - Lockfile or project descriptor hash (`package-lock.json`, `poetry.lock`, `pom.xml`, `go.sum`, `.csproj`, etc.)

- **Central strategy**  
  The behavior is defined by:

  - `PIPE-CACHE-NODE-BUILD-001`
  - `PIPE-CACHE-PYTHON-BUILD-002`
  - `PIPE-CACHE-JVM-BUILD-003`
  - `PIPE-CACHE-STRATEGY-CONFIG-004`
  - `PIPE-CACHE-BENCHMARK-TEST-005`

---

## 2. How Cache Keys Are Generated

> **Important:** The exact structure is implemented inside composite actions under  
> `BrikByte-Studios/.github/.github/actions/*`.

### 2.1 Node.js — `cache-node-deps`

**Composite action:**

- **Repo:** `BrikByte-Studios/.github`
- **Path:** `.github/actions/cache-node-deps/action.yml`

**Inputs:**

- `node-version`
- `project-path`

**Key pattern (conceptual):**

```text
node-${{ runner.os }}-${{ node-version }}-${manager}-${lockfileHash}
```

Where:
- `manager` ∈ `{ npm, yarn, pnpm }`
- `lockfileHash` is `hashFiles('**/package-lock.json')` or `hashFiles('**/yarn.lock')` etc.

**Cached paths:**
- `~/.npm`
- `.yarn/cache`
- `~/.cache/pnpm` (or pnpm store path)

---

### 2.2 Python — `cache-python-deps`

**Composite action:**
- **Repo**: `BrikByte-Studios/.github`
- **Path**: `.github/actions/cache-python-deps/action.yml`

**Inputs:**
- `python-version`
- `project-path`

**Key pattern (conceptual):**
```text
python-${{ runner.os }}-${{ python-version }}-${tool}-${lockfileHash}
```

Where:
- `tool` ∈ `{ pip, poetry, pipenv }`
- `lockfileHash` from:
  - `requirements*.txt`
  - `poetry.lock`
  - `Pipfile.lock`

**Cached paths (typical):**
- `~/.cache/pip`
- `~/.cache/pypoetry`
- `~/.local/share/virtualenvs` (if applicable)

---

### 2.3 JVM — `cache-java-deps`

**Composite action:**
- **Repo**: `BrikByte-Studios/.github`
- **Path**: `.github/actions/cache-java-deps/action.yml`

**Inputs:**
- `java-version`
- `project-path`

**Key pattern (conceptual):**
```text
jvm-${{ runner.os }}-${{ java-version }}-${tool}-${hashFiles('**/pom.xml', '**/build.gradle*')}
```

**Cached paths:**
- Maven: `~/.m2/repository`
- Gradle: `~/.gradle/caches`

---

### 2.4 Go — `cache-go-deps`

**Composite action:**
- **Repo:** `BrikByte-Studios/.github`
- **Path:** `.github/actions/cache-go-deps/action.yml`

**Inputs:**
- `go-version`
- `project-path`

**Key pattern (conceptual):**
```text
go-${{ runner.os }}-${{ go-version }}-${hashFiles('${project-path}/go.sum')}
```

**Cached paths:**
- `$(go env GOMODCACHE)`
- `$(go env GOCACHE)`

---

### 2.5 .NET — `cache-dotnet-deps`

**Composite action:**
- **Repo:** `BrikByte-Studios/.github`
- **Path:** `.github/actions/cache-dotnet-deps/action.yml`

**Inputs:**
- `dotnet-version`
- `project-path`

**Key pattern (conceptual):**
```text
dotnet-${{ runner.os }}-${{ dotnet-version }}-${hashFiles('**/*.sln', '**/*.csproj', '**/Directory.Packages.props')}
```

**Cached paths:**
- `~/.nuget/packages`
- `~/.dotnet/tools`

---

## 3. Cache Reset & Force Clear Instructions

BrikByteOS provides a central cache clean utility:
- **Repo:** `BrikByte-Studios/.github`
- **Script:** `.github/scripts/cache-clean.sh`
- **Composite action:** `.github/actions/cache-clean/action.yml`

**Guarantee:** `cache-clean.sh` is **idempotent** and will **not fail** if paths don’t exist.

### 3.1 Using the Script Directly
```yaml
- name: Clean Node caches (on demand)
  run: |
    .github/scripts/cache-clean.sh "${HOME}/.npm" "./node_modules"
```

Or, with `CACHE_PATHS`:
```yaml
- name: Clean JVM caches via env
  run: |
    CACHE_PATHS="$HOME/.m2/repository,$HOME/.gradle/caches" \
      .github/scripts/cache-clean.sh
```

### 3.2 Using the Composite Action
```yaml
- name: "Force cache refresh (Node)"
  uses: BrikByte-Studios/.github/.github/actions/cache-clean@main
  with:
    # Comma/newline separated paths
    paths: |
      ${HOME}/.npm
      node-api-example/node_modules
```

### 3.3 Force Refresh Toggle (Template Example)

In some templates you can wire:
```yaml
# in workflow_call:
inputs:
  force-cache-refresh:
    description: "Force cache clear before build"
    required: false
    default: "false"
    type: string

# in job steps:
- name: "Force cache refresh (Node)"
  if: ${{ inputs.force-cache-refresh == 'true' }}
  uses: BrikByte-Studios/.github/.github/actions/cache-clean@main
  with:
    paths: |
      ${HOME}/.npm
      ${{ env.PROJECT_PATH }}/node_modules
```
---

## 4. Performance Expectations

BrikByteOS defines **baseline expectations** for caching:

- **Warm build ≥ 30% faster than cold build**  
Target: `improvement_pct >= 30`.

- **Regression threshold: +25% slower**  
If warm build becomes significantly slower than expected, the **benchmark suite** will mark a **regression** and can:
    - ❌ Fail CI
    - 📝 Open a GitHub issue

### 4.1 Benchmark Suite
**Repo:** `BrikByte-Studios/brik-pipe-examples`
**Workflow:** `.github/workflows/ci-cache-benchmark.yml`
**Script:** `.github/scripts/cache-benchmark.sh`

The benchmark:
- Runs **cold** and **warm** builds
- Outputs JSON under:
```text
.audit/cache-benchmark/<timestamp>-<language>.json
```

- Maintains a Markdown history:
```text
brik-pipe-docs/cache/cache-benchmark-history.md
```

Example JSON metric:
```json
{
  "language": "node",
  "cold_build_ms": 91200,
  "warm_build_ms": 41200,
  "improvement_pct": 54.8,
  "status": "PASS"
}
```

---

## 5. Common Failures & Fixes (Troubleshooting Matrix)

Use this matrix as a quick triage guide.

| Symptom | Likely Cause | Quick Checks | Fix |
|---------|--------------|--------------|-----|
| Cache MISS on every run | Key changed frequently or lockfile missing | Check lockfile exists; compare cache key in logs | Commit lockfile; avoid unnecessary key prefix changes |
| Warm build not faster | Low dependency footprint or minimal work | Compare `cold_build_ms` vs `warm_build_ms` in JSON | Accept small delta, or reduce work executed in CI |
| Build fails with “missing module/package” even after cache | Cache cleaned but dependencies not re-installed | Confirm `make ci` installs deps (`npm ci`, `pip install`, etc.) | Ensure CI pipeline still runs install commands after cache restore |
| “cache-clean.sh not found…” warning | Script not present in repo where called | Confirm `.github/scripts/cache-clean.sh` exists in that repo | Add script or remove cache-clean usage in that repo |
| GitHub issue not created on regression | `issues: write` missing or `gh` not configured | Check workflow `permissions:` block; inspect `gh` step logs | Add `issues: write` permission; ensure using default GITHUB_TOKEN |
| Benchmarks fail with KeyError / missing env | Env variables not exported before Python evaluation | Inspect `cache-benchmark.sh` around env export | Ensure variables are `export`ed before `python - << 'PY'` blocks |

---

## 6. Debug Commands & Log Patterns
### 6.1 Log Markers

Look for these markers in CI logs:
- `[CACHE]` — low-level cache messages (planned usage)
- `[CACHE-CLEAN]` — messages from `cache-clean.sh`
- `[CACHE-BENCH]` — messages from `cache-benchmark.sh`
- `CACHE HIT` / `CACHE MISS` / `PARTIAL RESTORE` / `CACHE REFRESH`

Example GitHub Actions `echo` patterns (from strategy):
```bash
echo "::notice ::[CACHE] HIT for key ${KEY}"
echo "::warning ::[CACHE] MISS for key ${KEY} – running cold build"
echo "::notice ::[CACHE] PARTIAL RESTORE – completing missing deps"
echo "::notice ::[CACHE] REFRESH – uploading new cache snapshot"
```

**Tip:** Use the Actions log search box for `CACHE` or `[CACHE-BENCH]` to quickly locate relevant sections.

### 6.2 Quick Debug Commands

Inside a debug step you can inspect caches:
```yaml
- name: Debug Node cache content
  if: ${{ runner.debug == '1' }}
  run: |
    ls -R "${HOME}/.npm" | head -100 || echo "~/.npm empty or missing"

- name: Debug Python pip cache
  if: ${{ runner.debug == '1' }}
  run: |
    ls -R "${HOME}/.cache/pip" | head -100 || echo "~/.cache/pip empty"
```
---

## 7. When Not to Rely on Cache

Caching is powerful but **not always appropriate**:

1. **Highly volatile dependencies**
   - If your dependency graph changes every commit, cache hit rate will be low.
   - In such cases, caching may add complexity without much benefit.

2. **Stateful or environment-specific artifacts**
   - Do **not** cache artifacts that depend heavily on:
     - Secrets
     - Environment-specific configuration
     - Local dev paths

3. **Debugging build issues**
   - When debugging tricky build problems, run:
     - A job with `cache: false` (e.g. `enable-cache: "false"`)
     - Or manually clean caches via:
```yaml
uses: BrikByte-Studios/.github/.github/actions/cache-clean@main
```

4. **One-off jobs**
   - For rarely used workflows (e.g. release-only jobs), caching might not be worth the complexity.

---

## 8. Example Log “Screenshots”
**Note:** Replace these placeholders with actual screenshots captured from GitHub Actions.

### 8.1 Green Example — Cache Hit & Good Improvement
```text
[CACHE] HIT for key node-Linux-20-npm-<hash>
[CACHE-BENCH] COLD build duration: 91200 ms
[CACHE-BENCH] WARM build duration: 41200 ms
[CACHE-BENCH] Improvement % = 54.8
[CACHE-BENCH] Benchmark status = PASS
```

*Example screenshot placeholder:*

### 8.2 Red Example — Regression
```text
[CACHE] HIT for key python-Linux-3.11-pip-<hash>
[CACHE-BENCH] COLD build duration: 60000 ms
[CACHE-BENCH] WARM build duration: 59000 ms
[CACHE-BENCH] Improvement % = 1.7
[CACHE-BENCH] Benchmark status = FAIL
⚠️  Cache benchmark regression detected for python.
```

*Example screenshot placeholder:*

---

## 9. Summary Checklist

A new engineer should walk away knowing:

- ✅ How cache keys are built per runtime
- ✅ How to **force clear** caches safely
- ✅ How to interpret **HIT / MISS / PARTIAL / REFRESH** logs
- ✅ What performance targets we expect (≥30% improvement)
- ✅ Where to find **benchmark history** & JSON metrics
- ✅ How to debug and when to temporarily ignore caches

For questions or improvements, open an issue in:
- `BrikByte-Studios/.github` → label: `area:caching`, `area:docs`