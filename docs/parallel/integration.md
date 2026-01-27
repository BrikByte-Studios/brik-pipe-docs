# Integration Test Matrices

Integration tests validate system behavior under real dependencies.

Each shard provisions its own lab.

---

## Architecture

```text
Shard → Env → Compose → Seed → Test → Teardown
```

Isolation is mandatory.

---

## Compose Labs

Each shard runs:

`docker-compose.integration.yml`


With isolated volumes.

---

## Env Resolution

Secrets resolved via:

- GitHub secrets
- Vault (future)
- .env (local)

Enforced via:

`provision-integration-env`


---

## Matrix Model

`Shard × Service × Config`


Example:

| Shard | DB | Region |
|-------|----|--------|
| 0 | PG | EU |
| 1 | PG | US |

---

## Health Gates

Services must report:

`healthy`


Before tests start.

Fail-fast.

---

## Outputs
```text
test-artifacts/integration/shards/
test-results.json
.audit/
```

---

## Data Management

Each shard:

- Own DB schema
- Own volumes
- Own seeds

Never share.

---

## Failure Modes

| Type | Cause |
|------|--------|
| Timeout | Bad health check |
| Deadlock | Shared DB |
| Drift | Bad seeds |

---

## Rule

If integration tests interfere,
you violated isolation.