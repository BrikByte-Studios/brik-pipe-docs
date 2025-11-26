# BrikByteOS Build & Test Conventions  
**Doc ID:** PIPE-BUILD-CONVENTIONS-CONFIG-003  
**Scope:** `brik-pipe-examples/*` and all future BrikByteOS services

This document defines the **canonical directory layouts**, **build/test commands**, **build config schema**, and **CI expectations** for all supported runtimes in the BrikByteOS ecosystem.

It is the **single source of truth** for:

- How projects are structured (src, tests, env, output)
- Which commands must exist (`make build`, `make test`, `make ci`)
- How reusable CI templates (in `BrikByte-Studios/.github`) should invoke builds and tests
- How `brikpipe.build.yml` is validated (CLI + CI)

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

5. **Typed configuration**  
   Per-service build/test behavior is declared once in `brikpipe.build.yml` and validated with a central schema.

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

Future services should mirror these layouts, `Makefile` contracts, and `brikpipe.build.yml` usage.

---

## 4. Build Config Schema & Validation (PIPE-BUILD-SCHEMA-TEST-004)

### 4.1 Purpose

Each service defines its build and test behavior in a small, typed config file:

- **`brikpipe.build.yml`** at the project root (or project folder).

This config is validated against a central JSON Schema to ensure:

- Required fields are present (`language`, `runtime_version`, `build_command`, `test_command`, `output_dir`).
- Only allowed languages are used.
- No unexpected top-level keys are introduced.
- CI fails fast on misconfiguration instead of during runtime.

Schema location (in the meta repo):

- `.github/schemas/brikpipe-build.schema.json` (in `BrikByte-Studios/.github`)

---

### 4.2 Example Configs

#### Node.js example (`node-api-example/brikpipe.build.yml`)

```yaml
schema_version: v1
language: node
runtime_version: "20"
build_command: "npm run build"
test_command: "npm test"
output_dir: "dist"

cache_paths:
  - "node_modules"

env_files:
  - ".env"

metadata:
  service_name: "Node API Example"
  owner: "platform"
  tags:
    - "example"
    - "node"
```

#### Python example (`python-api-example/brikpipe.build.yml`)

```yaml
schema_version: v1
language: python
runtime_version: "3.11"
build_command: "python -m py_compile main.py"
test_command: "pytest"
output_dir: "dist"

cache_paths:
  - ".venv"
  - ".cache/pip"

env_files:
  - ".env"

metadata:
  service_name: "Python API Example"
  owner: "platform"
  tags:
    - "example"
    - "python"
```

See other language examples in their respective `*-api-example` folders.

---

### 4.3 Local Validation
You can validate your build config **locally** using the shared validator script from the `.github` meta repo.

From your service repo:

```bash
# 1) Clone the meta repo alongside your service (if not already present)
git clone git@github.com:BrikByte-Studios/.github.git .brik-meta

# 2) Install validator dependencies (once)
cd .brik-meta
npm install ajv@^8.17.0 ajv-formats@^3.0.1 yaml@^2.6.0
cd ..

# 3) Run the validator against your config
node .brik-meta/.github/scripts/validate-build-config.mjs \
  --file "brikpipe.build.yml" \
  --schema ".brik-meta/.github/schemas/brikpipe-build.schema.json"
```
Expected behavior:
- **Exit code 0** → config is valid.
- **Exit code 1** → validation failed; errors are printed in a human-readable format, for example:

```text
brikpipe.build.yml is INVALID:
- [/language] must be equal to one of the allowed values
- [/] must have required property 'test_command'
```

If you’re using the published CLI, you can also run:
```bash
npx brik-pipe-cli validate build-config \
  --file "brikpipe.build.yml" \
  --schema ".brik-meta/.github/schemas/brikpipe-build.schema.json"
```

---

### 4.4 CI Behavior
Config validation is enforced in CI via the reusable workflow:
- `.github/workflows/ci-config-validate.yml` (in `BrikByte-Studios/.github`)
**Example usage** from an example repo (`brik-pipe-examples`):

```yaml
# .github/workflows/ci-node-api-example.yml
name: "CI — Node API Example"

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  config-validate:
    uses: BrikByte-Studios/.github/.github/workflows/ci-config-validate.yml@main
    with:
      project-path: "node-api-example"
      config-file: "brikpipe.build.yml"

  ci:
    needs: config-validate
    uses: BrikByte-Studios/.github/.github/workflows/template-node-ci.yml@main
    with:
      node-version: "20"
      project-path: "node-api-example"
```
**CI rules:**
  - If the config is **invalid**, `config-validate` fails and the whole workflow fails.
  - If the config is **missing**, CI fails with a clear message.
  - If the config is **valid**, the language-specific CI job (`ci`) runs as normal.

---

### 4.5 Negative Test Fixtures (`brik-pipe-labs`)
To ensure the validator actually catches bad configs, `brik-pipe-labs` contains
an intentionally invalid fixture, for example:

- `brik-pipe-labs/.invalid/invalid-node-config.yml`
```yaml
schema_version: v1
language: typescript          # ❌ invalid language (not in enum)
runtime_version: "20"
build_command: "npm run build"
# test_command is intentionally omitted        # ❌ missing required field
output_dir: "dist"
```
The labs CI pipeline wires in the same `ci-config-validate` workflow and asserts that this fixture **fails** validation (negative test).

---

### 4.6 Security Notes
Commands (`build_command`, `test_command`) are treated as **opaque strings** with guardrails:
- **No newlines** (schema enforces a single-line string) to reduce multi-line injection surface.
- **Length capped at 512 characters**.

The schema:
  - Validates **structure** and **allowed languages**.
  - Does not attempt to prove that every possible shell command is safe.

Additional safety controls can be layered over time in:
- The validator script itself (e.g. risky-shell-character detection, allow/deny-lists), and/or
- Central **Policy Gates** (e.g. `PIPE-GOV-8.x`).

A security engineer should periodically review:
- The schema (for command injection risk, unsafe patterns).
- The validator implementation and its integration in CI.

---

## 5. Global Layout & Env Conventions
While each runtime has nuances, some global guidelines apply:

### 5.1 Source Code
The **main application code** should live in a clearly identified location:
- `src/` (Node, Java, Go, .NET via `src/<Project>`)
- Language-specific default (e.g., `app/` is allowed but must be documented)

### 5.2 Tests
- Tests must live in a dedicated test tree:
  - `tests/` (Node, Python, Go)
  - `src/test/java` (Java)
  - `tests/<Project.Tests>` (.NET)

### 5.3 Environment Configuration
- Use **explicit, versioned env config where possible:**
  - `.env` for simple key/value environments
  - `appsettings.json` / `appsettings.Development.json` for .NET
  - `application.properties` / `application.yaml` for Spring Boot
- **Secrets** are never committed; use CI secrets and environment variables.

### 5.4 Build Output
- Build artifacts should go into conventional locations:
  - Node: `dist/`
  - Python: `dist/` and `build/`
  - Java: `target/` (Maven) or `build/` (Gradle)
  - Go: `bin/` or `build/` (when applicable)
  - .NET: `**/bin/Release/`

---

## 6. Runtime-Specific Conventions
### 6.1 Node.js
**Example Repo:** `node-api-example/`

**Layout**  
```text
node-api-example/
  package.json
  package-lock.json
  src/
    index.js
  tests/
    *.test.js (or *.spec.js)
  dist/              # build output
  Makefile
  brikpipe.build.yml
```

**Required Scripts** in `package.json`
```json
{
  "scripts": {
    "build": "mkdir -p dist && cp -r src dist/",
    "test": "node ./tests/index.test.js || echo \"replace with real test runner\" && exit 0"
  }
}
```
In real services, `test` should use a proper test runner (e.g. Jest, Vitest).

**Makefile Contract**  
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
**CI Integration**  
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
---
### 6.2 Python
**Example Repo:** `python-api-example/`  
**Layout**  
```text
python-api-example/
  main.py
  requirements.txt
  tests/
    test_health.py
  dist/              # optional, created by build
  build/             # optional, created by build
  Makefile
  brikpipe.build.yml
```
**Requirements**  
`requirements.txt` contains runtime + test deps, for example:
```text
fastapi
uvicorn
pytest
httpx
```
**Makefile Contract**  
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
**CI Integration**  
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
---

### 6.3 Java (Maven/Gradle)
**Example Repo:** `java-api-example/`

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
  brikpipe.build.yml
```
`pom.xml`uses Spring Boot parent to manage plugin & dependency versions.

**Makefile Contract**
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
**CI Integration**
Reusable workflow: `.github/workflows/template-java-ci.yml`
- Inputs:
  - `java-version` (default: `"17"`)
  - `distribution` (default: `"temurin"`)
  - `enable-cache` (default: `"true"`)
  - `project-path` (e.g. `"java-api-example"`)
- Detects build tool (Maven vs Gradle) in `project-path`
- Runs `make ci` from `project-path`

**Usage example:**

```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-java-ci.yml@main
    with:
      java-version: "17"
      distribution: "temurin"
      project-path: "java-api-example"
```
---

### 6.4 Go
**Example Repo:** `go-api-example/`

**Layout**
```text
go-api-example/
  go.mod
  main.go
  health_handler.go
  health_handler_test.go
  bin/         # optional: custom binaries
  build/       # optional: custom output
  Makefile
  brikpipe.build.yml
```
Single-module Go service with test files `*_test.go`.

**Makefile Contract**
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
**CI Integration**
Reusable workflow: `.github/workflows/template-go-ci.yml`
- Inputs:
  - `go-version` (default: `"1.22.x"`)
  - `project-path` (e.g. `"go-api-example"`)
- Behavior:
  - Ensures `go.mod` exists at `project-path`
  - Uses `cache-dependency-path: project-path/go.sum`
  - Runs `make ci` from `project-path`
  
**Usage example:**
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-go-ci.yml@main
    with:
      go-version: "1.22.x"
      project-path: "go-api-example"
```
---

### 6.5 .NET
**Example Repo:** `dotnet-api-example/`

**Layout**
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
  brikpipe.build.yml
```
**Makefile Contract**  
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
**CI Integration**
Reusable workflow: `.github/workflows/template-dotnet-ci.yml`
- Inputs:
  - `dotnet-version` (default: `"8.0.x"`)
  - `project-path` (e.g. `"dotnet-api-example"`)
- Behavior:
  - Verifies `.sln` or `.csproj` exists at `project-path`
  - Executes `make ci` from `project-path`
  - Uploads TRX test results and Release binaries as artifacts

**Usage example:**
```yaml
jobs:
  ci:
    uses: BrikByte-Studios/.github/.github/workflows/template-dotnet-ci.yml@main
    with:
      dotnet-version: "8.0.x"
      project-path: "dotnet-api-example"
```
---

## 7. CI Contract Summary
All reusable workflows in `BrikByte-Studios/.github/.github/workflows` must:
1. **Accept a `project-path` input**
   - Default `"."`, but examples use subfolders (`node-api-example`, etc.)

2. **Verify project structure**
   - e.g. `package.json`, `requirements.txt`, `pom.xml`, `go.mod`, `.sln/.csproj`
3. **Call `make ci` from the `project-path` only**
  - No direct language-specific commands inside YAML
  - Exceptions must be justified in an ADR
4. **Upload standard artifacts, if applicable**
  - Node: `dist/`
  - Python: `dist/`, `build/`
  - Java: `target/**/*.jar`, `build/libs/**/*.jar`
  - Go: `bin/`, `build/`
  - .NET: `**/bin/Release/**`, `**/TestResult*.trx`
5. **Run config validation (where applicable)**
  - Use `ci-config-validate.yml` before language-specific CI.
  - Treat failing validation as a **hard gate**.

---

## 8. Definition of Done
(for PIPE-BUILD-CONVENTIONS-CONFIG-003 & PIPE-BUILD-SCHEMA-TEST-004)

For each example repo:
- `make build` succeeds on a clean checkout.
- `make test` succeeds on a clean checkout.
- `make ci` runs the full pipeline and matches CI behavior.
- `brikpipe.build.yml` exists and passes schema validation.
- Directory structure matches the conventions defined in this document.
- Example CI workflows:
  - Call `config-validate` first.
  - Call only `make ci` (or at most `make build` / `make test` explicitly).
  - Do not duplicate logic from Makefiles or from `brikpipe.build.yml`.

---

## 9. FAQs
### Q: Can a service add more Make targets?  
Yes. `build`, `test`, and `ci` are required.  
You may add others (`lint`, `format`, `coverage`, etc.) as needed.

### Q: What if a legacy service cannot conform to these directories?
- New services **must** conform.
- Legacy services should add a migration plan and, at minimum:
  - Provide a Makefile that wraps whatever structure they currently use.
  - Ensure `make ci` behaves like the runtime matrix + templates expect.
  - Add `brikpipe.build.yml` and keep it schema-compliant.

### Q: Where do I add environment-specific details?
- Use:
  - `.env` (Node/Python/Go)
  - `application-*.properties` (Java)
  - `appsettings.*.json` (.NET)
- Document any deviations in the service’s `README.md`.

### Q: How do I know if my build config is safe?
- The schema:
  - Enforces structure, types, allowed languages, and basic string rules.
  - Does **not** fully validate shell safety.
- For additional safety:
  - Follow BrikByteOS **Policy Gates** and secure coding guidelines.
  - Avoid chaining multiple risky shell constructs inside a single command.
  - Keep commands small and explicit; prefer `npm test`, `pytest`, etc. over long inline pipelines.