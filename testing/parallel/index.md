---
title: Parallel Testing Playbook
id: parallel-testing-playbook
owner: QA + Platform
status: stable
last_updated: 2025-12-21
---

# Parallel Testing Playbook

This playbook teaches you how to run **Unit**, **Integration**, **E2E**, and **Performance** tests in **parallel** safely, predictably, and with cost control.

If you only read one section: read **Quick Start** and **Disable Quickly**.

---

## Core Concepts

### What “matrix” means (GitHub Actions)
A **matrix** is a GitHub Actions feature that runs the **same job** multiple times with different inputs (e.g., shard index 1..N).

### What “shards” are
A **shard** is one slice of the total test workload.
- If `SHARD_COUNT=4`, we split the test workload into 4 parts.
- Each matrix job runs one shard: `SHARD_INDEX=1..4`.

### Deterministic sharding (required)
Our sharding must be deterministic:
- same repo + same ref + same seed/config → same shard plan
- no “random shuffle” by default

This prevents “flake-by-shuffle”.

---

## Parallel Modes

### Static Shard Mode
Static mode splits tests by a deterministic rule (e.g., alphabetical list, file sizes, stable hashing).

**Use when:**
- you want reliable speedups
- you don’t have stable runtime history yet

### Dynamic Shard Mode (opt-in)
Dynamic mode uses **runtime history** (from `.audit/`) to balance shards more evenly.

**Use when:**
- tests have uneven runtimes
- you have benchmark evidence that dynamic improves imbalance and wall-clock

**Important:** dynamic mode requires a valid input list (`out/test-items.txt`) and historical timing (if enabled in your planner). If missing, pipelines should fall back to static.

---

## Quick Start

### 1) Add a discovery step to produce a non-empty test items list
Parallel planning depends on an item list.

**Contract:**
- file path: `out/test-items.txt`
- format: newline-delimited items (paths or ids)
- must be non-empty (or explicitly “skip sharding”)

Examples:
- Go: packages or test ids
- Node: test files
- Java: test classes
- Python: test files or node ids

### 2) Run shard plan action (generates `out/shard-map.json`)
Example:

```yaml
- name: Shard plan
  uses: BrikByte-Studios/.github/.github/actions/shard-plan@main
  with:
    mode: ${{ inputs.parallel_mode || 'static' }}   # static|dynamic
    shard_count: 4
    test_type: unit
    items_file: ${{ env.WORKING_DIRECTORY }}/out/test-items.txt
    workdir: ${{ env.WORKING_DIRECTORY }}
    out_dir: ${{ env.WORKING_DIRECTORY }}/out
    audit_root: .audit
```

### 3) Run tests using shard env vars

Each shard job receives:
- `UNIT_SHARD` and `UNIT_SHARD_TOTAL` (or test-type equivalent)
- `PARALLEL_MODE=static|dynamic`

Your test runner must honor these.


## When to Use Parallelism

Use parallelism when:
- wall-clock is too slow for developer feedback
- tests are stable and isolated
- the suite is large enough to benefit (usually > ~2–3 min serial)
- you can show improvement via benchmarking

Recommended approach:
1. start with **2 shards**
2. benchmark
3. increase only if the benchmark improves wall-clock without raising flake rate or cost too much

## When NOT to Use Parallelism

Avoid parallelism if:
- tests share mutable state (same DB schema, same global seed, same ports)
- tests are already fast (< ~60–90s) and parallel adds overhead
- you are debugging a hard flake (run serial first)
- the suite is too small (shard overhead dominates)

Common parallel-flake causes:
- shared DB contention / non-unique test data
- port collisions (services binding to same ports)
- static filesystem paths (`/tmp/app.db`) shared across shards
- timeouts/readiness checks missing
- order-dependent tests

## Cost vs Speed Trade-offs

Parallelism improves **wall-clock** but can increase **runner-minutes**.
- Serial: slower wall-clock, cheaper runner-minutes
- Parallel: faster wall-clock, potentially higher total compute

Your goal is not “max shards”, it’s:
- **fast feedback** within a cost budget
- **stable** pass rate

Use benchmarking evidence (see Benchmark workflow docs) to justify shard counts.


## Debugging Parallel Failures
### 1) Identify failing shard

Look for environment lines like:
- `UNIT_SHARD=3`
- `UNIT_SHARD_TOTAL=4`
- `PARALLEL_MODE=static|dynamic`

### 2) Pull artifacts

Check:
- `out/junit.xml`
- `out/shard-map.json` (if produced)
- `.audit/.../parallel-benchmark.json` (if running benchmark workflow)
- E2E traces / screenshots / videos (if configured)
- integration container logs (if configured)

###  3) Reproduce locally (run only that shard)

Example pattern:
```bash
export PARALLEL_MODE=static
export UNIT_SHARD=3
export UNIT_SHARD_TOTAL=4
make test
```

If your runner uses `out/shard-map.json`, run the shard’s listed items.

## Disable Quickly

Use **one** of these “fast off switches” (choose one standard per repo):

### Option A (recommended): force serial

Set:
- `PARALLEL_MODE=static`
- `SHARD_COUNT=1`

### Option B: repo-level kill switch

If your workflow supports it, set:
- `ENABLE_PARALLEL=false`

**Hotfix guidance:**
- For a “get green now” situation, set shard count to `1` temporarily, then open an issue to re-enable with a fix.


## Docs Map
- [E2E parallel playbook](parallel-e2e.md)
- [Integration parallel playbook](parallel-integration.md)
- [Decision flowchart](parallel-decision-flowchart.svg)


## Related
- Parallel matrix strategy and caps: `brik-pipe-docs/testing/parallel-matrix.md`
- Benchmarking workflow: `.github/workflows/ci-parallel-benchmark.yml`