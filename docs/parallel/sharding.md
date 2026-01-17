# How Sharding Works (Static v1)

**Audience:** repo maintainers, CI owners  
**Applies to:** BrikByteOS v1 parallel orchestration using `.brik/parallel.yml`  
**Mode:** `static` (deterministic, no historical balancing)

---

## 1. What “Static Sharding” Means

Static v1 sharding = **split work into N shards using a deterministic rule**, run shards in parallel, then collect results.

Key properties:

- **Deterministic:** same inputs → same shard assignment every run
- **Stateless:** no history / timing model used
- **Simple:** modulo allocation over a stable ordering

---

## 2. The Core Rule

Given:

- `total_shards = N`
- `shard_index = i` (0-based in CI)
- a deterministic list of test identifiers sorted in a stable way

A test at position `k` goes to shard:

```text
k % N == i
```


So each shard gets a roughly even slice of the ordered list.

---

## 3. Shard Indexing Convention (Important)

BrikByteOS pipelines treat shard indices as **0-based** at the workflow layer:

- `BRIK_SHARD_INDEX`: `0..N-1`
- `BRIK_SHARD_TOTAL`: `N`

Some test runners expect **1-based** shard numbering. In that case, map it:

- `RUNNER_SHARD = BRIK_SHARD_INDEX + 1`
- `RUNNER_TOTAL = BRIK_SHARD_TOTAL`

Example mapping:

| BrikByteOS | Runner-friendly |
|---|---|
| index=0 total=4 | shard=1 total=4 |
| index=1 total=4 | shard=2 total=4 |
| index=2 total=4 | shard=3 total=4 |
| index=3 total=4 | shard=4 total=4 |

---

## 4. Where Shards Come From

Shards can be defined in `.brik/parallel.yml` in two ways:

### 4.1 Global default shards

```yaml
version: "parallel.v1"

parallel:
  enabled: true
  mode: "static"
  shards: 4
```

This means “default to 4 shards unless overridden per kind”.

### 4.2 Per-kind shard counts (recommended)
```yaml
version: "parallel.v1"

parallel:
  enabled: true
  mode: "static"
  matrix:
    include:
      - kind: unit
        shards: 4
      - kind: integration
        shards: 2
      - kind: e2e
        browser: chromium
        shards: 2
```

This means:
- Unit → 4 shards
- Integration → 2 shards
- E2E chromium → 2 shards

---

## 5. Two Static Shard Modes (Execution)

Static v1 supports two execution styles (the contract enables both; the workflow chooses).

### 5.1 Native sharding (runner does the split)

You pass shard index/total to the test command, and the repo’s tooling selects tests.

Typical when the repo has a sharder script (fast + deterministic).

**Example concept:**
- list tests
- sort deterministically
- pick tests matching `k % total == index`

### 5.2 List-based sharding (workflow provides assigned tests file)

The workflow discovers all test IDs, splits them deterministically, writes:
- `assigned-tests.txt`

Then runs the test command using that file (via env var or placeholder).

This is best when:
- the runner doesn’t support sharding natively
- you want standardized splitting logic in BrikByteOS

---

## 6. Determinism Rules (Must Follow)

To guarantee stable shards across runs:

### 6.1 Stable Test Identifier

Use a stable identifier like:
- file path (recommended)
- test fully-qualified name (when available)

### 6.2 Stable Ordering

Before sharding, tests MUST be sorted deterministically, e.g.:
- `sort` lexicographically
- consistent path normalization

### 6.3 No randomness
- no random seed unless fixed
- no “discovery order” reliance

---

## 7. Examples
### Example A — Unit tests with 4 shards

**.brik/parallel.yml**
```yaml
version: "parallel.v1"
parallel:
  enabled: true
  mode: "static"
  matrix:
    include:
      - kind: unit
        shards: 4
```

**What happens**
- CI creates 4 jobs for unit tests:
  - shard 0/4
  - shard 1/4
  - shard 2/4
  - shard 3/4

Each job runs only its assigned portion.

---

### Example B — E2E browser × shards (2 browsers × 2 shards)
```yaml
version: "parallel.v1"
parallel:
  enabled: true
  mode: "static"
  matrix:
    include:
      - kind: e2e
        browser: chromium
        shards: 2
      - kind: e2e
        browser: firefox
        shards: 2
```
**What happens**
- Total jobs = 4:
  - chromium shard 0/2
  - chromium shard 1/2
  - firefox shard 0/2
  - firefox shard 1/2

---

### Example C — Integration subsets with 2 shards each
```yaml
version: "parallel.v1"
parallel:
  enabled: true
  mode: "static"
  matrix:
    include:
      - kind: integration
        subset: payments
        shards: 2
      - kind: integration
        subset: orders
        shards: 2
```

**What happens**
- Each subset gets its own shard fan-out:
  - payments shard 0/2
  - payments shard 1/2
  - orders shard 0/2
  - orders shard 1/2

---

### Example D — Serial fallback (safe mode)
```yaml
version: "parallel.v1"
parallel:
  enabled: false
```

Or simply no `.brik/parallel.yml`.

**What happens**
- workflows run serially (`shards=1`, no fan-out)

---

## 8. Limits and Guardrails (v1)

To prevent CI cost explosions, BrikByteOS v1 should enforce these limits.

### 8.1 Shard limits
- `shards` must be an integer `>= 1`
- recommended maximum: **16 shards per kind**

### 8.2 Matrix job limits

Compute estimated job count:
- For each matrix include row:
  - jobs contributed = `shards` (or 1 if omitted)
- Total jobs = sum across include rows

Recommended maximum total jobs per workflow run: **32**

### 8.3 Failure behavior

If limits are exceeded, validation should fail early with clear messages:
- “shards exceeds max_shards=16”
- “matrix expands to 40 jobs; max_total_jobs=32”

---

## 9. Practical Recommendations
### Choose shards based on test size
- Unit tests: 4–8 shards
- Integration: 1–4 shards (depends on DB + container cost)
- E2E: usually 2 shards per browser (start small)

### Don’t overshard small suites

If you have fewer tests than shards:
- some shards will be empty
- you pay extra CI overhead
- you gain nothing

---

## 10.  Troubleshooting Checklist

If a shard runs “0 tests” unexpectedly:
- Confirm tests are discovered correctly
- Confirm stable sorting
- Confirm shard index base (0-based vs 1-based)
- Confirm list-based mode actually passes assigned tests file
- Confirm runner command uses the shard variables

---

## 11. Summary

Static v1 sharding is:
- deterministic modulo splitting
- simple and stable
- safe defaults when disabled or missing
- guardrailed by max shards and max job count

This forms the foundation for later phases (dynamic balancing), without breaking v1 behavior.