# BrikByteOS Cache System (v1) — Overview

**Applies to:** PIPE-CORE-1.3  
**Stacks:** Node, Python, JVM  
**Goal:** deterministically speed up CI builds, auditable by evidence.

BrikByteOS provides **standardized, policy-driven build caches** that:

- Cache dependency stores (not build outputs)
- Use deterministic, inspectable cache keys
- Apply safe fallback restore ladders
- Write `.audit/` evidence explaining cache behavior
- Are benchmarked via PIPE-CACHE-BENCH-001

## Key Recipe (v1)

All cache keys are derived as:
```php-template
brikbyteos|cache|<stack>|v1|
  os=<linux|macos|windows>|
  tc=<toolchain>|
  tool=<tool>|
  desc=<lockfile_hash>|
  bust=<optional>
```

Example:
```lua
brikbyteos|cache|node|v1|os=linux|tc=node20|tool=pnpm|desc=ad21fa...|bust=
```

## Restore Fallback Ladder

Exact key fails? BrikByteOS automatically tries:

| Level | Restores |
| --- | --- |
| 1 | Exact match |
| 2 | No bust |
| 3 | Any descriptor |
| 4 | Any tool |
| 5 | OS + toolchain |
| 6 | OS only |

This is why caches still restore even when lockfiles change slightly.

## What We Cache (Always Safe)
| Stack | Cached Paths |
| --- | --- |
| Node | pnpm/yarn/npm global stores |
| Python | `~/.cache/pip` wheels |
| JVM | `~/.m2/repository`, `~/.gradle/caches` |


### What We Never Cache

❌ build outputs (`dist/`, `bin/`, `target/`)  
❌ `.env`, credentials  
❌ virtualenv folders  
❌ node_modules  
❌ secrets

## Where Evidence Lives

All cache operations produce evidence under:
```arduino
.audit/<YYYY-MM-DD>/PIPE-CORE-1.3/cache/
  cache-policy.<stack>.json
  cache-run.<stack>.json
```

Benchmarks live under:
```swift
.audit/<YYYY-MM-DD>/PIPE-CORE-1.3/benchmarks/
```