# BrikByteOS Build Runtime Support Matrix

<!--
This file is the SINGLE SOURCE OF TRUTH for supported build runtimes.

It is consumed by:
- brik-pipe-docs (this repo) for documentation.
- brik-pipe-cli (via a JSON snapshot) for validation and DX tooling.
- brik-pipe-packs for language-specific build/test templates.
- .github org governance docs for consistency.
- brik-pipe-examples for example repos.

Any runtime/version change MUST go through:
- Platform Lead review
- A governance/ADR entry (e.g., ADR-BUILD-RUNTIMES-001)
-->

> **Scope**  
> This matrix defines the supported build runtimes for **BrikByteOS Pipelines v1**:
> - Node.js  
> - Python  
> - Java  
> - .NET  
> - Go  

> **Support Levels**
> - `supported` – Fully supported in CI templates and packs. Backed by tests and examples.  
> - `experimental` – Available, but not yet battle-tested across products.  
> - `planned` – Future support; may not have full templates yet.

> **Update Cadence**
> - Minimum **quarterly review** (or when upstream LTS changes).
> - Changes should be recorded in an ADR (e.g., `docs/adr/ADR-BUILD-RUNTIMES-001.md`).

---

## 1. Summary Table

This table is for quick human consumption. Machine-readable JSON is maintained alongside this in `brik-pipe-cli/src/assets/runtime-matrix.json`.

| Language | Status      | Min Version | Max Version | Default Build Tool      | Default Build Command                        | Default Test Command                      | Folder Conventions                             | Default Docker Base Image             | Notes |
|---------|-------------|-------------|-------------|-------------------------|----------------------------------------------|--------------------------------------------|------------------------------------------------|--------------------------------------|-------|
| Node.js | supported   | 18.x        | 22.x        | npm (default), pnpm     | `npm ci && npm run build`                    | `npm test` or `npm run test`              | `src/`, `tests/`, `scripts/`                   | `node:20-alpine`                     | Target active LTS lines. Verify against Node LTS schedule. |
| Python  | supported   | 3.10        | 3.12        | `pip` / `uv`            | `pip install -r requirements.txt` or `uv run` | `pytest`                                   | `src/`, `tests/`, `app/`                        | `python:3.11-slim`                  | Prefer 3.11 for new services. |
| Java    | supported   | 17          | 21          | Maven (default), Gradle | `mvn -B clean package`                       | `mvn -B test`                             | `src/main/java`, `src/test/java`               | `eclipse-temurin:17-jdk-alpine`      | 17 as baseline LTS, 21 emerging LTS. |
| .NET    | supported   | 6.0         | 8.0         | dotnet CLI              | `dotnet restore && dotnet build --configuration Release` | `dotnet test --configuration Release` | `src/`, `tests/`                                 | `mcr.microsoft.com/dotnet/sdk:8.0`   | 6.0 & 8.0 LTS. |
| Go      | supported   | 1.21        | 1.23        | go toolchain            | `go build ./...`                             | `go test ./...`                           | `cmd/`, `pkg/`, `internal/`, `test/`           | `golang:1.22-alpine`                | Prefer module-aware builds. |

> ⚠️ **Note:** Version ranges must be validated against current LTS schedules before each official release of BrikByteOS. This document is normative; pipelines and packs must conform to it.

---

## 2. Per-Language Details

### 2.1 Node.js

- **Status:** `supported`
- **Preferred LTS:** 20.x
- **Version Range:** 18.x – 22.x  
  - 18.x: maintained for legacy services.  
  - 20.x: default for new services.  
  - 22.x: early adoption allowed where needed.

**Canonical Commands**

- Build:  
    ```bash
    npm ci && npm run build
    ```
- Test:
    ```bash
    npm test
    # or
    npm run test
    ```

**Folder Conventions**
- Application code: `src/`
- Tests: `tests/`
- Helper scripts: `scripts/`

**Default Docker Base Image**
- `node:20-alpine`

**Notes**
- New Node services SHOULD be scaffolded with 20.x.
- 16.x and below are considered **deprecated** and SHOULD NOT be used in new templates.

---

### 2.2 Python
- **Status:** `supported`
- **Version Range:** 3.10 – 3.12

**Canonical Commands**
- Install + build/setup:
    ```bash
    pip install -r requirements.txt
    # or for uv-based projects:
    uv sync
    ```
- Tests:
    ```bash
    pytest
    ```

**Folder Conventions**
- Application code: `src/` or `app/`
- Tests: `tests/`

**Default Docker Base Image**
- `python:3.11-slim`

**Notes**
- 3.11 is recommended for new projects (performance improvements).
- 3.9 and below are not supported in v1 templates.

---

### 2.3 Java
- **Status:** `supported`
- **Version Range:** 17 – 21

**Canonical Commands**
- Maven-based (default):
    ```bash
    mvn -B clean package
    ```

- Tests:
    ```bash
    mvn -B test
    ```

**Folder Conventions**
- Application code: `src/main/java`
- Tests: `src/test/java`
- Resources: `src/main/resources`

**Default Docker Base Image**
- `eclipse-temurin:17-jdk-alpine`

**Notes**
- Java 17 is the default LTS target.
- Java 11 is considered legacy and may be maintained only for already-existing services via explicit overrides.

---

### 2.4 .NET
- **Status:** `supported`
- **Version Range:** 6.0 – 8.0


**Canonical Commands**
- Build:
    ```bash
    dotnet restore
    dotnet build --configuration Release
    ```
- Tests:
    ```bash
    dotnet test --configuration Release
    ```
**Folder Conventions**
- Application code: `src/`
- Tests: `tests/`
- Solution files: `.sln` at root or `src/` root.

**Default Docker Base Image**
- `mcr.microsoft.com/dotnet/sdk:8.0`

**Notes**
- .NET 6.0 and 8.0 are LTS; they are the only versions used in templates by default.

---

### 2.5 Go
- **Status:** `supported`
- **Version Range:** 1.21 – 1.23

**Canonical Commands**
- Build:
    ```bash
    go build ./...
    ```
- Tests:
    ```bash
    go test ./...
    ```

**Folder Conventions**
- Application entrypoints: `cmd/<service-name>/`
- Libraries: `pkg/` and/or `internal/`
- Tests: `_test.go` files colocated; integration tests may live under `test/`

**Default Docker Base Image**
- `golang:1.22-alpine`

**Notes**
- GOPATH-based projects are considered legacy; modules (`go.mod`) are required for BrikByteOS templates.