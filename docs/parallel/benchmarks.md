# Reading Benchmark Outputs

Benchmarks live under:

.audit/**/parallel/benchmarks/


---

## File: parallel-benchmark.json

Example:

```json
{
  "mode": "parallel-static",
  "speedup": 3.4,
  "serial_ms": 120000,
  "parallel_ms": 35000
}
```

---

## Fields
| Field | Meaning |
|-------|---------|
| mode | serial / parallel |
| speedup | serial ÷ parallel |
| efficiency | speedup ÷ shards |
| variance | stability |

---

## Interpretation
### Good
```nginx
speedup ≥ 0.7 × shards
```

### Warning
```nginx
speedup < 0.4 × shards
```

### Bad
```nginx
speedup < 1
```

---

## Trend Analysis
Compare over time:
```bash
.history/benchmarks.json
```

Detect regressions.

---

## Enforcement Modes
| Mode | Action |
|------|--------|
| warn | Log |
| enforce | Fail |

---

## Evidence Bundle
Benchmark always links to:
- shard artifacts
- normalized results
- metadata

No orphan metrics.

---

## Rule
Benchmarks without artifacts are lies.

