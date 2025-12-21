# Parallel Test Matrix Strategy

**Document ID:** `PIPE-PARALLEL-MATRIX`  
**Audience:** Platform, QA Automation, CI/CD  
**Status:** Active  
**Last Updated:** 2025-12-21

## 1. Purpose

This document defines how **tests are parallelized deterministically** across CI runners in BrikByteOS.

Goals:
- Reduce wall-clock CI time
- Maintain deterministic, debuggable execution
- Support multiple languages and test frameworks
- Enable **safe dynamic optimization** without breaking reproducibility
- Produce audit-grade artifacts for governance and performance tracking

---

## 2. Core Principles
### 1. Determinism first
- Same commit + same inputs = same shard assignment

### 2. Static by default
- Dynamic behavior is opt-in and guarded

### 3. Shard awareness
- Every test knows which shard it belongs to

### 4. Auditability
- Shard plans are exported to `.audit/`

### 5. Safe fallback
- Planner failure must never block test execution

---

## 3. Parallelization Levels
| Level | Description |
| --- | --- |
| Job matrix | GitHub Actions matrix (e.g. 4–8 shards) |
| Test shard | Each job runs only its assigned tests |
| Test framework | Native parallelism (optional, secondary) |


BrikByteOS **controls sharding at the test list level**, not framework magic.

---

## 4. Terminology
| Term | Meaning |
| --- | --- |
| **Item** | A test unit (file, class, spec, case) |
| **Shard** | A slice of the test set |
| **Shard Map** | `shard-map.json` describing assignments |
| **Static Mode** | Even distribution by count |
| **Dynamic Mode** | Weighted distribution by cost history |
| **Audit Root** | `.audit/` evidence directory |

---

## 5. Static Shard Mode (Default)
### 5.1 Description

Static mode distributes tests **evenly by count** across shards.
- No historical data required
- Fully deterministic
- Lowest operational risk

### 5.2 When to Use
- New repositories
- Unstable or frequently changing tests
- Governance-critical pipelines
- Local development

### 5.3 Inputs Used
- `shard_count`
- `items` or `items_file`
- Optional `seed`

### 5.4 Guarantees
- Identical shard plans for identical inputs
- No dependency on `.audit/` history
- Zero learning curve

---

## 6. Dynamic Shard Mode 🧠
### 6.1 Description

Dynamic shard mode distributes tests based on **historical execution cost** to minimize total wall-clock time.

Instead of “same number of tests per shard”, the planner aims for:

> **Same total execution time per shard**

### 6.2 What “Cost” Means

Cost is derived from historical data in `.audit/`, such as:
- Test duration
- Retry frequency (optional)
- File size heuristics (fallback)

Each test item receives a **weight**, and shards are filled greedily to balance total weight.


### 6.3 Data Sources (Priority Order)
1. **Explicit history file** (`--history-path`)
2. **Audit history** under:
    ```pgsql
    .audit/**/<test_type>/**/shard-history.json
    ```
3. **Heuristic fallback**
   - File size
   - Alphabetical ordering (deterministic)

If no usable history exists → **automatic fallback to static mode**.

### 6.4 Enabling Dynamic Mode

Dynamic mode is opt-in.
```yaml
- uses: BrikByte-Studios/.github/.github/actions/shard-plan@main
  with:
    mode: dynamic
    shard_count: 6
    test_type: unit
    items_file: my-app/out/test-items.txt
    audit_root: .audit
```

If `mode` is omitted or empty → defaults to `static`.

### 6.5 Safety & Fallback Rules

Dynamic mode is **non-blocking by design**.

| Failure Scenario | Behavior |
| --- | --- |
| No history found | Fallback to static |
| Corrupt history | Fallback to static |
| Planner error | Workflow continues with static |
| Empty item list | Planner exits early (no-op) |

CI logs will emit:
```php
::warning::Shard planner failed; falling back to static mode.
```
### 6.6 Determinism in Dynamic Mode

Dynamic mode is **still deterministic**:
- Sorting is stable
- Greedy assignment is ordered
- Optional seed fixes tie-breaks

This means:  
Dynamic ≠ random

### 6.7 Outputs

Dynamic mode produces the same outputs as static mode:
```json
{
  "mode": "dynamic",
  "shard_count": 6,
  "assignments": {
    "1": ["test_a", "test_f"],
    "2": ["test_b"],
    "3": ["test_c"],
    ...
  },
  "metadata": {
    "used_history": true,
    "fallback": false
  }
}
```
---

## 7. Shard Map Contract

The shard planner **must** produce:
```arduino
<out_dir>/shard-map.json
```

This file is the **single source of truth** for:
- Test execution
- Audit export
- Coverage merging
- Performance analysis

---

## 8. Audit & Evidence

After planning, the action exports evidence:
```pgsql
.audit/
└── YYYY-MM-DD/
    └── parallel/
        ├── shard-map.json
        ├── shard-summary.json
        └── metadata.json
```

This supports:
- CI performance benchmarking
- Regression detection
- Governance reviews
- Cost attribution

---

## 9. Language-Agnostic Usage Pattern

All languages follow the same flow:
1. **Discover tests**
   - Write newline-delimited `out/test-items.txt`
2. **Plan shards**
   - `shard-plan` (static or dynamic)
3. **Run tests**
   - Each shard executes its slice
4. **Merge artifacts**
   - Coverage, reports, logs
5. **Governance gates**
   - Coverage, flake rate, performance

---

## 10.  Recommended Defaults
| Scenario | Mode |
| --- | --- |
| New repo | Static |
| < 200 tests | Static |
| Large monorepo | Dynamic |
| Flaky suite | Static |
| Performance tuning | Dynamic |

---

## 11.  Anti-Patterns (Avoid)

❌ Using framework-level sharding without shard-plan  
❌ Randomized test distribution  
❌ Making dynamic mode mandatory  
❌ Blocking CI on planner failure  
❌ Mutating shard assignments mid-job  

---

## 12. Related Documents
- `PIPE-PARALLEL-SHARD-DYNAMIC-003`
- `PIPE-PARALLEL-BENCHMARK-TEST-004`
- `PIPE-CORE-2.4.4`
- `GOV-TEST-COVERAGE-POLICY-004`

---

## 13.  Summary

- **Static mode** is the foundation
- **Dynamic mode** is an optimization layer
- Both share the same contracts, outputs, and audits
- Failures never block CI
- Determinism is never compromised
- Parallelism is an optimization — not a gamble.


**Parallelism is an optimization — not a gamble**.  
BrikByteOS treats it as infrastructure, not a trick.