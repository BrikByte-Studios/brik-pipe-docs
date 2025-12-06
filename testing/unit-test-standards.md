<!--
  =============================================================================
  BrikByteOS — Unit Test Standards (Cross-Runtime)
  -----------------------------------------------------------------------------
  WBS ID : PIPE-TEST-UNIT-STANDARDS-INIT-001
  Owner  : QA Automation Lead
  Co-Own : DevOps Engineer
  Repos  :
    - Enforced / consumed by:
        • BrikByte-Studios/brik-pipe-examples (example apps)
        • Product repos that adopt BrikByteOS CI templates
  Purpose:
    Define a mandatory, cross-runtime unit test contract for:
      • Node
      • Python
      • Java (JVM)
      • Go
      • .NET
    so CI can rely on a single `make test` entrypoint per repo.
  =============================================================================
-->

# BrikByteOS Unit Test Standards

> **Goal:** Any engineer should be able to wire unit tests in a new repo in **\<15 minutes** using these conventions only.

BrikByteOS defines a **simple, mandatory contract** for unit tests:

1. Every service repo **MUST expose a `make test` target**.
2. `make test` **MUST call the canonical test runner** for that language.
3. Test layout and naming **MUST follow the conventions in this document**.
4. **Any non-zero exit code from tests MUST fail CI.** This is non-negotiable.

CI templates are then free to just run:

```bash
make test
```

…without needing to know language-specific details.

---
## 1. Global Contract (All Languages)
### 1.1 Required Make Targets

Every repo MUST implement:
```make
test:
	# run the canonical unit test command for this language

ci:
	# (optional) may wrap build + test, but test is always test runner
```

Other targets (`build`, `lint`, `fmt`, etc.) are encouraged but not mandated here.

### 1.2 Test Process Rules
- Tests MUST:
    - Run non-interactively (no prompts, no TTY questions).
    - Exit with:
      - `0` → success
      - `>0` → failure (CI must fail)
- Test runners MUST use their default discovery rules:
    - No hand-curated file lists in YAML.
    - No manual globbing in CI scripts if avoidable.
- CI templates should not call `npm test`, `pytest`, `dotnet test`, etc.  
They call only `make test`, which is defined in the repo.

---

## 2. Node.js Standards
### 2.1 Test Command & Layout
| Field | Standard |
|-------|----------|
| Test command | `npm test` (default) or `pnpm test` |
| Make target | `make test` → runs `npm test` / `pnpm test` |
| Directories | `tests/` or `__tests__/` at repo or project root |
| File pattern | `*.test.js`, `*.spec.js`, `*.test.ts`, `*.spec.ts` |
| Default runner | Node’s built-in test runner or Jest/Vitest/etc.

**Recommended layout:**
```text
node-api-example/
  src/
    index.js
  tests/               # OR __tests__/
    example.test.js
  package.json
  Makefile
```

### 2.2 Example Makefile Stub (Node)
```make
# =============================================================================
# Makefile — Node.js Test Contract (BrikByteOS)
# -----------------------------------------------------------------------------
# Repo   : BrikByte-Studios/brik-pipe-examples (node-api-example)
# Purpose: Provide canonical `make test` entrypoint for CI & local dev.
# =============================================================================

.PHONY: test ci

test:
	@echo "🧪 Running Node.js unit tests via npm test..."
	npm test

ci: test
	@echo "✅ CI test stage (Node) completed."
```

If using `pnpm`, replace `npm test` with `pnpm test` and document that in `README`.

### 2.3 CI Interaction

In `template-node-ci.yml` (in `.github` repo), CI should only do:
```yaml
- name: Run Node CI via Make
  working-directory: ${{ env.PROJECT_PATH }}
  run: |
    echo "🚦 Running Node tests via 'make test'..."
    make test
```
---
## 3. Python Standards
### 3.1 Test Command & Layout
| Field | Standard |
|-------|----------|
| Test command | `pytest` |
| Make target | `make test` → runs `pytest` |
| Directories | `tests/` at project root |
| File pattern | `test_*.py` / `*_test.py` |
| Config | Optional `conftest.py` and/or `pytest.ini` |

**Recommended layout:**
```text
python-api-example/
  app/
    __init__.py
    main.py
  tests/
    test_main.py
  requirements.txt
  Makefile
```

### 3.2 Example `Makefile` Stub (Python)
```make
# =============================================================================
# Makefile — Python Test Contract (BrikByteOS)
# -----------------------------------------------------------------------------
# Repo   : BrikByte-Studios/brik-pipe-examples (python-api-example)
# Purpose: Provide canonical `make test` entrypoint using pytest.
# =============================================================================

.PHONY: test ci

test:
	@echo "🧪 Running Python unit tests via pytest..."
	pytest

ci: test
	@echo "✅ CI test stage (Python) completed."
```

### 3.3 CI Interaction

In template-python-ci.yml:
```yaml
- name: Run Python CI via Make
  working-directory: ${{ env.PROJECT_PATH }}
  run: |
    echo "🚦 Running Python tests via 'make test'..."
    make test
```
---
## 4. Java (JVM) Standards
### 4.1 Test Command & Layout

**Maven projects:**

| Field | Standard |
|-------|----------|
| Test command | `mvn -B test` |
| Make target | `make test` → `mvn -B test` |
| Test src dir | `src/test/java` |
| Naming | `*Test.java`, `*Tests.java` |

**Gradle projects:**

| Field | Standard |
|-------|----------|
| Test command | `./gradlew test` (preferred) or `gradle test` |
| Make target | `make test` → `./gradlew test` |
| Test src dir | `src/test/java` |
| Naming | `*Test.java`, `*Tests.java` |


**Recommended layout (Maven):**
```text
java-api-example/
  src/
    main/java/com/example/App.java
    test/java/com/example/AppTest.java
  pom.xml
  Makefile
```

### 4.2 Example `Makefile` Stub (Java — Maven)
```make
# =============================================================================
# Makefile — Java/Maven Test Contract (BrikByteOS)
# -----------------------------------------------------------------------------
# Repo   : BrikByte-Studios/brik-pipe-examples (java-api-example)
# Purpose: Provide canonical `make test` entrypoint using Maven.
# =============================================================================

.PHONY: test ci

test:
	@echo "🧪 Running Java unit tests via Maven..."
	mvn -B test

ci: test
	@echo "✅ CI test stage (Java/Maven) completed."
```

For Gradle-based examples, replace with `./gradlew test`.

---

## 5. Go Standards
### 5.1 Test Command & Layout
| Field | Standard |
|-------|----------|
| Test command | `go test ./...` |
| Make target | `make test` → `go test ./...` |
| File pattern | `*_test.go` |
| Directory | inline with packages or under `tests/` |

**Recommended layout:**
```text
go-api-example/
  main.go
  main_test.go
  Makefile
```

### 5.2 Example `Makefile` Stub (Go)
```make
# =============================================================================
# Makefile — Go Test Contract (BrikByteOS)
# -----------------------------------------------------------------------------
# Repo   : BrikByte-Studios/brik-pipe-examples (go-api-example)
# Purpose: Provide canonical `make test` entrypoint for go test ./...
# =============================================================================

.PHONY: test ci

test:
	@echo "🧪 Running Go unit tests via 'go test ./...'"
	go test ./...

ci: test
	@echo "✅ CI test stage (Go) completed."
```
---
## 6. .NET Standards
### 6.1 Test Command & Layout
| Field | Standard |
|-------|----------|
| Test command | `dotnet test` |
| Make target | `make test` → `dotnet test` |
| Test projects | One or more `*.csproj` under `Tests/` directory |
| Naming | Something.Tests project naming is recommended |

**Recommended layout:**
```text
dotnet-api-example/
  src/
    MyApi/
      MyApi.csproj
  tests/
    MyApi.Tests/
      MyApi.Tests.csproj
      SomeTests.cs
  Makefile
```

### 6.2 Example `Makefile` Stub (.NET)
```make
# =============================================================================
# Makefile — .NET Test Contract (BrikByteOS)
# -----------------------------------------------------------------------------
# Repo   : BrikByte-Studios/brik-pipe-examples (dotnet-api-example)
# Purpose: Provide canonical `make test` entrypoint using dotnet test.
# =============================================================================

.PHONY: test ci

test:
	@echo "🧪 Running .NET unit tests via 'dotnet test'..."
	dotnet test

ci: test
	@echo "✅ CI test stage (.NET) completed."
```
---

## 7. CI Contract: “We Only Call `make test`”

BrikByteOS CI templates MUST NOT hard-code language-specific test commands.

Templates should:
- Verify project layout (presence of `Makefile`, `tests/`, etc. where appropriate).
- Call:
```bash
make test
```
- Fail on any non-zero exit code.

Minimal example (applies to all `template-*-ci.yml`):
```yaml
- name: Run CI tests via Make
  working-directory: ${{ env.PROJECT_PATH }}
  run: |
    echo "🚦 Running unit tests via 'make test'..."
    make test
```
---

## 8. FAQ / Troubleshooting
### Q1: “My tests are not being discovered”
**Node:**
- Ensure files are under `tests/` or `__tests__/`.
- Use `*.test.js` / `*.spec.js` naming (or update your runner config)..

**Python:**
- Ensure `tests/` directory exists.
- Use `test_*.py` and/or `*_test.py`.
- Check `pytest -q` locally to see what tests are collected.

**Java:**
- For Maven / Gradle, tests should live under `src/test/java`.
- Class names should end in `Test` or `Tests`.

**Go:**
- Use `*_test.go` filenames.
- Ensure `package` name matches the corresponding `*_test.go` packages.

**.NET:**
- Use separate test projects under `tests/` or `Tests/`.
- Ensure `dotnet test` at repo root discovers them (via solution file or nested csproj).

---

## 9. Migration Guidance (Existing Repos)

For legacy repos that don’t follow these standards:

1. **Add a Makefile** at the repo root with a `test`target.
2. Adjust your layout so that the canonical runner (npm / pytest / etc.) discovers tests by default.
3. Update your CI workflow to use only `make test` instead of direct runner commands.
4. Validate locally:
   - Break a single test → ensure `make test` exits non-zero.
   - Fix tests → ensure `make test` exits zero and CI goes green.

Future governance (PIPE-GOV-7.3.2) may enforce these standards via policy checks and reporting.

---
## 10.  Summary
- **One contract:** `make test` per repo.
- **Per-language canonical runner:** `npm / pytest / mvn / go test / dotnet test`.
- **Convention over configuration:** default discovery rules; standard folder layouts.
- **CI simplicity:** templates remain thin and reusable across languages.

For changes or clarifications, open an issue in `BrikByte-Studios/.github` with labels:
- `area:testing`
- `area:standards`
- `area:ci-cd`