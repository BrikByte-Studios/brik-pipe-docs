# 🧪 BrikPipe Integration Tests

**Version:** 1.0.0  
**Owner:** BrikByte Studios — Engineering Productivity & QA Platform Team  
**Scope:** BrikByteOS Pipelines (PIPE-CORE-2.x)

---

## 1. 🎯 Purpose of Integration Tests

BrikPipe integration tests validate that a **real service container** (Node, Python, Java, Go, .NET, etc.) can:

1. **Start successfully inside a Docker network**
2. **Connect to its dependencies** (DB, cache, brokers)
3. Expose correct **health endpoints**
4. Execute **language-specific integration tests** inside a dedicated test-runner container
5. Work reliably across:
     - Local development
     - CI (GitHub Actions)
     - Pipeline Matrix Testing
     - Pre-release smoke tests

Integration tests sit between:
- **Unit tests** → logic correctness
- **E2E tests** → full-system validation

They ensure **containers behave correctly in isolation**, which is critical for BrikPipe’s **container-matrix** CI.

---

## 2. 🧱 Integration Test Architecture Overview

```bash
┌───────────────────────────────────────────────────────────────┐
│ GitHub Actions Workflow (integration-test.yml)                │
│   - Pulls service image                                       │
│   - Starts DB + Cache containers                              │
│   - Starts service container (app)                            │
│   - Starts test-runner container                              │
│                                                               │
│       ┌───────────────────────────────┐                       │
│       │  brikpipe/integration-test-   │                       │
│       │           runner:latest       │                       │
│       │  Bash script executes:         │                      │
│       │    • DB readiness checks       │                      │
│       │    • App readiness checks      │                      │
│       │    • Language test commands    │                      │
│       └───────────────────────────────┘                       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

Each language service supplies real HTTP endpoints, e.g.:

| Stack | Root | Health |
| --- | --- | --- |
| Node.js | `/` | `/health` |
| Python/FastAPI | `/` | `/health` |
| Go | `/` | `/health` |
| Java (Spring) | `/` | `/actuator/health` or `/health` |
| .NET minimal API | `/` | `/health` |

---

## 3. 📁 Directory Structure (Recommended)
```markdown
repo/
  node-api-example/
    tests/
      integration/
        test_health.js
        test_root.js

  python-api-example/
    tests/
      test_health.py
      test_root.py

  go-api-example/
    integration_test.go

  java-api-example/
    src/test/java/.../IntegrationTests.java

  dotnet-api-example/
    tests/.../Integration/ApiIntegrationTests.cs
```

Integration tests must be:
- runnable via CLI locally
- runnable inside the test-runner container
- NOT requiring external ports (only internal Docker network)

---

## 4. 🧩 The BrikPipe Integration Test Runner

The runner image:
```bash
brikpipe/integration-test-runner:latest
```

Contains:
- Node.js 20
- Python 3.11 + venv support
- Java 17 JDK & JRE
- Go toolchain (CGO disabled to avoid C compiler in CI)
- .NET SDK 8.0
- Bash + curl + nc + health check tools

The workflow injects commands via ENV:

| ENV | Description |
| --- | --- |
| `APP_BASE_URL` | e.g., `http://app:3000` |
| `APP_HEALTH_URL` | e.g., `http://app:3000/health` |
| `DB_HOST` | Usually `db` |
| `CACHE_HOST` | Optional |
| `TEST_LANGUAGE` | node / python / java / go / dotnet |
| `TEST_COMMAND` | Explicit override |
| `SERVICE_WORKDIR` | Folder containing the service |


The runner:
1. `cd $SERVICE_WORKDIR`
2. Waits for DB (TCP)
3. Waits for App (HTTP)
4. Executes correct test command

---

## 5. 🚀 Health Checks (DB + App)
### 5.1 Database readiness

Runner performs:
```yaml
nc -z db 5432
```

(retries until timeout)

### 5.2 App readiness
```bash
curl -fsS http://app:PORT/health
```

Timeout default: **60s**

Both must pass before running tests.

---

## 6. 🔧 Language-Specific Integration Test Behaviours

Below summarizes what the runner does:

---

### 6.1 Node.js
#### Default Command
```arduino
npm run test:integration
```

If missing:
```bash
npm test
```

Requirements:
- `package.json` must exist
- Tests must resolve relative to `SERVICE_WORKDIR`

---

### 6.2 Python

Runner automatically sets:
```bash
export PYTHONPATH="$(pwd):$PYTHONPATH"
```

Default command:
```nginx
pytest -m integration
```

If no tests match → fallback:
```nginx
pytest
```

---

### 6.3 Java

Runner attempts, in order:

1. `./mvnw -B verify -Pintegration-tests`
2. `mvn -B verify -Pintegration-tests`
3. `./gradlew integrationTest`

---

### 6.4 Go

Runner forces **static builds**:
```bash
CGO_ENABLED=0 go test ./... -run Integration
```

Tests must contain **"Integration"** in function name.

---

### 6.5 .NET (C#)

Runner searches for:
```markdown
tests/*IntegrationTests*.csproj
```

If not found:
```bash
dotnet test
```

---

## 7. 📊 Expected Test Output (CI Logs)

Example:
```csharp
[INFO] Waiting for DB...
[INFO] DB is ready after 2s.
[INFO] Waiting for app readiness at http://app:8080/health...
[INFO] App is ready after 0s.
[INFO] Running Python integration tests...
======================= test session starts =======================
collected 2 items
PASSED test_health.py
PASSED test_root.py
```

---

## 8. 🛑 Common Failure Modes
| Symptom | Explanation | Fix |
| --- | --- | --- |
| `404` on health endpoint | Wrong endpoint path | Update input `healthcheck_path` |
| `connection refused` | App not ready | Add startup delay or correct port |
| Python `ModuleNotFoundError` | PYTHONPATH missing | Runner now exports automatically |
| Go CGO errors | No gcc in runner | CGO disabled automatically |
| Java profile not found | Missing `integration-tests` profile | Add correct Maven config |
| .NET cannot connect to host | Tests incorrectly using localhost | Use `APP_BASE_URL` injected into tests |

---

## 9. 🧼 Cleanup Process

Runner performs:
```powershell
docker stop tests app db cache
docker rm -f tests app db cache
docker network rm brikpipe-integ-net
```

Guaranteed to clean even on failure.

---

## 10. 📝 Best Practices for Service Authors
### ✔ Provide a `/health` endpoint

Must return **HTTP 200**.

### ✔ Provide a smoke-test root endpoint

Example:
```css
GET / → { message: "X API Example — BrikByteOS pipelines OK" }
```
### ✔ Name integration tests clearly
- Node: `*.integration.test.js` or mark tests
- Python: use `@pytest.mark.integration`
- Go: function names containing `Integration`
- Java: `IT*` or profile-specific
- .NET: `Integration` folder or class naming convention

### ✔ Keep tests isolated

No external networks.
Use DB + cache via hostnames:
- `db`
- `cache`

---

## 11.  📡 Updating the Integration Test Runner

Runner lives in:
```swift
github.com/BrikByte-Studios/.github/.github/templates/integration-test-runner.Dockerfile
```

When updated:

1. Rebuild:
    ```bash
    docker build -t brikpipe/integration-test-runner:latest .
    ```
2. Push to GHCR if needed.
3. Workflow will automatically pull latest on next CI run.

---

## 12.  🔮 Roadmap: Integration Testing (PIPE-CORE-2.x)
| Version | Feature |
| --- | --- |
| v2.1 | Unified test metadata export |
| v2.2 | Traceability: REQ → TEST → AUDIT mapping |
| v2.3 | Distributed Integration Testing (multi-service) |
| v2.4 | Test Orchestrator with AI insights |
| v2.5 | Flakiness detection & auto-retry engine |
| v2.6 | Integration Load Testing Profile |

---

## 13.  📚 References

- BrikPipe Test Governance: `.governance/tests.yml`
- CI Reusable Workflows: `.github/workflows/integration-test.yml`
- Test Runner Template: `.github/templates/integration-test-runner.Dockerfile`
- Audit Bundles: `.audit/`