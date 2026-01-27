# E2E Browser × Shard Matrices

E2E tests are I/O-bound and UI-fragile.

Parallelization is controlled and capped.

---

## Supported Runners

| Tool | Support |
|------|----------|
| Playwright | ✅ |
| Cypress | ✅ |
| Selenium | ⚠️ (legacy) |

---

## Matrix Dimensions

`Browser × Shard × Viewport`


Example:

| Browser | Shard |
|---------|-------|
| Chrome | 0 |
| Firefox | 1 |

---

## Example

```yaml
strategy:
  matrix:
    browser: [chromium, firefox]
    shard: [0,1]
```

---

## Resource Controls

E2E shards are limited:
- Max 4 (default)
- CPU capped
- Memory capped

---

## Video & Trace

Each shard stores:
```text
videos/
screenshots/
traces/
```

In artifacts.

---

## Flake Mitigation
- Retries ≤ 2
- Trace on retry
- Screenshot on fail

---

## Stability Rules

❌ No fixed sleeps  
✅ Use auto-wait  
❌ No random data  
✅ Stable selectors

---

## Rule

If UI tests are slow,  
parallelism is not your problem.  
Architecture is.