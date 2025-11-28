# BrikByteOS Pipelines — Kaniko Build Performance Dashboard

> Purpose: Provide a simple, human-readable dashboard to compare **first builds vs cached builds** per service and prove that
> **Kaniko caching is working** for PIPE-CONTAINER-REGISTRY-CONFIG-004.

This dashboard is intended to be **manually updated** whenever we validate build performance for each example service.

---

## 1. How to Use This Dashboard

### 1.1 Scope

We track performance for the following example services in `brik-pipe-examples`:

| Service | Workflow File | Image Name |
|--------|----------------|-----------|
| Node API | `.github/workflows/node-api-use-kaniko.yml` | `ghcr.io/brikbyte-studios/example-node-api` |
| Python API | `.github/workflows/python-api-use-kaniko.yml` | `ghcr.io/brikbyte-studios/example-python-api` |
| Java API | `.github/workflows/java-api-use-kaniko.yml` | `ghcr.io/brikbyte-studios/example-java-api` |
| Go API | `.github/workflows/go-api-use-kaniko.yml` | `ghcr.io/brikbyte-studios/example-go-api` |
| .NET API | `.github/workflows/dotnet-api-use-kaniko.yml` | `ghcr.io/brikbyte-studios/example-dotnet-api` |


All of these call the reusable Kaniko workflow from:

- `BrikByte-Studios/.github/.github/workflows/ci-build-kaniko.yml`

### 1.2 What We Measure

For each service, we measure:

- **Build #1 (cold)**: First run after:
  - Cache is empty or invalidated.
  - Dependencies and layers have not yet been cached.
- **Build #2 (warm)**: Immediate second run with:
  - No code / Dockerfile changes.
  - Same tags and inputs.
  - Kaniko cache enabled and pointing to the configured cache repository.

We then compare:

- **Duration** (HH:MM:SS from GitHub Actions UI).
- **Evidence of cache hits** (from Kaniko logs).
- **Qualitative notes** (e.g. “node_modules restore reused from cache”).

---

## 2. Summary Dashboard

> Update this table whenever you validate a service.  
> Use `TBD` until the measurement is captured.

| Service | Cache Repo | Build #1 Duration (Cold) | Build #2 Duration (Warm) | Delta (Warm – Cold) | Cache Hit Evidence | Last Measured |
|--------|------------|---------------------------|---------------------------|---------------------|--------------------|---------------|
| Node API | `ghcr.io/brikbyte-studios/cache/example-node-api` | 34 | 33 | 1 | ✅ | 2025-11-28T10:12:45Z |
| Python API | `ghcr.io/brikbyte-studios/cache/example-python-api` | 38 | 42 | -4 | ✅ | 2025-11-28T10:16:44Z |
| Java API | `ghcr.io/brikbyte-studios/cache/example-java-api` | 63 | 113 | -50 | ✅ | 2025-11-28T10:16:46Z |
| Go API | `ghcr.io/brikbyte-studios/cache/example-go-api` | 36 | 42 | -6 | ✅ | 2025-11-28T10:16:47Z |
| .NET API | `ghcr.io/brikbyte-studios/cache/example-dotnet-api` | 51 | 47 | 4 | ✅ | 2025-11-28T10:16:49Z |


**Legend:**

- `Cache Hit Evidence`:
  - `☐` = not yet verified
  - `✅` = verified (see per-service notes below)

---

## 3. Measurement Procedure

### 3.1 Pre-conditions

For each service:

1. Ensure the workflow exists and is wired correctly:
   - Example (Node): `.github/workflows/node-api-use-kaniko.yml`
   - Uses `cache_enabled: true` and an explicit `cache_repo`.
2. Confirm that registry and cache repos are reachable:
   - Canonical registry: `ghcr.io`
   - Image & cache repos exist or are creatable:
     - e.g. `ghcr.io/brikbyte-studios/example-node-api`
     - `ghcr.io/brikbyte-studios/cache/example-node-api`
3. Ensure secrets are configured:
   - `REGISTRY_TOKEN` mapped from `GITHUB_TOKEN` or `REGISTRY_PAT`
   - Optional: `REGISTRY_USERNAME` for non-actor auth if needed

### 3.2 Steps to Capture First vs Cached Build

For each service:

1. **Trigger a cold build**
   - Go to **GitHub → Actions → [Service Workflow]**.
   - Trigger via:
     - Commit touching `*-service-example/**`, or
     - `workflow_dispatch` if enabled.
   - Wait for the **first run to complete**.
   - Record:
     - Total duration from the workflow run summary.
     - Key log snippets indicating *no cache* used (or very few hits).
   - Fill in `Build #1 Duration (Cold)` and notes below.

2. **Trigger a warm build**
   - Trigger the **same workflow again** without changing code or Dockerfile.
   - Wait for the **second run to complete**.
   - Record:
     - Total duration.
     - Log lines indicating **cache hits** (see examples below).
   - Fill in `Build #2 Duration (Warm)`, `Delta`, and update `Cache Hit Evidence` to `✅`.

3. **Update this dashboard**
   - Update the summary table.
   - Add or update the per-service section below with:
     - Times.
     - Relevant Kaniko log snippets.
     - Observations.

---

## 4. Per-Service Details & Evidence

> Use these sections to paste actual log snippets and timestamps.

### 4.1 Node API — `example-node-api`

- **Workflow:** `.github/workflows/node-api-use-kaniko.yml`
- **Image:** `ghcr.io/brikbyte-studios/example-node-api`
- **Cache Repo:** `ghcr.io/brikbyte-studios/cache/example-node-api`

**Metrics**

- Build #1 (cold): `TBD`
- Build #2 (warm): `TBD`
- Delta: `TBD`

**Cache Evidence (Kaniko logs)**

Paste key lines when available, e.g.:

```text
INFO[0005] Using cache layer for ghcr.io/.../node:18-alpine
INFO[0012] Using cache layer for /bin/sh -c npm ci --only=production
INFO[0018] Using cache layer for /bin/sh -c npm run build
```
**Notes**
- `TBD`

---

### 4.2 Python API — `example-python-api`

**Workflow:** `.github/workflows/python-api-use-kaniko.yml`

**Image:** `ghcr.io/brikbyte-studios/example-python-api`

**Cache Repo:** `ghcr.io/brikbyte-studios/cache/example-python-api`

**Metrics**

- Build #1 (cold): `TBD`
- Build #2 (warm): `TBD`
- Delta: `TBD`

**Cache Evidence (Kaniko logs)**

```text
INFO[0006] Using cache layer for apk add --no-cache python3 ...
INFO[0014] Using cache layer for pip install -r requirements.txt
```
**Notes**
- `TBD`

---

### 4.3 Java API — `example-java-api`

**Workflow:** `.github/workflows/java-api-use-kaniko.yml`

**Image:** `ghcr.io/brikbyte-studios/example-java-api`

**Cache Repo:** `ghcr.io/brikbyte-studios/cache/example-java-api`

**Metrics**

- Build #1 (cold): `TBD`
- Build #2 (warm): `TBD`
- Delta: `TBD`

**Cache Evidence (Kaniko logs)**

```text
INFO[0010] Using cache layer for mvn dependency:go-offline
INFO[0025] Using cache layer for mvn package -DskipTests
```
**Notes**
- `TBD`

---

### 4.4 Go API — `example-go-api`

**Workflow:** `.github/workflows/go-api-use-kaniko.yml`

**Image:** `ghcr.io/brikbyte-studios/example-go-api`

**Cache Repo:** `ghcr.io/brikbyte-studios/cache/example-go-api`

**Metrics**

- Build #1 (cold): `TBD`
- Build #2 (warm): `TBD`
- Delta: `TBD`

**Cache Evidence (Kaniko logs)**

```text
INFO[0003] Using cache layer for go mod download
INFO[0007] Using cache layer for CGO_ENABLED=0 GOOS=linux go build -o app .
```
**Notes**
- `TBD`

---

### 4.5 .NET API — `example-dotnet-api`

**Workflow:** `.github/workflows/dotnet-api-use-kaniko.yml`

**Image:** `ghcr.io/brikbyte-studios/example-dotnet-api`

**Cache Repo:** `ghcr.io/brikbyte-studios/cache/example-dotnet-api`

**Metrics**

- Build #1 (cold): `TBD`
- Build #2 (warm): `TBD`
- Delta: `TBD`

**Cache Evidence (Kaniko logs)**

```text
INFO[0008] Using cache layer for dotnet restore
INFO[0016] Using cache layer for dotnet publish -c Release -o /app/publish
```
**Notes**
- `TBD`

---

## 5. Linking to Requirements & Test Cases

This dashboard provides human-verifiable evidence for:
- **REQ-REGISTRY-003** — Kaniko builds SHOULD use caching to improve performance.
- **TC-REGISTRY-CACHE-001** — Second build uses cache and completes faster than the first.

Also indirectly supports:
- CI performance KPIs under `PIPE-CORE-1.2.4`:
    - Decreased build times.
    - Reduced repeated work during deployments.

When filling this dashboard, you can reference:
- GitHub Action run URLs.
- GHCR image and cache repository pages.
- ADRs or policy docs that define canonical registry & caching strategy.