# 🔐 Integration Secrets & Environment Provisioning (BrikPipe)

**Document Type:** Security Standard  
**Applies To:** All BrikPipe integration test pipelines  
**Owner:** BrikByteOS Security + Platform Engineering  
**Last Updated:** 2025-12-09  
**Status:** Active  

---

## 1. Purpose

This document defines the **official security standard** for managing **secrets and environment variables used in BrikPipe containerized integration tests**.

It ensures that:

- ❌ No secrets are hardcoded in repositories  
- ❌ No secrets appear in CI logs  
- ✅ Secrets are injected **only via GitHub Environments & Secrets**  
- ✅ A single, enforced naming convention exists  
- ✅ Integration runtimes are **secure-by-default**  

This policy is mandatory for **all repositories using:**

- `integration-test.yml`
- `run-integration-tests.sh`
- `env-generate-integration.sh`

---

## 2. Security Principles

| Principle | Enforcement |
|----------|-------------|
| Secrets never committed | `.env.integ.local` is gitignored |
| Secrets never logged | `::add-mask::` always applied |
| Secrets isolated from prod | Separate `integration` environment |
| Least privilege | Integration secrets ≠ Production secrets |
| Fail fast on missing secrets | Runtime validation enforced |

---

## 3. GitHub Environment Model

### 3.1 Required GitHub Environment

All integration pipelines **must use**:

```yaml
environment: integration
```

This environment must be created in:

- ✅ Each service repo
- ✅ At org level (for shared secrets)

---

### 3.2 Secret Storage Rules
| Location | Purpose |
|----------|---------|
| **Org secrets** | Shared DBs, shared downstream mocks |
| **Repo secrets** | Service-specific credentials |
| **Environment secrets** | Integration-only security isolation |


❌ Production secrets **must never be** reused for integration.

---

## 4. Required Secret Naming Convention

All integration secrets **must start with**:
```nginx
INTEG_
```

**✅ Approved Standard Keys**
```env
INTEG_DB_USER
INTEG_DB_PASS
INTEG_DB_NAME
INTEG_DB_HOST
INTEG_DB_PORT

JWT_SECRET_TEST
```

❌ Any secret **without `INTEG_` prefix is rejected**  
❌ Mixed production/integration names are forbidden

---

## 5. Workflow Injection Pattern

All BrikPipe integration workflows must inject secrets like this:
```yaml
environment: integration

env:
  INTEG_DB_USER: ${{ secrets.INTEG_DB_USER }}
  INTEG_DB_PASS: ${{ secrets.INTEG_DB_PASS }}
  INTEG_DB_NAME: ${{ secrets.INTEG_DB_NAME }}
  INTEG_DB_HOST: ${{ secrets.INTEG_DB_HOST }}
  INTEG_DB_PORT: ${{ secrets.INTEG_DB_PORT }}
  JWT_SECRET_TEST: ${{ secrets.JWT_SECRET_TEST }}
```

❌ No plaintext fallback values are allowed.

---

## 6. Runtime Env File Generation
**Script:**  
`.github/scripts/env-generate-integration.sh`

**Responsibilities**
- ✅ Reads injected GitHub secrets
- ✅ Validates required fields
- ✅ Masks secrets from logs
- ✅ Emits:
```text
.env.integ.runtime
```

✅ Fails fast if any required secret is missing

---

## 7. Example Template File (Committed)

Every service repo **must contain**:
```text
.env.integ.example
```

**✅ Correct Example**
```env
INTEG_DB_USER=
INTEG_DB_PASS=
INTEG_DB_NAME=app_test
INTEG_DB_HOST=localhost
INTEG_DB_PORT=5432

JWT_SECRET_TEST=
```

Rules:
- ✅ Placeholders only
- ❌ Never real values
- ✅ Safe to commit

---

## 8. Local Developer Override (Allowed)

For local dev only:
```lua
.env.integ.local
```

✅ Loaded manually  
✅ Gitignored  
❌ Never used in CI

---

## 9. Log Redaction Enforcement

The following commands are mandatory in `env-generate-integration.sh`:
```bash
echo "::add-mask::$INTEG_DB_PASS"
echo "::add-mask::$JWT_SECRET_TEST"
```

This ensures:
- ✅ Even if echoed → value is hidden
- ✅ GitHub auto-redaction enforced
- ✅ Logs remain audit-safe

---

## 10. Failure Behavior (Security DoD)
| Scenario | Expected Behavior |
|----------|-------------------|
| Secret missing | ❌ Pipeline fails immediately |
| Secret malformed | ❌ Pipeline fails immediately |
| Forked PR | ✅ Secrets NOT injected |
| Secret printed | ✅ Auto-redacted |
| Env not found | ❌ Pipeline blocked |

---

## 11.  Governance & Traceability
| Control | ID |
|----------|----|
| Secrets never committed | REQ-SEC-021 |
| Isolated integration secrets | REQ-SEC-022 |
| Secrets masked in logs | REQ-SEC-023 |

### Test Cases
- TC-SEC-031 — Secrets load without exposure
- TC-SEC-032 — Pipeline fails on missing secret
- TC-SEC-033 — Log masking verified

### Architectural Reference
```text
ADR-00X-integration-secrets-strategy.md
```

---

## 12.  Contingency & Emergency Policy

✅ Temporary **local-only** override allowed:
```bash
.env.integ.local
```

❌ CI never loads local secrets  
❌ CI never bypasses secret validation

If secrets cause CI-wide failure:
- ✅ Integration workflow can be paused
- ❌ Secrets are never downgraded to plaintext

---

## 13.  Repositories Enforced

This policy applies to:
- `BrikByte-Studios/.github`
- `brik-pipe-examples/*`
- All BrikPipe-enabled service repos

---

## ✅ Final Security Posture Achieved
| Risk | Status |
|------|--------|
| Hardcoded secrets | ❌ Eliminated |
| Secret leakage in logs | ❌ Eliminated |
| Mixed prod/integration creds | ❌ Eliminated |
| Drift across repos | ✅ Standardized |
| SOC2 / ISO audit readiness | ✅ Achieved |