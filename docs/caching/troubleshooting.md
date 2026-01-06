# Cache Troubleshooting Playbook

| Problem | Cause | Fix |
| --- | --- | --- |
| No cache hit | wrong lockfile | check descriptor_hash |
| Cache never saves | fork PR | allow_cache_write |
| Slow builds | build outputs cached | remove dist/ |
| Wrong key | toolchain mismatch | align Node/JDK/Python |
| Corrupt deps | bust cache | `cache_bust: "reset-1"` |

Emergency bust:
```yaml
cache_bust: "force-reset-2026-01"
```

## Governance Anchors
| Ref | Purpose |
| --- | --- |
| REQ-PIPE-CORE-1.3.6 | Docs compliance |
| ADR-020 | Cache stores |
| ADR-021 | Key strategy |
| ADR-022 | Benchmarks |

## Result

With these docs:
- Any repo enables caching in < 2 minutes
- Cache keys are explainable
- Misses are diagnosable
- Benchmarks are defensible