# parallel.yml (v1) — Quick Reference

## Minimal
```yaml
version: "parallel.v1"
parallel:
  enabled: true
  shards: 4
```

## Matrix include
- `parallel.matrix.include` is deterministic ordering.
- Each item becomes a “job intent” that runners expand into shards.

## Guardrails
- max shards default: 16
- max matrix jobs default: 32