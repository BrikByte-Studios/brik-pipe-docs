# Dynamic Shard Balancing

Static sharding assumes uniform test cost.

Reality disagrees.

Dynamic balancing adapts.

---

## Inputs

Balancer consumes:

```text
.audit/**/metadata.json
parallel-benchmark.json
```

---

## Metrics

| Metric | Use |
|--------|------|
| Duration | Weight |
| Failures | Risk |
| Retries | Volatility |

---

## Algorithm (v1)

1. Sort tests by cost
2. Greedy assign
3. Equalize buckets
4. Emit plan

---

## Plan File

`test-plan.json`


Example:

```json
{
  "shards": {
    "0": ["a.test","b.test"],
    "1": ["c.test"]
  }
}
```

---

## Execution
Runner uses:
```css
--shard-plan-path
```
Overrides static.

---

## Stability Window
Plans updated only after:
- ≥5 runs
- Low variance

No oscillation.

---

## Failure Safety
If plan missing → fallback to static.

Never block CI.

---

## Roadmap
v2:
- ML weighting
- Predictive retries
- Hotspot detection