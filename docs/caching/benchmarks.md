# Cache Benchmarks (PIPE-CACHE-BENCH-001)

Benchmarks compare:

| Mode | Meaning |
| --- | --- |
| cold | no reuse, forced miss |
| warm | cache restored |
| control | caching disabled |

Run:
```bash
gh workflow run cache-benchmarks.yml
```

Results:
```pgsql
.audit/YYYY-MM-DD/PIPE-CORE-1.3/benchmarks/
  bench-node.json
  bench-python.json
  bench-jvm.json
  summary.md
```