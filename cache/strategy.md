---
title: "BrikByteOS Cache Strategy"
slug: "cache-strategy"
description: "Platform-wide cache semantics (HIT / MISS / PARTIAL RESTORE / REFRESH) and recovery patterns for CI pipelines."
tags:
  - cache
  - ci-cd
  - governance
  - reliability
  - brikbyteos
---

# 🧱 BrikByteOS — CI Cache Strategy

> **Task:** `PIPE-CACHE-STRATEGY-CONFIG-004`  
> **Scope:** Platform-wide cache semantics for Node, Python, JVM, Go, .NET and future runtimes.

---

## 1. Why This Document Exists

BrikByteOS uses caching in CI to:

- Reduce **dependency resolution time** (Node, Python, JVM, Go, .NET, …)  
- Reduce **compute cost** and **flake** from external registries  
- Keep builds **deterministic** and **fast** once caches warm up  

But a cache must **never** become a **single point of failure**.

> **Principle:**  
> “A missing or broken cache may slow you down, but must not break a correct build.”

This document defines:

- Cache **states** (`HIT`, `MISS`, `PARTIAL RESTORE`, `REFRESH`)  
- Expected **behavior** in each state  
- Standard **log markers**  
- A small **cache-clean utility** for manual & automated recovery  

---

## 2. Cache States & Semantics

### 2.1 State Table

| State              | When It Occurs                                                                 | Expected Behavior                                                                                     | Log Marker (recommended)                                   |
|--------------------|--------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| `HIT`              | A cache entry for the computed key is fully restored                           | Run build using restored cache; continue normally                                                   | `[CACHE] HIT`                                              |
| `MISS`             | No cache entry exists for the key (first run, rotated key, evicted cache)     | Run **cold build** (full dependency fetch) and **upload new cache**                                 | `[CACHE] MISS`                                             |
| `PARTIAL RESTORE`  | Cache restored but does not contain all expected content (partial files/dirs)  | Re-fetch missing dependencies; allow build to succeed; upload updated cache as **REFRESH**          | `[CACHE] PARTIAL RESTORE`                                  |
| `REFRESH`          | CI has rebuilt dependencies/artifacts and saved a newer snapshot               | Completed new cache snapshot after build; future runs should see `HIT` or `MISS` (if rotated later) | `[CACHE] REFRESH`                                          |

> **Guarantee:**  
> Missing, invalidated, or partially restored caches **must not cause build failures by themselves**.

---

## 3. Behavior Rules

### 3.1 No Cache Found (`MISS`)

- **Symptom**: `actions/cache` finds no entry for the key.
- **Behavior**:
  - Proceed with **cold build** (fresh install/restore).
  - At the end of the job, **save** the new cache snapshot.
- **Log**:

```bash
echo "::notice ::[CACHE] MISS for key ${KEY} – running cold build (no prior cache)."
```

Typical `actions/cache` pattern:
```yaml
- name: Restore cache
  id: cache-restore
  uses: actions/cache@v4
  with:
    path: ${{ env.CACHE_PATHS }}
    key: ${{ env.CACHE_KEY }}
    restore-keys: ${{ env.CACHE_PREFIX }}-

# … install deps / run build …

- name: Save cache (optional if actions/cache is configured for save)
  if: always()
  run: |
    echo "::notice ::[CACHE] REFRESH – build completed, cache snapshot up-to-date."
```

**Important:** cache is a **performance optimization** only.

---

### 3.2 Cache Hit (`HIT`)
- **Symptom:** `steps.cache-restore.outputs.cache-hit == 'true'`.
- **Behavior:**
  - Run build normally; dependencies should resolve quickly.
- **Log**:
```bash
echo "::notice ::[CACHE] HIT for key ${KEY} – using warm cache."
```

Example snippet:
```yaml
- name: Summarize cache state
  shell: bash
  run: |
    if [ "${{ steps.cache-restore.outputs.cache-hit }}" = "true" ]; then
      echo "::notice ::[CACHE] HIT for key ${{ env.CACHE_KEY }}"
    else
      echo "::notice ::[CACHE] MISS for key ${{ env.CACHE_KEY }} – cold build."
    fi
```

---

### 3.3 Partial Restore (`PARTIAL RESTORE`)

GitHub’s `actions/cache@v4` can occasionally restore only **part** of the cached content (e.g., due to path changes or multi-path caches).

- **Detection (best-effort)**:
    - Expected directory exists but is **unusually small** or missing critical subdirectories.
    - Optional: project-specific sanity checks, e.g.:
        - Node: `node_modules` not present, but lockfile exists.
        - JVM: `~/.m2/repository` or `~/.gradle/caches` exists but is effectively empty.
- **Behavior:**
    - Treat as a **warm-ish** build:
        - Run dependency installation (`npm ci`, `poetry install`, `mvn -B verify`, etc.).
        - Let the tool refetch any missing assets.
    - At the end of build, let `actions/cache` update the snapshot → `REFRESH`.
- **Log**:
```bash
echo "::notice ::[CACHE] PARTIAL RESTORE – completing missing dependencies and refreshing cache."
```

**Key rule:** even if partial, the cache must not break the build; it may just be less effective.

---

### 3.4 Cache Refresh (`REFRESH`)

Whenever the dependency/build step completes successfully and new content is written to the cache directory:

- Treat the next save as a **cache refresh** (new snapshot).
- This might be triggered by:
    - Lockfile change (hash difference).
    - TTL/key rotation.
    - Recovery from partial restore or corruption.

**Log example:**
```bash
echo "::notice ::[CACHE] REFRESH – uploaded new cache snapshot for ${KEY}."
```

---

## 4. TTL & Eviction Guidelines

BrikByteOS uses **GitHub Actions cache** as the underlying mechanism, which already enforces:
- **Retention** (default GitHub TTL — subject to org settings).
- **Size limits** per repo/organization.

We add **logical TTL** via **key rotation**:

### 4.1 Key Rotation Patterns
- **Include lockfile hash** and **runtime version**:
    - Node: `node-${{ runner.os }}-${{ node_version }}-${{ manager }}-${ hashFiles('**/package-lock.json', …) }`
    - Python: `python-${{ runner.os }}-${{ python_version }}-${ tool }-${ hashFiles('**/requirements.txt', …) }`
    - JVM: `jvm-${{ runner.os }}-${{ java_version }}-${ tool }-${ hashFiles('**/pom.xml', '**/build.gradle*') }`
    - Go: `go-${{ runner.os }}-${{ go_version }}-${ hashFiles('**/go.sum') }`
    - .NET: `.net-${{ runner.os }}-${{ dotnet_version }}-${ hashFiles('**/*.csproj', '**/*.sln') }`
- **Rotate prefix** when:
    - There’s a major dependency model change (e.g., monolith → monorepo restructure).
    - Cache grows too large or appears polluted.
    - **Example:** add `v2-` prefix to the key seed.
```yaml
env:
  CACHE_KEY: v2-node-${{ runner.os }}-${{ env.NODE_VERSION }}-${{ steps.detect.outputs.manager }}-${{ steps.lock.outputs.hash }}
```

---

### 4.2 Practical Guidelines
- **Short-lived experiments:**
    - Accept smaller benefits; don’t over-optimise caches.
- **Long-lived services:**
    - Use strong keying (runtime + lockfiles).
    - Rotate prefixes only when the dependency graph changes substantially.

---

## 5. Logging Conventions

To keep logs consistent, BrikByteOS recommends these **exact patterns**:
```bash
# HIT
echo "::notice ::[CACHE] HIT for key ${KEY}"

# MISS
echo "::notice ::[CACHE] MISS for key ${KEY} – running cold build."

# PARTIAL RESTORE
echo "::notice ::[CACHE] PARTIAL RESTORE for key ${KEY} – completing missing deps."

# REFRESH
echo "::notice ::[CACHE] REFRESH for key ${KEY} – uploading new snapshot."
```

Runtime-specific composite actions (Node, Python, JVM, Go, .NET) should emit these markers.

---

## 6. Recovery: cache-clean Utility

**Canonical script path:** `.github/scripts/cache-clean.sh`  
**Repo (canonical):** `BrikByte-Studios/.github`

A tiny script that:
- Deletes one or more cache directories (Node, Python, JVM, Go, .NET).
- Is **idempotent** and **safe** to run multiple times.
- Logs what it touched or skipped.

**Usage in CI:**
```yaml
- name: Force cache clean (manual / recovery)
  if: always()
  run: |
    CACHE_PATHS="${HOME}/.npm,${HOME}/.cache/pip" \
      .github/scripts/cache-clean.sh
```

See cache-clean.sh
 for implementation & examples.

---

## 7. Integration with Runtime-Specific Cache Tasks

This strategy underpins:

- `PIPE-CACHE-NODE-BUILD-001` — Node (npm / Yarn / pnpm)
- `PIPE-CACHE-PYTHON-BUILD-002` — Python (pip / Poetry / Pipenv)
- `PIPE-CACHE-JVM-BUILD-003` — JVM (Maven / Gradle)
- `PIPE-CACHE-GO-BUILD-004` — Go modules
- `PIPE-CACHE-DOTNET-BUILD-005` — .NET / NuGet

Each runtime-specific composite action should:

1. **Use these state semantics** (HIT / MISS / PARTIAL RESTORE / REFRESH).
2. **Never hard-fail** solely due to cache absence or partial restore.
3. **Optionally enlist** `cache-clean.sh` when corruption is suspected.

---

## 8. Summary
- Caches are **helpers**, not **requirements**.
- Build correctness wins over cache convenience.
- States are explicit and logged consistently.
- Teams have a **documented escape hatch and a small, safe** script to clean caches when necessary.

When in doubt: **let the build succeed and log loudly**, rather than failing due to cache behavior.