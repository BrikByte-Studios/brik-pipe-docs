# Parallel Testing — Philosophy & Guarantees

This system exists to make test execution:

- Faster
- More predictable
- Auditable
- Scalable

Parallelization is treated as an engineering discipline — not a speed hack.

---

## Core Principles

### 1. Determinism First
All sharding is:

- Input-driven
- Reproducible
- Contract-governed

Same inputs → same shards → same results.

No randomness.

---

### 2. Evidence Over Optimism

Every run produces:

- Per-shard artifacts
- Normalized results
- `.audit/` bundles
- Benchmarks

Speed claims must be provable.

---

### 3. Safe by Default

Guardrails:

- Max shards = 16 (v1)
- Missing shards = fail (default)
- No silent drops
- No “best guess” merges

---

### 4. Contracts > Convention

Parallel behavior is governed by:  
`.brik/parallel.yml`


Never by “tribal knowledge”.

---

## Guarantees

| Area | Guarantee |
|------|-----------|
| Coverage | Every discovered test runs exactly once |
| Isolation | Shards do not share state |
| Recovery | Failed shards are inspectable |
| Audit | Every run is reproducible |
| Scaling | Linear speedup up to infra limits |

---

## Execution Model

```text
PLAN → SHARD → COLLECT → MERGE → BENCHMARK → AUDIT
```

Each stage is observable.

No hidden coupling.

---

## Supported Domains

| Domain | Runner |
|--------|---------|
| Unit | pytest / node:test / junit |
| Integration | docker-compose labs |
| E2E | Playwright / Cypress |
| Load | (planned) |
| Fuzz | (planned) |

---

## Failure Policy

| Scenario | Behavior |
|----------|----------|
| Missing shard | Fail |
| Empty shard | Warn |
| Corrupt output | Fail |
| Partial merge | Fail |

---

## Versioning

This is **v1 contract**.

Breaking changes require:

- ADR
- Migration guide
- Dual support window

---

## Mental Model

Parallel CI is:

> A distributed system with evidence.

Treat it accordingly.

