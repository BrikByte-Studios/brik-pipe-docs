---
title: Parallel E2E Testing Playbook
id: parallel-e2e
owner: QA + E2E Maintainers
status: stable
last_updated: 2025-12-21
---

# Parallel E2E Testing Playbook

E2E tests are the **most expensive** and **most flake-prone** category to parallelize.
This guide shows how to shard E2E safely, how to debug shard-only failures, and how to disable quickly when you need a hotfix.

> If you’re under pressure: jump to **Disable Quickly** and **Shard Debug Checklist**.

---

## Goal

Make E2E faster **without**:
- increasing flaky failures
- breaking shared environments
- exploding runner-minutes cost

Success looks like:
- wall-clock drop ≥ meaningful target (e.g., 30%+)
- shard imbalance trending down (especially in dynamic mode)
- no new flake patterns introduced

---

## E2E Sharding Model

### Standard environment variables

Your E2E runner must honor:

- `PARALLEL_MODE=serial|static|dynamic`
- `E2E_SHARD=<1..N>`
- `E2E_SHARD_TOTAL=<N>`
- `SHARD_COUNT=<N>` (often used to build the matrix)

> Some repos may use `SHARD_INDEX/SHARD_TOTAL`. Choose one mapping and document it in the repo.

### Static vs Dynamic for E2E

**Static (default):**
- deterministic split by test file list (or stable hash)
- easiest to reason about
- best when you don’t have reliable timing history

**Dynamic (opt-in):**
- balances shards using runtime history from `.audit/`
- reduces “shard 3 always slow” problem
- requires stable history + stable test IDs

---

## Preconditions (Before You Parallelize E2E)

Parallelize only if these are true:

### 1) Isolation
Each shard must be isolated from other shards.

**Must be unique per shard:**
- test user accounts (or test data namespace)
- database schema / database name (if using DB)
- ports
- filesystem output directories
- external resources (buckets, queues) where possible

**Recommended pattern:**
- prefix everything with a shard-scoped namespace:
  - `${RUN_ID}-${E2E_SHARD}`

### 2) Deterministic environment setup
- Dependencies pinned (docker tags, browser versions, Playwright/Cypress versions)
- Setup scripts not relying on non-deterministic ordering
- Avoid global shared “seed once” behavior across shards

### 3) Artifact capture enabled
E2E without artifacts is pain.
Enable at least:
- junit output
- screenshots on failure
- traces/videos where supported

---

## Quick Start (E2E Parallel)

### Step 1: Generate a non-empty test items list

You need `out/test-items.txt` for shard planning.

Examples:
- Playwright: list spec files
- Cypress: list spec files
- Selenium: list scenario IDs or spec files

Example (generic):
```bash
mkdir -p out
find tests/e2e -type f \( -name "*.spec.*" -o -name "*.test.*" \) | sort > out/test-items.txt
test -s out/test-items.txt
```

### Step 2: Generate shard map (optional but recommended)
```yaml
- name: Shard plan (E2E)
  uses: BrikByte-Studios/.github/.github/actions/shard-plan@main
  with:
    mode: ${{ inputs.parallel_mode || 'static' }}
    shard_count: 4
    test_type: e2e
    items_file: ${{ env.WORKING_DIRECTORY }}/out/test-items.txt
    workdir: ${{ env.WORKING_DIRECTORY }}
    out_dir: ${{ env.WORKING_DIRECTORY }}/out
    audit_root: .audit
```

### Step 3: Run E2E shard

Each matrix job runs one shard:
```yaml
- name: Run E2E shard
  run: |
    echo "E2E shard ${E2E_SHARD}/${E2E_SHARD_TOTAL} mode=${PARALLEL_MODE}"
    make test:e2e
  env:
    PARALLEL_MODE: ${{ inputs.parallel_mode || 'static' }}
    E2E_SHARD: ${{ matrix.shard }}
    E2E_SHARD_TOTAL: ${{ inputs.shard_count }}
```

## Runner Requirements (Your repo must implement these)

Your E2E entrypoint must:

1. **Select** tests for the shard (from a deterministic list)
2. **Run only those tests**
3. **Export artifacts** to stable locations

Minimum contract:
- `out/junit.xml` (or junit per shard)
- `out/test-items.txt` (discovery output)
- optional: `out/shard-map.json` (planner output)
- E2E artifacts: `out/e2e/**` (traces, screenshots, videos)


## Debugging E2E Shard Failures
### Shard Debug Checklist
1. **Confirm which shard failed**
    - Look for:
      - `E2E_SHARD`
      - `E2E_SHARD_TOTAL`
      - `PARALLEL_MODE`
2. **Check the shard’s selected tests**
    - Output should print the selected list OR a count.
    - If missing: add logging (“Selected N specs for shard i”).
3. **Inspect artifacts**
    - `out/junit.xml` (failures)
    - screenshots
    - traces/videos
    - service logs (if integration services involved)
4. **Reproduce locally**
```bash
export PARALLEL_MODE=static
export E2E_SHARD=2
export E2E_SHARD_TOTAL=4
make test:e2e
```

5. **If dynamic mode is on**
    - confirm shard map exists: `out/shard-map.json`
    - confirm `.audit/` history exists (if required)
    - if missing history: dynamic may behave like static or should fall back

## Common E2E Parallel Failure Causes
### Data collisions
- Two shards creating the same user/email
- Two shards writing the same DB record keys  
Fix: shard-scoped namespace.

### Port collisions
- running services on fixed ports  
Fix: random ports or shard-based offset.

### Shared external environment
- staging env not designed for parallel load  
Fix: per-shard tenant, or run E2E in ephemeral env.

### Rate limits
- hitting auth/email/SMS providers  
Fix: mock/stub where possible; increase backoff.

### Timing / readiness
- shards racing and the app isn’t ready  
Fix: proper health checks + retries.

## Choosing Shard Count for E2E

Start small:
- **2 shards**, benchmark, then increase.

Guidance:
- If shards are imbalanced (one shard slow), prefer **dynamic mode** (with history) before adding more shards.
- Avoid going beyond a sensible cap (org policy) unless benchmarks prove it.

## Cost Guidance

E2E parallelism can increase runner-minutes due to:
- duplicated setup per shard (install/build)
- repeated environment provisioning
- browser startup overhead

Mitigations:
- cache dependencies (node_modules, playwright browsers)
- build once, reuse artifacts
- keep shard counts modest
- benchmark weekly and compare with baseline

## Disable Quickly
### Option A: Force serial

Set:
- `PARALLEL_MODE=static`
- `SHARD_COUNT=1`  
(or set your E2E shard total to 1)

### Option B: Kill switch

If supported by repo:
- `ENABLE_PARALLEL=false`

Use this when:
- diagnosing flakiness
- a release hotfix needs green CI now

## Recommended Artifacts & Evidence

For each E2E run:
- `out/junit.xml`
- `out/e2e/screenshots/**`
- `out/e2e/traces/**`
- `out/e2e/videos/**`
- `out/shard-map.json` (when using planner)
- `.audit/**` evidence (optional but ideal)

## Related Docs
- Parallel overview: `brik-pipe-docs/testing/parallel/index.md`
- Integration parallel playbook: `parallel-integration.md`
- Strategy & caps: `brik-pipe-docs/testing/parallel-matrix.md`