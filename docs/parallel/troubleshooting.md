# Parallel Testing — Troubleshooting

When parallel CI breaks, think like a distributed systems engineer.

---

## 1. Long-Tail Shards

### Symptom
One shard takes 5× longer.

### Cause
Uneven test weight.

### Fix
Enable dynamic balancing.

---

## 2. Flaky Tests

### Symptom
Shard fails intermittently.

### Cause
Hidden dependencies.

### Fix
Isolate:
- Temp dirs
- Ports
- Seeds

---

## 3. Missing Shards

### Symptom
Merge fails.

### Cause
Runner crash / timeout.

### Fix
Check shard logs + infra.

---

## 4. Duplicate Execution

### Symptom
Tests run twice.

### Cause
Bad discover script.

### Fix
Sort + uniq.

---

## 5. Resource Starvation

### Symptom
Random slowdowns.

### Cause
Runner saturation.

### Fix
Reduce shard count.

---

## 6. Hanging Labs

### Symptom
Integration never starts.

### Cause
Health check deadlock.

### Fix
Inspect docker logs.

---

## 7. Skewed Benchmarks

### Symptom
Speedup collapses.

### Cause
Cold caches / IO.

### Fix
Warmup runs.

---

## Debug Workflow

1. Inspect .audit bundle
2. Compare shard durations
3. Replay locally
4. Validate contract
5. Re-run single shard

---

## Emergency Mode

Disable parallelism:

```yaml
parallel_enabled: false
```
Restore stability first.

---

## Rule
If you cannot explain the failure with artifacts,  
you do not understand it yet.