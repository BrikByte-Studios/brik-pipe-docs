# BrikByteOS Parallel Matrix – Overview

**Audience:** Repository owners, QA engineers, CI maintainers  
**Status:** v1 – Foundation  
**Applies to:** Unit, Integration, and E2E pipelines  
**Contract file:** `.brik/parallel.yml`

---

## 1. What This Is

The **BrikByteOS Parallel Matrix Specification** defines a single, standard way for repositories to configure:

- Test sharding  
- Matrix fan-out  
- Parallel execution behavior  
- Retry rules  
- Future dynamic balancing hooks  

It provides a **deterministic, validated contract** that all BrikByteOS pipelines can consume.

---

## 2. The Problem It Solves

Before this contract:

- Each repo invented its own shard variables  
- Workflows expanded matrices differently  
- Configuration errors were only discovered at runtime  
- There was no schema validation  
- Parallelization behavior was inconsistent  

### After adopting this contract

| Goal | Result |
|----|----|
| One place to configure parallelism | `.brik/parallel.yml` |
| Fail fast on bad configs | JSON Schema validation |
| Deterministic sharding | Stable and repeatable |
| Consistent pipelines | Reusable orchestration |
| Safe evolution | Backward-compatible defaults |

---

## 3. Where Configuration Lives

### Repository Level

Each repository MAY include:

```text
.brik/parallel.yml
```


This file is the **single source of truth** for how tests are parallelized.

### Platform Level (provided by BrikByteOS)

| Resource | Purpose |
|-------|--------|
| `parallel.schema.json` | Formal schema validation |
| `parallel.spec.md` | Human-readable contract |
| `validate-parallel-contract` | CI guard action |

---

## 4. Quick Start

### Minimum configuration

To enable parallelization with 4 shards:

**.brik/parallel.yml**

```yaml
version: "parallel.v1"

parallel:
  enabled: true
  shards: 4
```
That is enough for any BrikByteOS pipeline to:
- Enable parallel mode
- Fan out unit tests into 4 shards
- Execute deterministically

---

## 5. Full Example
```yaml
version: "parallel.v1"

parallel:
  enabled: true

  shards: 4

  shard_env:
    index: "BRIK_SHARD_INDEX"
    total: "BRIK_SHARD_TOTAL"

  mode: "static"

  matrix:
    include:
      - kind: "unit"
        shards: 4

      - kind: "e2e"
        browser: "chromium"
        shards: 2

      - kind: "e2e"
        browser: "firefox"
        shards: 2

  retry:
    per_shard: 1
    flaky_mode: "off"

  aggregation:
    enabled: true
    merge_strategy: "simple"
```

---

## 6. Behavior When File Is Missing

If a repository does not include `.brik/parallel.yml`, the system falls back to safe defaults:

| Setting | Default |
|---------|---------|
| parallel.enabled | false |
| shards | 1 |
| matrix | none |
| behavior | serial execution |


### Important

No repository will break by adopting BrikByteOS pipelines without this file.

---

## 7. Determinism Guarantees

All BrikByteOS implementations MUST follow these rules.

### 7.1 Sharding Determinism

Test allocation must be stable:
```matlab
test_index % total_shards == shard_index
```

Requirements:
- Tests are sorted deterministically
- No randomness in shard assignment
- Same config → same shard contents

### 7.2 Matrix Determinism
- `matrix.include` order is authoritative
- No implicit reordering
- Same config → same job order

---

## 8. Validation

Every workflow using this contract should validate it:
```yaml
- uses: BrikByte-Studios/brik-pipe-actions/.github/actions/validate-parallel-contract@main
```

Validation ensures:
- Correct version
- Allowed values
- No impossible matrix combinations

---

## 9. Common Usage Patterns
### 9.1 Unit Tests Only
```yaml
parallel:
  enabled: true
  shards: 6

  matrix:
    include:
      - kind: unit
        shards: 6
```

### 9.2 Browser Matrix for E2E
```yaml
matrix:
  include:
    - kind: e2e
      browser: chromium
      shards: 2

    - kind: e2e
      browser: firefox
      shards: 2
```

### 9.3 Integration Service Subsets
```yaml
matrix:
  include:
    - kind: integration
      subset: payments
      shards: 2

    - kind: integration
      subset: orders
      shards: 2
```

---
## 10. Guardrails

Platform workflows should enforce sensible limits:

| Limit | Value |
|-------|-------|
| Minimum shards | 1 |
| Maximum shards | 16 |
| Maximum total matrix jobs | 32 |


This prevents accidental CI cost explosions.

---

## 11.  Supported Test Types

The contract is intentionally generic and supports:
| Kind | Typical Usage |
|------|---------------|
| `unit` | Fast deterministic tests |
| `integration` | Service-level tests |
| `e2e` | Browser or API flows |

Each stack (Node, Python, .NET, Java, Go) interprets the same contract.

---

## 12.  Future Compatibility

Fields reserved for later phases:
- `history` (dynamic balancing)
- `flaky_mode`
- advanced merge strategies

These are present as forward-compatible hooks but not yet active in v1.

---

## 13. Traceability

This contract supports the following platform governance items:

| Reference | Description |
|-----------|-------------|
| REQ-PIPE-CORE-2.4 | Parallel Test Orchestration |
| ADR-TEST-030 | Parallelization & Sharding Strategy |
| RTM-TEST-PARALLEL-001 | Baseline Performance Targets |

---

## 14.  Related Documents
| Document | Purpose |
|----------|---------|
| `parallel.spec.md` | Formal field definitions |
| `parallel.schema.json` | Machine validation |
| Pipeline docs | How workflows consume the contract |
| Examples repo | Real working samples |

---

## 15. Example Repositories

Reference implementations can be found in:
```perl
brik-pipe-examples/**/.brik/parallel.yml
```

Including:
- node-api-example
- python-api-example
- dotnet-api-example
- playwright-example

---

## 16.  Migration Guide

To adopt the new system:

1. Create `.brik/parallel.yml`
2. Enable validation action
3. Remove custom shard environment variables
4. Let workflows consume the contract

Rollback is simple:

Delete or disable `.brik/parallel.yml`→ pipelines revert to serial mode.

---

## 17.  Support

For questions or enhancements:
- Open an issue in **brik-pipe-actions**
- Reference task: PIPE-CORE-2.4.1

Summary

The Parallel Matrix Specification provides:
- Predictability
- Consistency
- Safety
- Extensibility

It is the foundation for all BrikByteOS parallel test orchestration.