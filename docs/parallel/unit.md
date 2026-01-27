# Unit Test Sharding

Unit tests are CPU-bound, deterministic, and cheap.

They are ideal for horizontal sharding.

---

## Supported Runners

| Stack | Tool |
|-------|------|
| Python | pytest |
| Node | node:test / jest |
| Java | junit |
| Go | go test |
| .NET | dotnet test |

---

## Shard Modes

### Native (Default)

Runner handles splitting.

Example:
```yaml
shard_mode: native
```

Used when framework supports sharding.

---

## List Mode

Framework-agnostic file-based sharding.
```yaml
shard_mode: list
discover_command: |
  find tests -name "test_*.py"
```

Pipeline:
```bash
discover → split → assign → execute
```

---

## Shard Environment

Each shard receives:
```ini
BRIK_SHARD_INDEX=0..N-1
BRIK_SHARD_TOTAL=N
```

Use in scripts:
```bash
pytest --shard=$BRIK_SHARD_INDEX
```

---

## Output Contract

Each shard writes:
```bash
test-artifacts/unit/shards/<id>/
  └── test-results.json
```

---

## Normalization

JUnit → Canonical JSON

Fields:
```json
{
  "passed",
  "failed",
  "skipped",
  "total",
  "duration_ms"
}
```

---

## Best Practices

✅ Keep tests stateless  
✅ Avoid global fixtures  
✅ Mock network calls  
❌ No shared temp dirs  
❌ No random seeds

---

## Common Failures
| Issue | Cause |
|-------|-------|
| Duplicates | Non-deterministic discovery |
| Empty shards | Bad discover script |
| Skew | Test size imbalance |

---

## Rule

If unit tests are flaky, parallelism will amplify it.

Fix first. Then shard.