# Integration Fixtures & Mocks  
**Path:** `brik-pipe-docs/testing/integration-fixtures-and-mocks.md`  
**Spec ID:** `PIPE-INTEG-FIXTURES-CONFIG-002`

---

## 1. Purpose & Scope

This document standardizes **database fixtures** and **service mocks** for BrikByteOS integration tests across all language examples:

- Node (`node-api-example`)
- Python (`python-api-example`)
- Go (`go-api-example`)
- .NET (`dotnet-api-example`)
- Java (`java-api-example`)

It backs the work item:

> **PIPE-INTEG-FIXTURES-CONFIG-002 – Add DB + Service Mock / Fixture Support**

Goals:

- Every service starts integration tests from a **known, deterministic DB state**.
- External calls are **mocked** (no calls to real payment providers, etc.).
- The **BrikPipe integration runner** can rely on a consistent contract across stacks.
- Integration tests can be run in **containers** (CI) or **locally** with the same semantics.

---

## 2. High-Level Design

### 2.1 Core Concepts

- **DB fixtures**  
  Pre-seeded schema + data for Postgres (and optionally other DBs) that ensure:
  - Required tables exist (e.g., `payments`).
  - At least one row exists so “baseline” tests can verify fixture load success.

- **Service mocks**  
  In-process HTTP servers or mocking libraries that simulate external APIs, e.g.:

  ```text
  POST {EXTERNAL_API_BASE_URL}/external/payment
  -> 200 OK + {"status":"approved","transactionId":"mock-tx-123"}
  ```

- **Environment-driven wiring**  
Services and tests are configured via env vars:

| Variable | Usage |
| --- | --- |
| `APP_BASE_URL` | HTTP base URL for app under test |
| `APP_HEALTH_URL` | Health endpoint for readiness checks |
| `DB_HOST`, `DB_PORT` | DB connection info for fixture tests |
| `DB_USER`, `DB_PASSWORD` | Credentials for fixture DB |
| `DB_NAME` | Database name (e.g., testdb) |
| `EXTERNAL_API_BASE_URL` | External provider base URL (mocked) |

- **Container-oriented**  
The **integration test runner** runs in its own container:
    - `app` container → the service image (Node/Python/Go/.NET/Java).
    - `db` container → Postgres with fixture SQL mounted/executed.
    - optional `cache` container → Redis.
    - `tests` container → runs language-specific integration tests.

---

## 3. Directory & File Conventions
### 3.1 Repo-Level Conventions

For each language example, fixtures and mocks follow these patterns:
```text
<service>/
  brikpipe.build.yml
  Dockerfile
  Makefile
  ...
  tests/                         # language-specific test root
    integration/                 # integration-only tests
      ...                        # integration test files + mocks
```

DB fixture files live under a shared or service-specific folder (implementation can be via mounted volume in the DB container):

```text
tests/integration/fixtures/db/
  postgres/
    001_create_schema.sql
    002_seed_payments.sql
```

**Note:** Exact mount path into the Postgres container is handled by the BrikPipe integration runner and/or docker-compose templates. The requirement is that the repo **exposes** deterministic fixture files.

---

## 4. Database Fixtures (Postgres)
### 4.1 Baseline Contract

All languages rely on the same logical fixtures:
- DB: `testdb` (configurable via env vars).
- User/password: `testuser` / `testpass` (configurable).
- Required table:
```sql
CREATE TABLE IF NOT EXISTS payments (
    id              SERIAL PRIMARY KEY,
    amount_cents    INTEGER NOT NULL,
    currency        VARCHAR(3) NOT NULL,
    status          VARCHAR(32) NOT NULL,
    external_ref    VARCHAR(64),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
- Seed row (minimum):
```sql
INSERT INTO payments (amount_cents, currency, status, external_ref)
VALUES (10000, 'ZAR', 'seeded', 'seed-fixture-1');
```

### 4.2 Fixture Loader Contract

The DB container applies fixtures **before** app/tests run. Typical patterns:
- `docker-entrypoint-initdb.d/*.sql` (for Postgres official image).
- Or `psql` commands executed by the integration runner.

From the perspective of the tests, it is enough to assume:

When tests start, the `payments` table exists and `COUNT(*) > 0`.

### 4.3 Language-Level DB Fixture Tests

Each stack has a **sanity test** that asserts fixtures are correctly applied:

**Go** (`go-api-example/tests/integration/db_fixtures_test.go`)
```go
func TestDBFixturesArePresent(t *testing.T) {
    dbHost := getenv("DB_HOST", "db")
    dbPort := getenv("DB_PORT", "5432")
    dbUser := getenv("DB_USER", "testuser")
    dbPassword := getenv("DB_PASSWORD", "testpass")
    dbName := getenv("DB_NAME", "testdb")

    dsn := fmt.Sprintf(
        "host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
        dbHost, dbPort, dbUser, dbPassword, dbName,
    )

    db, err := sql.Open("postgres", dsn)
    if err != nil {
        t.Fatalf("failed to open DB: %v", err)
    }
    defer db.Close()

    if err := db.Ping(); err != nil {
        t.Fatalf("failed to ping DB: %v", err)
    }

    var count int
    if err := db.QueryRow("SELECT COUNT(*) FROM payments").Scan(&count); err != nil {
        t.Fatalf("failed to query payments table: %v", err)
    }

    if count == 0 {
        t.Fatalf("expected at least 1 seeded payment row, got %d", count)
    }
}
```

**.NET** (`DotNetApiExample.IntegrationTests.DbFixturesTests`)
```csharp
[Fact]
[Trait("Category", "Integration")]
public async Task PaymentsTable_ShouldContainSeededRows()
{
    var host = GetEnvOrDefault("DB_HOST", "db");
    var port = GetEnvOrDefault("DB_PORT", "5432");
    var user = GetEnvOrDefault("DB_USER", "testuser");
    var password = GetEnvOrDefault("DB_PASSWORD", "testpass");
    var name = GetEnvOrDefault("DB_NAME", "testdb");

    var connectionString =
        $"Host={host};Port={port};Username={user};Password={password};Database={name};";

    await using var conn = new NpgsqlConnection(connectionString);

    try
    {
        await conn.OpenAsync();
    }
    catch (Exception ex)
    {
        throw new InvalidOperationException(
            $"Failed to open Postgres connection ({host}:{port}/{name})", ex);
    }

    await using var cmd = new NpgsqlCommand("SELECT COUNT(*) FROM payments", conn);
    var result = await cmd.ExecuteScalarAsync();

    Assert.NotNull(result);
    var count = Convert.ToInt32(result);
    Assert.True(count > 0, $"Expected at least 1 seeded payment row, got {count}");
}
```

Node, Python, Java can mirror this pattern as needed using their respective DB clients; the requirement is **at least one fixture check per stack**.

---

## 5. Service Mocks (External Payment Provider)
### 5.1 Contract

All examples use a common external endpoint contract:
- **Base URL**: `EXTERNAL_API_BASE_URL` (env var)
- **Path**: `/external/payment`
- **Method**: `POST`
- **Request body**: at minimum `{ "amount": <number>, "currency": "ZAR" }`
- **Mock response**:
```json
{
  "status": "approved",
  "transactionId": "mock-tx-123"
}
```

Integration tests assert:
- App calls **the mocked provider**, not a real upstream.
- App’s **/payments** endpoint returns the same approved payload (directly or synthesized).

---

## 6. Language-Specific Patterns
### 6.1 Node

**Key idea:** Run the app in a container; use either a **local mock server** (e.g. `nock`, `msw`, or custom `http.createServer`) or a dedicated mock container wired via `EXTERNAL_API_BASE_URL`.

Example shape (test code, conceptual):
```js
// tests/integration/test_external_api.integration.test.js
import test from "node:test";
import assert from "node:assert/strict";
import axios from "axios";

// pseudo: start local mock server OR rely on mock container
// set EXTERNAL_API_BASE_URL accordingly

test("creates payment using mocked provider", async (t) => {
  const appBaseUrl = process.env.APP_BASE_URL ?? "http://app:8080";

  const resp = await axios.post(`${appBaseUrl}/payments`, {
    amount: 100,
    currency: "ZAR",
  });

  assert.equal(resp.status, 200);
  assert.equal(resp.data.status, "approved");
  assert.equal(resp.data.transactionId, "mock-tx-123");
});
```

Node fixture support is primarily **DB-agnostic** at the Node layer; Postgres fixtures are applied at the DB container level.

---

### 6.2 Python

**Key idea**: Use `responses` to stub external HTTP calls and let the app read `EXTERNAL_API_BASE_URL`.

**Mock helper**
```python
# tests/integration/mocks/external_api_mocks.py
import responses
import re

def mock_external_payment():
    responses.add(
        responses.POST,
        re.compile(r"https://api\.example\.com/external/payment"),
        json={"status": "approved", "transactionId": "mock-tx-123"},
        status=200,
    )
```

**Integration test**
```python
# tests/integration/test_external_payment.py
import os
import re

import pytest
import requests
import responses

from tests.integration.mocks.external_api_mocks import mock_external_payment

APP_BASE_URL = os.getenv("APP_BASE_URL", "http://localhost:8080")


@pytest.mark.integration
@responses.activate
def test_integration_payment_uses_mocked_provider():
    """
    Verifies that the Python service uses the mocked external provider
    instead of a real API.

    Flow:
      - Test calls APP_BASE_URL /payments
      - Service reads EXTERNAL_API_BASE_URL and calls external provider
      - responses mocks the external provider, not our app.
    """
    os.environ["EXTERNAL_API_BASE_URL"] = "https://api.example.com"

    # Let calls to our app pass through unmocked:
    responses.add_passthru(re.compile(rf"^{re.escape(APP_BASE_URL)}"))

    # Mock external provider:
    mock_external_payment()

    resp = requests.post(
        f"{APP_BASE_URL}/payments",
        json={"amount": 100, "currency": "ZAR"},
        timeout=5,
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "approved"
    assert body["transactionId"] == "mock-tx-123"
```
---

### 6.3 Go

**Key idea:** Use `httptest.Server` to mock the provider; app itself still runs as a container, hit via `APP_BASE_URL`.
```go
// tests/integration/external_payment_integration_test.go
package integration

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

type paymentRequest struct {
	Amount   int    `json:"amount"`
	Currency string `json:"currency"`
}

type paymentResponse struct {
	Status        string `json:"status"`
	TransactionID string `json:"transactionId"`
}

func TestExternalPaymentFlowUsesMock(t *testing.T) {
	// 1) Start mock external provider
	mockServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/external/payment" {
			http.NotFound(w, r)
			return
		}

		resp := paymentResponse{
			Status:        "approved",
			TransactionID: "mock-tx-123",
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer mockServer.Close()

	// 2) Point app at mock
	os.Setenv("EXTERNAL_API_BASE_URL", mockServer.URL)

	// 3) Call /payments on the app container
	appBaseURL := getenv("APP_BASE_URL", "http://app:8080")

	reqBody := paymentRequest{Amount: 100, Currency: "ZAR"}
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		t.Fatalf("failed to marshal request body: %v", err)
	}

	resp, err := http.Post(appBaseURL+"/payments", "application/json", bytes.NewReader(bodyBytes)) //nolint:noctx
	if err != nil {
		t.Fatalf("failed to call /payments: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
	}

	var got paymentResponse
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if got.Status != "approved" || got.TransactionID != "mock-tx-123" {
		t.Fatalf("unexpected payment response: %+v", got)
	}
}
```

---

### 6.4 .NET

**Key idea:** Use **WireMock.Net** to host a mock provider; `EXTERNAL_API_BASE_URL` points at the WireMock server; the app exposes `/payments` endpoint.

**Integration test**
```csharp
[Trait("Category", "Integration")]
public class ExternalPaymentIntegrationTests : IDisposable
{
    private readonly WireMockServer _mockServer;
    private readonly HttpClient _httpClient;
    private readonly string _appBaseUrl;

    public ExternalPaymentIntegrationTests()
    {
        _mockServer = WireMockServer.Start();
        var baseUrl = _mockServer.Urls[0];

        Console.WriteLine($"[MOCK] External API base URL: {baseUrl}");

        _mockServer
            .Given(
                Request.Create()
                       .WithPath("/external/payment")
                       .UsingPost()
            )
            .RespondWith(
                Response.Create()
                        .WithStatusCode(HttpStatusCode.OK)
                        .WithHeader("Content-Type", "application/json")
                        .WithBody(@"{ ""status"": ""approved"", ""transactionId"": ""mock-tx-123"" }")
            );

        Environment.SetEnvironmentVariable("EXTERNAL_API_BASE_URL", baseUrl);

        _appBaseUrl = GetEnvOrDefault("APP_BASE_URL", "http://localhost:8080");
        _httpClient = new HttpClient { BaseAddress = new Uri(_appBaseUrl) };
    }

    [Fact]
    public async Task PaymentsEndpoint_UsesMockedExternalProvider()
    {
        var request = new PaymentRequest
        {
            Amount = 100,
            Currency = "ZAR"
        };

        var response = await _httpClient.PostAsJsonAsync("/payments", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<PaymentResponse>();
        Assert.NotNull(body);
        Assert.Equal("approved", body!.Status);
        Assert.Equal("mock-tx-123", body.TransactionId);

        var logs = _mockServer.LogEntries;
        Assert.NotNull(logs);
        Assert.True(
            logs.Any(),
            "Expected WireMock to receive at least one request to /external/payment."
        );
    }

    public void Dispose()
    {
        _httpClient.Dispose();
        _mockServer.Stop();
        _mockServer.Dispose();
    }

    // … PaymentRequest / PaymentResponse + GetEnvOrDefault helpers …
}
```

Minimal `/payments` endpoint (PoC)
```csharp
// PaymentsEndpoints.cs
public sealed record PaymentRequest(int Amount, string Currency);
public sealed record PaymentResponse(string Status, string TransactionId);

public static class PaymentsEndpoints
{
    public static void MapPaymentsEndpoints(this WebApplication app)
    {
        app.MapPost("/payments", (PaymentRequest request) =>
        {
            var response = new PaymentResponse(
                Status: "approved",
                TransactionId: "mock-tx-123"
            );

            return Results.Ok(response);
        });
    }
}
```

For the PoC, the app doesn’t actually call the external provider; in a full implementation you would inject `HttpClient`, read `EXTERNAL_API_BASE_URL`, and forward the request. The test and endpoint shape are designed so that wiring the real call later won’t break the contract.

---

### 6.5 Java

**Key idea:** Use **MockServer** via Testcontainers (or a plain MockServer instance) to simulate the provider and set a system property for the app config.
```java
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class ExternalApiIntegrationTest {

    @Container
    static MockServerContainer mockServer =
            new MockServerContainer("mockserver/mockserver:5.15.0");

    private MockServerClient mockClient;

    @BeforeAll
    void setupMocks() {
        mockClient = new MockServerClient(mockServer.getHost(), mockServer.getServerPort());

        mockClient
            .when(
                HttpRequest.request()
                    .withMethod("POST")
                    .withPath("/external/payment")
            )
            .respond(
                HttpResponse.response()
                    .withStatusCode(200)
                    .withBody("{\"status\":\"approved\",\"transactionId\":\"mock-tx-123\"}")
            );

        String baseUrl = String.format("http://%s:%d",
                mockServer.getHost(), mockServer.getServerPort());
        System.out.printf("[MOCK] MockServer base URL: %s%n", baseUrl);

        System.setProperty("external.api.base-url", baseUrl);
    }

    @Test
    void contextLoadsAndMocksAreReachable() {
        assertThat(mockServer.isRunning()).isTrue();
    }
}
```
In containerized integration tests, the Java app should read either `external.api.base-url` system property or `EXTERNAL_API_BASE_URL` and call `/external/payment` accordingly.

---

## 7. Integration Runner Behaviour

The BrikPipe integration test runner (`brikpipe/integration-test-runner:latest`) orchestrates:

1. **DB readiness & fixtures**
    - Waits for `db:5432` to be reachable.
    - Assumes fixtures already applied (via `docker-entrypoint-initdb.d` or scripts).
2. **App readiness**
    - Polls `APP_HEALTH_URL` (e.g., `http://app:8080/health`) until:
        - HTTP 200
        - Optional JSON body check (e.g., `{ "status": "ok" }`).
3. **Test execution**
    - Uses `TEST_LANGUAGE` to choose default commands:
        - `node` → `npm test` or `node --test` with integration patterns.
        - `python` → `pytest -m integration`.
        - `go` → `go test -tags=integration ./... -run Integration`.
        - `dotnet` → `dotnet test` in working directory.
        - `java` → `mvn -ntp verify -Pintegration-tests`, etc.
    - Or uses `TEST_COMMAND` override if explicitly provided.
4. **Environment injection**
    - Sets:
        ```text
        APP_BASE_URL
        APP_HEALTH_URL
        DB_HOST
        DB_PORT
        HEALTHCHECK_TIMEOUT
        TEST_LANGUAGE
        SERVICE_WORKDIR
        ```
        so each test suite can connect and run deterministic checks.
---

## 8. Governance & Evidence
### 8.1 Acceptance Criteria (PIPE-INTEG-FIXTURES-CONFIG-002)
- **DB fixtures**
    - Postgres container starts with `payments` table and at least one row.
    - Each language has a **DB fixture check test** that:
        - Connects using env-driven DSN.
        - `SELECT COUNT(*) FROM payments` > 0.

- **Service mocks**
    - External provider is never called in CI; all outbound calls are routed to mocks.
    - Each language has at least one integration test that:
        - Sets `EXTERNAL_API_BASE_URL` to a mock.
        - Calls `/payments` on the app.
        - Asserts approved response and/or mock received at least one request.

- **Runner compatibility**
    - All tests succeed when run via:
        - Language-specific `make ci`.
        - Full container matrix using `brikpipe/integration-test-runner`.

### 8.2 Evidence Paths

Typical evidence produced in CI (varies by stack):
- `out/junit.xml` / `out/junit-unit.xml` / `out/junit-integration.xml`
- Coverage: `coverage.out`, `coverage-unit.out`, `coverage.xml`, `coverage-unit.xml`, `out/coverage.json`
- Logs from mocks: WireMock logs, MockServer logs, printed `[MOCK] ... base URL` lines.
- DB fixture logs: container logs showing `.sql` execution.

These artefacts are consumed by:
- `coverage-gate` action (`PIPE-CORE-2.x`),
- `audit blob sync` (`audit-blob-sync.mjs`),
- and any future **policy-as-code** checks enforcing integration test presence.

---

## 9. Extensibility Notes
- Additional DBs (MySQL, etc.) can be added using the same `fixtures/db/<engine>` pattern.
- Additional external services (e.g., fraud checks, notifications) should:
    - Follow the **env-based base URL** pattern.
    - Be mocked in integration tests using the same approach as the payment provider.
- Future **critical paths** in coverage governance (`tests.yml`) may reference:
    - Fixture test files (`*db_fixtures*`).
    - External payment integration tests (`*external_payment*`, `*PaymentsEndpoint_UsesMocked*`).