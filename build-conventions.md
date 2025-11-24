# BrikByteOS Build & Test Conventions  
**Doc ID:** PIPE-BUILD-CONVENTIONS-CONFIG-003  
**Scope:** brik-pipe-examples/* and all future BrikByteOS services

This document defines the **canonical directory layouts**, **build/test commands**, and **CI expectations** for all supported runtimes in the BrikByteOS ecosystem.

It is the **single source of truth** for:

- How projects are structured (src, tests, env, output)
- Which commands must exist (`make build`, `make test`, `make ci`)
- How reusable CI templates (in `BrikByte-Studios/.github`) should invoke builds and tests

---

## 1. Goals

1. **Deterministic builds**  
   Every service should build and test the same way locally and in CI.

2. **Single entrypoint**  
   CI pipelines and developers use the same small set of commands:
   - `make build`
   - `make test`
   - `make ci`

3. **Predictable layout**  
   New engineers should be able to infer a project’s structure from the runtime.

4. **Runtime Matrix alignment**  
   All commands and versions must align with `runtime-matrix.md` / `runtime-matrix.json`.

---

## 2. Canonical Make Targets

Every BrikByteOS service **MUST** provide the following `Makefile` targets
in its project root:

| Target       | Required | Purpose                                                          |
|--------------|----------|------------------------------------------------------------------|
| `make build` | ✅        | Compile / bundle / package the project                           |
| `make test`  | ✅        | Run the main test suite in a CI-safe way                        |
| `make ci`    | ✅        | Orchestrate the **full CI workflow** (usually build + test)     |

**CI workflows must call only these targets** (preferably `make ci`).

---

## 3. Reference Example Repositories

The following repositories implement these conventions and act as **living examples**:

- **Node.js** — `brik-pipe-examples/node-api-example/`
- **Python** — `brik-pipe-examples/python-api-example/`
- **Java** — `brik-pipe-examples/java-api-example/`
- **Go** — `brik-pipe-examples/go-api-example/`
- **.NET** — `brik-pipe-examples/dotnet-api-example/`

Future services should mirror these layouts and Makefile contracts.

---

## 4. Global Layout & Env Conventions

While each runtime has nuances, some global guidelines apply:

### 4.1 Source Code

- The **main application code** should live in a clearly identified location:
  - `src/` (Node, Java, Go, .NET via `src/<Project>`)
  - Language-specific default (e.g., `app/` is allowed but must be documented)

### 4.2 Tests

- Tests must live in a dedicated test tree:
  - `tests/` (Node, Python, Go)
  - `src/test/java` (Java)
  - `tests/<Project.Tests>` (.NET)

### 4.3 Environment Configuration

- Use **explicit, versioned env config where possible**:
  - `.env` for simple key/value environments
  - `appsettings.json` / `appsettings.Development.json` for .NET
  - `application.properties` / `application.yaml` for Spring Boot
- **Secrets** are never committed; use CI secrets and environment variables.

### 4.4 Build Output

- Build artifacts should go into conventional locations:
  - Node: `dist/`
  - Python: `dist/` and `build/`
  - Java: `target/` (Maven) or `build/` (Gradle)
  - Go: `bin/` or `build/` (when applicable)
  - .NET: `**/bin/Release/**`

---

## 5. Runtime-Specific Conventions

### 5.1 Node.js

**Example Repo:** `node-api-example/`

#### Layout

```text
node-api-example/
  package.json
  package-lock.json
  src/
    index.js
  tests/
    *.test.js (or *.spec.js)
  dist/              # build output (optional until build step is added)
  Makefile
```

**Required Scripts in `package.json`**   
```json
{
  "scripts": {
    "build": "mkdir -p dist && cp -r src dist/",
    "test": "node ./tests/index.test.js || echo \"replace with real test runner\" && exit 0"
  }
}
```

In real services, `test` should use a proper test runner (e.g. Jest, Vitest).

#### Makefile Contract

Located at `node-api-example/Makefile`:
```makefile
# Canonical Build/Test Commands for Node.js
# PIPE-BUILD-CONVENTIONS-CONFIG-003

.PHONY: build test ci

build:
	npm run build

test:
	npm test

ci: build test
```
#### CI Integration  
Reusable workflow: `.github/workflows/template-node-ci.yml`
- Inputs:
  - `node-version` (default: `"20"`)
  - `project-path` (e.g. `"node-api-example"`)
- The job:
  - Verifies `package.json` exists at `project-path`
  - Runs `make ci` from that directory

**Usage in consumer repo:**
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-node-ci.yml@main
    with:
      node-version: "20"
      project-path: "node-api-example"
```

### 5.2 Python

**Example Repo:** `python-api-example/`

#### Layout
```text
python-api-example/
  main.py
  requirements.txt
  tests/
    test_health.py
  dist/              # optional, created by build
  build/             # optional, created by build
  Makefile
```

#### Requirements

`requirements.txt` contains runtime + test deps, for example:
```text
fastapi
uvicorn
pytest
httpx
```

#### Makefile Contract   
`python-api-example/Makefile`:
```makefile
# Canonical Build/Test Commands for Python
# PIPE-BUILD-CONVENTIONS-CONFIG-003

.PHONY: build test ci

build:
	python -m pip install build
	python -m build

test:
	pytest

ci: build test
```

#### CI Integration
Reusable workflow: `.github/workflows/template-python-ci.yml`
- Inputs:
  - `python-version` (default: `"3.11"`)
  - `project-path` (e.g. `"python-api-example"`)
- Behavior:
  - Runs all `run:` steps with `working-directory: project-path`
  - Installs dependencies from `requirements.txt`
  - Sets `PYTHONPATH="$PWD:$PYTHONPATH"`
  - Calls `make ci` in the project path

**Usage in consumer repo:**
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-python-ci.yml@main
    with:
      python-version: "3.11"
      project-path: "python-api-example"
```

### 5.3 Java (Maven/Gradle)

#### Example Repo: `java-api-example/`

Typical Spring Boot structure:
```text
java-api-example/
  pom.xml
  src/
    main/
      java/com/brikbyte/example/JavaApiExampleApplication.java
      java/com/brikbyte/example/controller/HealthController.java
      resources/application.properties
    test/
      java/com/brikbyte/example/HealthControllerTest.java
  target/          # Maven output
  Makefile
```
`pom.xml`

Uses Spring Boot parent to manage plugin & dependency versions
(ensuring no explicit `<version>` needed for Boot starters).

#### Makefile Contract

`java-api-example/Makefile`:
```makefile
# Canonical Build/Test Commands for Java (Maven first, fallback Gradle)
# PIPE-BUILD-CONVENTIONS-CONFIG-003

.PHONY: build test ci

build:
	if [ -f pom.xml ]; then mvn -B clean package; \
	elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then ./gradlew clean build; \
	else echo "No supported Java build tool found"; exit 1; fi

test:
	if [ -f pom.xml ]; then mvn -B test; \
	elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then ./gradlew test; \
	else echo "No supported Java test tool found"; exit 1; fi

ci: build test
```

#### CI Integration

Reusable workflow: `.github/workflows/template-java-ci.yml`
- Inputs:
  - `java-version` (default: `"17"`)
  - `distribution` (default: `"temurin"`)
  - `enable-cache` (default: `"true"`)
  - `project-path` (e.g. `"java-api-example"`)
- Detects build tool (Maven vs Gradle) in `project-path`
- Runs only `make ci` from `project-path`

#### Usage example:
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-java-ci.yml@main
    with:
      java-version: "17"
      distribution: "temurin"
      project-path: "java-api-example"
```

### 5.4 Go

#### Example Repo: `go-api-example/`

#### Layout
```text
go-api-example/
  go.mod
  main.go
  health_handler.go
  health_handler_test.go
  bin/         # optional: custom binaries
  build/       # optional: custom output
  Makefile
```

Single-module Go service with test files `*_test.go`.

#### Makefile Contract

`go-api-example/Makefile`:
```makefile
# Canonical Build/Test Commands for Go
# PIPE-BUILD-CONVENTIONS-CONFIG-003

.PHONY: build test ci

build:
	go build ./...

test:
	go test ./...

ci: build test
```

#### CI Integration

Reusable workflow: `.github/workflows/template-go-ci.yml`
- Inputs:
  - `go-version` (default: `"1.22.x"`)
  - `project-path` (e.g. `"go-api-example"`)
- Behavior:
  - Ensures `go.mod` exists at `project-path`
  - Uses `cache-dependency-path: project-path/go.sum`
  - Runs only `make ci` from `project-path`


#### Usage example:
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-go-ci.yml@main
    with:
      go-version: "1.22.x"
      project-path: "go-api-example"
```

### 5.5 .NET

#### Example Repo: `dotnet-api-example/`

#### Layout
```text
dotnet-api-example/
  dotnet-api-example.sln
  src/
    BrikByte.DotNetApiExample/
      BrikByte.DotNetApiExample.csproj
      Program.cs
      appsettings.json
      appsettings.Development.json
  tests/
    BrikByte.DotNetApiExample.Tests/
      BrikByte.DotNetApiExample.Tests.csproj
      HealthEndpointTests.cs
      GlobalUsings.cs
  Makefile
```

#### Makefile Contract

`dotnet-api-example/Makefile`:
```makefile

# Canonical Build/Test Commands for .NET
# PIPE-BUILD-CONVENTIONS-CONFIG-003

.PHONY: build test ci

build:
	dotnet restore
	dotnet build --configuration Release --no-restore

test:
	dotnet test --configuration Release --no-build --logger trx

ci: build test
```

#### CI Integration

Reusable workflow: `.github/workflows/template-dotnet-ci.yml`
- Inputs:
  - `dotnet-version` (default: `"8.0.x"`)
  - `project-path` (e.g. `"dotnet-api-example"`)
- Behavior:
  - Verifies `.sln` or `.csproj` exists at `project-path`
  - Executes `make ci` from `project-path`
  - Uploads TRX test results and Release binaries as artifacts

#### Usage example:
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-dotnet-ci.yml@main
    with:
      dotnet-version: "8.0.x"
      project-path: "dotnet-api-example"
```
---

## 6. CI Contract Summary

All reusable workflows in `BrikByte-Studios/.github/.github/workflows` must:

1. **Accept a `project-path` input**
     - Default `"."`, but examples use subfolders (`node-api-example`, etc.)

2. **Verify project structure**
    - e.g. `package.json`, `requirements.txt`, `pom.xml`, `go.mod`, `.sln/.csproj`
3. **Call make ci from the project-path only**
    - No direct language-specific commands inside YAML
    - Exceptions must be justified in an ADR

4. **Upload standard artifacts, if applicable**
    - Node: `dist/`
    - Python: `dist/`, `build/`
    - Java: `target/**/*.jar`, `build/libs/**/*.jar`
    - Go: `bin/`, `build/`
    - .NET: `**/bin/Release/**`, `**/TestResult*.trx`

---
## 7. Definition of Done (for PIPE-BUILD-CONVENTIONS-CONFIG-003)

For each example repo:
- `make build` succeeds on a clean checkout
- `make test` succeeds on a clean checkout
- `make ci` runs the full pipeline and matches CI behavior
- Directory structure matches the conventions defined in this document
- Example CI workflows:
  - Call only `make ci` (or at most `make build` / `make test` explicitly)
  - Do not duplicate logic from Makefiles

---

## 8. FAQs
### Q: Can a service add more Make targets?

Yes. `build`, `test`, and `ci` are required.  
You may add others (`lint`, `format`, `coverage`, etc.) as needed.

### Q: What if a legacy service cannot conform to these directories?
- New services **must** conform.
- Legacy services should add a migration plan and, at minimum:
  - Provide a `Makefile` that wraps whatever structure they currently use.
  - Ensure `make ci` behaves like the runtime matrix + templates expect.

### Q: Where do I add environment-specific details?
- Use:
  - `.env` (Node/Python/Go)
  - `application-*.properties` (Java)
  - `appsettings.*.json` (.NET)
- Document any deviations in the service’s `README.md`.