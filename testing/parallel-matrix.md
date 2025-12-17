<!--
File: brik-pipe-docs/testing/parallel-matrix.md
Purpose: BrikByteOS governed parallelization strategy (matrix plan).
Owner: Platform Lead + QA Automation Lead
WBS: PIPE-PARALLEL-MATRIX-INIT-001
-->

# Parallel Matrix Strategy

## Overview

BrikByteOS uses a **governed matrix plan** to parallelize tests in a **deterministic, safe-by-default, cost-controlled** way across repositories.

This strategy defines:
- Standard matrix keys per test type (unit / integration / e2e / performance)
- Default shard counts and hard caps
- Deterministic rules for partitioning work
- A single reusable “Matrix Plan” action that emits `strategy.matrix` JSON

## Goals

- **Predictable CI runtime** (reduce time-to-signal)
- **Cost control** (prevent runaway parallelism)
- **Deterministic outcomes** (stable shard numbering and selection)
- **Portable across repos** (same contract everywhere)
- **Compatible with audit export** (`.audit/` evidence bundles)

## Non-goals

- Auto-tuning shards based on runtime heuristics
- Randomized shuffling to “balance” shards
- Per-repo custom logic baked into the platform runner (repos can override within caps)

---

## Core Principles

### Deterministic
- No randomness.
- Inputs are explicit lists (services, scenarios, browsers) or stable shard indices `1..N`.
- Selection uses stable ordering (e.g., sorted file lists).

### Safe-by-default
- Defaults are conservative.
- Integration/performance use fewer shards due to infra contention risk.

### Governed
- Repos may request overrides, but **platform caps** are enforced centrally.

### Configurable
- Configuration lives in `.github/actions/matrix-plan/parallel-matrix.yml`
- Repos may supply `override_shards` or explicit item lists.

---

## Test Type Strategy

### Matrix strategy per test type

| Test Type | Matrix Key(s) | Parallel Unit | Default Shards | Max Shards | Notes |
|---|---|---|---:|---:|---|
| Unit | `shard` | Test files / projects | 6 | 8 | Cheap, safe, CPU-bound |
| Integration | `item` OR `shard` | Service × scenario | 3 | 4 | DB/infra contention risk |
| E2E | `browser × shard` | Browser × shard | 4 | 6 | Heavy, flake-prone, long-running |
| Performance | `group` OR `shard` | Scenario groups | 1 | 2 | Resource intensive, avoid concurrency |

> Defaults and caps are defined centrally and enforced by the matrix-plan action.

---

## Matrix Inputs and Shapes

The matrix-plan action emits a JSON object compatible with GitHub Actions `strategy.matrix`.

### Unit
**Shape**
```json
{ "shard": [1,2,3,4] }
```

**Semantics**
- Each shard runs a deterministic subset of unit tests.
- The test runner (Makefile) must use `UNIT_SHARD` and `UNIT_SHARD_TOTAL` if sharding is implemented.

---

### Integration

Integration can run in two modes:

**Mode A: Item-based (recommended)**  
**Shape**
```json
{ "item": ["users::happy_path", "payments::declined_card"] }
```

**Semantics**
- Each matrix job executes exactly one integration “item” (service×scenario).
- Item list is provided explicitly (e.g., services_csv + scenarios_csv, or a single items CSV).

**Mode B: Shard-based (fallback)**  
**Shape**
```json
{ "shard": [1,2,3] }
```

**Semantics**
- Each shard executes a deterministic subset of integration items discovered/defined by the repo.
- Used when explicit items are not provided.

**Why 2–4?**
- Parallel integration runs compete for DB, caches, message brokers, and CPU/memory on shared runners.
- A small shard count avoids “infra thrash” and false negatives.

---

### E2E
**Shape**
```json
{ "browser": ["chromium","firefox"], "shard": [1,2,3,4] }
```
**Semantics**
- Cross-product matrix: browser × shard.
- Each job runs a deterministic subset of E2E tests for a given browser.
- Avoids mixing cross-browser failures.

---

### Performance

Performance tests run in two modes:

**Mode A: Group-based (recommended)**  
**Shape**
```json
{ "group": ["smoke", "baseline"] }
```

**Semantics**
- Each matrix job runs exactly one scenario group.
- Group definitions live in the repo (`tests/performance/groups.yml` or equivalent).

**Mode B: Shard-based (fallback)**  
**Shape**
```json
{ "shard": [1] }
```
**Semantics**
- Used when groups aren’t provided.
- Defaults to 1 shard; at most 2.

**Why 1–2?**
- Perf tests are resource-intensive and can distort results when run concurrently.
- Concurrency increases noise and reduces interpretability.

---

## Governance Configuration
### Config file

`BrikByte-Studios/.github/.github/actions/matrix-plan/parallel-matrix.yml`

Example:
```yaml
version: 1

global:
  clamp_to_caps: true
  min_shards: 1

defaults:
  unit:
    default_shards: 6
    max_shards: 8

  integration:
    default_shards: 3
    max_shards: 4

  e2e:
    default_shards: 4
    max_shards: 6
    browsers: [chromium, firefox]

  performance:
    default_shards: 1
    max_shards: 2
```
**Override behavior**
- Repos may request `override_shards`.
- If `clamp_to_caps: true`, the request is clamped to `max_shards`.

---

## Required Contracts Per Test Type
### Unit Contract (Makefile / runner)
- Accept:
  - `UNIT_SHARD` (1-indexed)
  - `UNIT_SHARD_TOTAL`
- Implement deterministic selection:
  - Sorted list of test projects/files
  - Stable modulo selection or explicit chunking
- Produce artifacts per shard:
  - TRX / JUnit
  - Coverage artifacts (optional but recommended)

### Integration Contract (Runner)
- Support explicit items via env:
  - `INTEG_ITEMS_CSV` or `ITEMS_CSV`
- Must run one item at a time within the job:
  - `item = service::scenario`
- Must export logs and results for audit.

### E2E Contract
- Accept `BROWSER` and `SHARD_INDEX`/`SHARD_TOTAL`
- Produce:
  - screenshots/videos/traces
  - junit
  - coverage if available

### Performance Contract
- Accept group key:
  - `PERF_GROUP` or `GROUP`
- Produce:
  - raw tool output
  - summary JSON
  - audit bundle

---

## Deterministic Sharding Rules
### Allowed
- Sorting inputs (`sort`, stable filenames, stable list ordering)
- Modulo selection: `((index) % shards) == shardIndex`
- Explicit mapping from groups/items to jobs

### Not allowed
- Random shuffling
- “Adaptive” runtime-based shard resizing without governance approval
- Dynamic discovery that changes ordering across runs

---

## Operational Guidance
### When to increase shards
- Unit tests: safe to increase up to cap if runtime is too high.
- E2E: increase cautiously; prioritize stability and artifact capture.
- Integration: only increase if DB and infra are isolated per job (rare).
- Performance: generally do not increase beyond 1 unless groups are truly isolated.

### Avoiding contention
- Integration/performance should prefer:
    - dedicated DB containers per job
    - constrained CPU/memory limits
    - shorter timeouts and clear health checks

---

## Traceability
- Supports: `PIPE-CORE-2.4.1`
- Outputs:
  - Strategy doc: `brik-pipe-docs/testing/parallel-matrix.md`
  - Config: `.github/parallel-matrix.yml` (platform canonical)
- KPI:
  - Predictable CI runtime + cost control

---

## Appendix: Example Workflow Usage
### Example: Unit tests
```yml
jobs:
  plan:
    uses: BrikByte-Studios/.github/.github/actions/matrix-plan@main
    with:
      test_type: unit

  unit:
    strategy:
      matrix: ${{ fromJson(needs.plan.outputs.matrix_json) }}
    env:
      UNIT_SHARD: ${{ matrix.shard }}
      UNIT_SHARD_TOTAL: ${{ strategy.job-total }}
```

### Example: Integration tests with items
```yml
jobs:
  plan:
    uses: BrikByte-Studios/.github/.github/actions/matrix-plan@main
    with:
      test_type: integration
      services_csv: "users,payments"
      scenarios_csv: "happy_path,declined_card"
```

### Example: Performance with groups
```yml
jobs:
  plan:
    uses: BrikByte-Studios/.github/.github/actions/matrix-plan@main
    with:
      test_type: performance
      items: "smoke,baseline"
```