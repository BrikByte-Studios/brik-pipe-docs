# E2E Tool Selection — Cypress vs Playwright (BrikByteOS)

> **Goal:** Standardize how BrikByte Studios chooses an E2E framework so teams move fast **without** fragmenting tooling.

---

## 1) Default Standard

**Default:** ✅ **Playwright** (recommended for new E2E work)  
**Allowed:** ✅ **Cypress** (when there is a clear reason)

**Why Playwright by default**
- Strong cross-browser capability (Chromium / Firefox / WebKit)
- Excellent scaling (workers, sharding, projects)
- Reliable automation primitives for complex flows

**Why Cypress is still supported**
- Excellent developer experience (interactive runner, time-travel debugging)
- Many teams already have Cypress expertise or existing suites
- Great fit for dashboard-style apps and fast feedback loops

---

## 2) Quick Decision Rule

Pick **Playwright** unless you can answer **YES** to at least one:

- Do we already have a Cypress suite we must keep / migrate?
- Is Cypress Runner UX a major productivity multiplier for this team?
- Are we targeting mainly Chromium and want the simplest local dev loop?

If **YES** → Cypress is acceptable.  
If **NO** → Use Playwright.

---

## 3) When to Choose Playwright ✅

Use Playwright when…

### Cross-browser confidence is required
- You need coverage across **Chromium + Firefox + WebKit**
- You want confidence that your UI works across browser engines

### Complex automation is expected
- Multi-tab flows, downloads, file uploads, complex navigation
- Rich network interception or advanced auth patterns (SSO/OAuth)

### Suite scale matters
- Large test suite, many specs, multiple apps/packages
- You want **workers/sharding/projects** to keep CI fast

### “One tool” strategy helps
- You want UI tests + API checks in the same runner
- You want consistent patterns across services

---

## 4) When to Choose Cypress ✅

Use Cypress when…

### Developer experience is the priority
- Cypress runner is central to your workflow
- Time-travel debugging and interactive inspection improves velocity

### Dashboard / CRUD web apps
- Many forms, tables, basic auth flows, and single-page interactions
- Your app is primarily Chromium-targeted (or that’s acceptable)

### Existing Cypress investment
- The repo already has Cypress tests + patterns + helpers
- Migration cost to Playwright is not justified

---

## 5) Known Constraints & Trade-offs

### Playwright considerations
- Slightly more upfront configuration for projects / reporting
- More “test engineering” oriented (great for platform teams)

### Cypress considerations
- Cypress in CI requires careful handling of:
  - service readiness (health checks)
  - Docker networking (avoid localhost pitfalls)
  - artifact paths (screenshots/videos must be exported correctly)

> ✅ BrikByteOS provides a reusable Cypress workflow that standardizes these concerns.

---

## 6) BrikByteOS Recommendations (Policy)

### Recommended (standard reasons to use Cypress)
- Existing Cypress suite that must remain
- Team is Cypress-first and Cypress Runner UX is critical
- App is a classic web dashboard, simple flows, Chromium is fine

### Recommended (standard reasons to use Playwright)
- New E2E suite starting from scratch
- Multi-browser confidence is important
- Complex automation flows are expected
- Large suite expected (scale + speed matter)

---

## 7) Practical Examples

| Scenario | Recommended Tool | Why |
|---|---|---|
| Marketing site / landing pages | Playwright | Fast, reliable, easy cross-browser |
| Admin dashboard CRUD flows | Cypress or Playwright | Both fit; choose based on team DX |
| Complex SSO/OAuth / multi-tab | Playwright | Strong primitives for complex browser flows |
| Existing Cypress suite | Cypress | Preserve investment, avoid rewrite |
| Monorepo with multiple UI packages | Playwright | Scaling + projects/sharding |
| “We need it running fast in CI with strong artifacts” | Either | Both workflows produce artifacts; Playwright often scales easier |

---

## 8) Operational Notes (CI Expectations)

### Common expectations for **both**
- Must include a readiness check (`/health` preferred)
- Must export artifacts (screenshots/videos/traces) on failures
- Must be deterministic and reproducible in CI

### Cypress-specific
- Prefer Docker network mode in CI:
  - UI container hostname: `app`
  - target URL: `http://app:<port>`
- Always upload:
  - `tests/e2e/cypress/screenshots`
  - `tests/e2e/cypress/videos`

### Playwright-specific
- Prefer trace + screenshot + video on failure for fast triage
- Use sharding/workers to keep runtime low as the suite grows

---

## 9) If You’re Still Unsure

Use this fallback rule:

1. **If you need cross-browser** → Playwright  
2. **If you already have Cypress tests** → Cypress  
3. Otherwise → Playwright

---

## 10) Related Docs
- `docs/e2e/playwright-adoption.md` (how to run Playwright locally + CI)


---
