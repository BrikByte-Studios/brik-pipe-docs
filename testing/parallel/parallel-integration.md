---
title: Parallel Integration Testing Playbook
id: parallel-integration
owner: QA + Platform
status: stable
last_updated: 2025-12-21
---

# Parallel Integration Testing Playbook

Integration tests sit between Unit and E2E:
- **heavier** than unit tests (DBs, queues, services)
- **less flaky** than E2E (usually), but still sensitive to shared state
- perfect candidate for **parallelism** when isolation is done properly

This playbook teaches safe sharding for integration tests across BrikByteOS/BrikPipe repos.

---

## Goal

Reduce integration test wall-clock time without:
- DB contention and state collisions
- port collisions
- shared container name conflicts
- expensive runner-minute blowups

Success looks like:
- consistent pass rate
- stable shard runtimes
- measurable wall-clock improvement (benchmark-proven)

---

## Standard Parallel Controls

Your integration runner must honor:

- `PARALLEL_MODE=serial|static|dynamic`
- `SHARD_COUNT=<N>` (for the matrix / job fan-out)
- `INTEGRATION_SHARD=<1..N>` and `INTEGRATION_SHARD_TOTAL=<N>`
  - (or `SHARD_INDEX/SHARD_TOTAL` if your repo standardizes that)

> Keep this consistent per repo. Don’t mix `INTEGRATION_SHARD` and `UNIT_SHARD` for integration tests.

---

## Static vs Dynamic Mode

### Static (default)
- deterministic split by test list (files/ids/packages)
- easiest to debug
- best when you don’t have reliable `.audit` timing history yet

### Dynamic (opt-in)
- balances shards using historical runtimes from `.audit`
- best when you have:
  - stable test IDs
  - stable runtime history
  - enough tests to benefit from balancing
- should **fall back to static** if history is missing

---

## Preconditions for Parallel Integration Tests

Parallel integration will fail if isolation is weak. Ensure:

### 1) Database isolation
**Avoid shared DB** across shards unless your tests are fully transactional + isolated.

Preferred patterns:
- **per-shard database name**
  - `db_${RUN_ID}_${INTEGRATION_SHARD}`
- **per-shard schema** (if DB supports it)
  - `schema_${RUN_ID}_${INTEGRATION_SHARD}`

If you use Docker Compose:
- use **unique project name** per shard:
  - `COMPOSE_PROJECT_NAME=it-${RUN_ID}-${INTEGRATION_SHARD}`

### 2) Port isolation
No fixed ports across shards.

Options:
- allocate ports dynamically
- use shard-based offset:
  - base 5432 + shard * 10, etc.
- use docker networking without publishing ports (preferred)

### 3) Service/container name isolation
Avoid collisions like:
- `postgres` container name reused
- `redis` container name reused

Fix:
- compose project naming (recommended)
- container name prefixing with shard namespace

### 4) External system isolation
If tests hit:
- S3 buckets
- queues/topics
- email/sms providers

Ensure shard namespace prefixing or mocking/stubbing.

---

## Quick Start

### Step 1: Generate a non-empty `out/test-items.txt`

Your shard planner requires a list of “items” to split.

Common patterns:
- one test file = one item
- one test class = one item
- one package/module = one item
- one scenario id = one item

Examples:

#### Java (JUnit)
```bash
mkdir -p out
find . -maxdepth 8 -type f \( -name "*IT.java" -o -name "*IntegrationTest.java" -o -name "*Test.java" \) | sort > out/test-items.txt
test -s out/test-items.txt
```
#### Node + Testcontainers
```bash
mkdir -p out
find tests/integration -type f -name "*.test.*" | sort > out/test-items.txt
test -s out/test-items.txt
```

#### ython (pytest integration)
```bash
mkdir -p out
python - <<'PY'
import glob
tests = sorted(glob.glob("**/test_*.py", recursive=True))
tests = [t for t in tests if "integration" in t or "it_" in t]
print("\n".join(tests))
PY
test -s out/test-items.txt
```

#### Go (integration packages)
```bash
mkdir -p out
go list ./... | grep -E 'integration|it' > out/test-items.txt || true
test -s out/test-items.txt
```

If your repo naturally has few integration tests (e.g., < shard count), reduce `SHARD_COUNT`.

### Step 2: Plan shards (static/dynamic)
```yaml
- name: Shard plan (integration)
  uses: BrikByte-Studios/.github/.github/actions/shard-plan@main
  with:
    mode: ${{ inputs.parallel_mode || 'static' }}
    shard_count: 4
    test_type: integration
    items_file: ${{ env.WORKING_DIRECTORY }}/out/test-items.txt
    workdir: ${{ env.WORKING_DIRECTORY }}
    out_dir: ${{ env.WORKING_DIRECTORY }}/out
    audit_root: .audit
```

Expected output:
- `out/shard-map.json` (or `out/shard-map.json` per your action output contract)

### Step 3: Run integration shard

Each matrix job runs one shard:
```yaml
- name: Run integration shard
  run: |
    echo "Integration shard ${INTEGRATION_SHARD}/${INTEGRATION_SHARD_TOTAL} mode=${PARALLEL_MODE}"
    make test:integration
  env:
    PARALLEL_MODE: ${{ inputs.parallel_mode || 'static' }}
    INTEGRATION_SHARD: ${{ matrix.shard }}
    INTEGRATION_SHARD_TOTAL: ${{ inputs.shard_count }}
    COMPOSE_PROJECT_NAME: it-${{ github.run_id }}-${{ matrix.shard }}
```

## Runner Requirements (Repo Contract)

Your integration runner must:
1. select tests for the shard
2. set up isolated infra for the shard
3. run only selected tests
4. export stable artifacts

Minimum artifacts:
- `out/junit.xml` (or junit per shard)
- service logs (if failing)
- optional: `out/shard-map.json`
- optional: coverage output (if configured)


## Debugging Shard Failures
### Integration Shard Debug Checklist
1. **Identify failing shard**
    - Check logs for:
      - `INTEGRATION_SHARD`
      - `INTEGRATION_SHARD_TOTAL`
      - `PARALLEL_MODE`
2. **Check shard-selected test list**
    - Your runner should print count + first few items
3. **Inspect infra logs**
    - container logs (db, api, worker)
    - compose logs export (recommended)
4. **Look for collision patterns**
    - DB name/schema reused
    - COMPOSE_PROJECT_NAME missing
    - published ports colliding
    - shared temporary directories
5. **Reproduce locally**
```bash
export PARALLEL_MODE=static
export INTEGRATION_SHARD=3
export INTEGRATION_SHARD_TOTAL=4
export COMPOSE_PROJECT_NAME=it-local-3
make test:integration
```

## Common Failure Causes (and Fixes)
### DB contention / state leakage

Symptoms:
- tests pass in serial but fail in parallel
- foreign key or unique key violations  
Fix:
- per-shard DB/schema
- explicit cleanup
- transactional tests where possible

### Port collisions

Symptoms:
- “address already in use”  
Fix:
- avoid publishing ports
- randomize ports
- shard-based offsets

### Container name collisions

Symptoms:
- docker complains about existing container names  
Fix:
- `COMPOSE_PROJECT_NAME` unique per shard

### Readiness / timing

Symptoms:
- flaky “connection refused” or “timeout”  
Fix:
- proper health checks
- retry/backoff for service readiness
- longer startup timeouts for cold caches

## Choosing Shard Count

Start at 2:
- validate stability
- check imbalance
- benchmark

Increase only if:
- benchmark shows significant wall-clock improvement
- overhead isn’t dominating (setup per shard can be expensive)

Rule of thumb:
- if most time is “setup”, more shards won’t help much
- if most time is “test execution”, sharding helps

## Cost vs Speed Trade-offs

Parallel integration can increase cost due to:
- running multiple DB containers
- repeated setup steps per shard
- duplicated dependency installs

Cost controls:
- caches (deps, docker layers)
- build once, reuse artifacts
- keep shard count within org caps
- enforce regression thresholds with benchmark workflow

## Disable Quickly
### Option A: Force serial

Set:
- `PARALLEL_MODE=static`
- `SHARD_COUNT=1`  
(or set integration shard total to 1)

### Option B: Kill switch

If repo supports:
- `ENABLE_PARALLEL=false`

Use for:
- urgent hotfix merges
- diagnosing flakiness
- upstream infra instability (registry outage, etc.)

## Recommended Evidence & Artifacts
- `out/junit.xml`
- `out/shard-map.json` (planner output)
- `docker compose logs` (export)
- `.audit/**` evidence bundle (optional but ideal)

## Related Docs
- Parallel overview: `brik-pipe-docs/testing/parallel/index.md`
- E2E parallel playbook: `parallel-e2e.md`
- Strategy & caps: `brik-pipe-docs/testing/parallel-matrix.md`
- Benchmark evidence: `.audit/**/parallel-benchmark.json`