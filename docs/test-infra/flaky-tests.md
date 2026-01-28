---
title: Flaky Tests — Stabilization Playbook + Manual Quarantine (v1)
version: PIPE-CORE-2.5.4
owner: QA Automation Lead
status: Active
---

<!--
Docstring:
This playbook defines the official BrikByteOS approach to flaky tests.
It is designed to be used with the exact artifacts produced by:
- PIPE-CORE-2.5.2 (flaky evaluator outputs)
- PIPE-CORE-2.5.3 (rolling trends + top offenders)

Key rule:
No "auto-skip" in v1. Quarantine is manual + governed + time-bounded.
-->

# Flaky Tests — Stabilization Playbook + Manual Quarantine (v1)

## Why this exists
Flaky failures destroy CI trust, waste engineering time, and create “rerun culture”.
This playbook standardizes how we:
- interpret flaky evidence (not vibes)
- fix root causes (not mask)
- quarantine temporarily (manual, owned, time-bounded)
- track improvement over time (7/30d trends)

---

## Definitions (v1)
**Stable test**  
A test that passes consistently across repeated runs and across recent history.

**Flaky test**  
A test that fails intermittently under the same code + environment assumptions.

**Consistently failing test**  
A test that fails reliably (very high fail rate) — usually a real defect or a broken contract.

**Infra / Environment noise**  
Failures caused by the runner/network/service availability rather than the test logic.

> Policy note: A flaky test is still a problem. It is not “fine because it passed on rerun”.

---

## Anti-goal: “Retry culture”
Retries, sleeps, and random timeouts often **hide defects** and **increase runtime**.

**Hard rule**: retries must not be used to “make red green”.  
If a test is failing, investigate root cause or quarantine (manual) with ownership.

---

## Evidence map (what to open first)

### Per-run evaluator evidence (PIPE-CORE-2.5.2)
These are generated when repeat-run + evaluator are enabled.

**Canonical `.audit` placement (v1):**
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/flaky-summary.json`
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/policy-decision.json`
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/normalized-results.json` *(optional)*
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/metadata.json`

### Rolling trends (PIPE-CORE-2.5.3)
Generated only if trends are enabled on `main` pushes.

- `test-results/flaky/trends/flaky-trends-7d.json`
- `test-results/flaky/trends/flaky-trends-30d.json`
- `test-results/flaky/trends/top-flaky-7d.json`
- `test-results/flaky/trends/top-flaky-30d.json`
- `test-results/flaky/trends/flaky-summary.md` *(optional)*

---

## Triage workflow (Step-by-step)

### Step 0 — Confirm infra vs test failure
**Goal:** avoid chasing a flaky test when the runner is sick.

Checklist:
- Did multiple unrelated tests fail at once?
- Are there network timeouts, DNS failures, container pull issues?
- Did required services fail health checks?
- Is failure correlated to runner load, concurrency, or a specific job?

If YES → treat as **infra noise**.  
Action: open an infra ticket, link to run logs, and avoid “fixing” tests.

---

### Step 1 — Identify classification & fail-rate band
Open:
- `.audit/.../flaky/flaky-summary.json`
- `.audit/.../flaky/policy-decision.json`

Look for:
- `suite_name`
- `runs_total`
- per-test `fail_rate`
- per-test `classification` (stable / flaky / consistently_failing)
- any policy enforcement decision (warn/block)

Interpretation bands (defaults; may be overridden by policy):
- **Stable:** fail_rate <= `stable_max_fail_rate` (example 0.05)
- **Flaky:** fail_rate <= `flaky_max_fail_rate` (example 0.40)
- **Consistently failing:** fail_rate > `flaky_max_fail_rate`

---

### Step 2 — Check the trend (7d vs 30d)
Open:
- `flaky-trends-7d.json` vs `flaky-trends-30d.json`
- `top-flaky-30d.json`

Questions:
- Is the flake newly introduced (present in 7d but not 30d)?
- Is it chronic (present in both, with worsening fail rate)?
- Is it improving (7d avg lower than 30d avg)?

**Decision hint:**
- New + high fail rate → fix now (likely regression)
- Chronic + slow burn → plan stabilization sprint + quarantine if blocking

---

### Step 3 — Choose an action
**A) Fix now**
Use when:
- consistently failing
- flake rate is high and blocking velocity
- regression suspected

**B) Stabilize environment**
Use when:
- failures correlate strongly to infra factors
- integration/e2e lab issues dominate

**C) Quarantine (manual, governed)**
Use when:
- repeated CI disruption is occurring
- root cause needs time (complex infra or refactor)
- test is not currently trusted as a signal

> Quarantine is NOT skipping. It is governance tracking + ownership + time-bounded urgency.

---

## Stabilization techniques catalog

### Unit tests
**Do**
- Make tests deterministic: isolate RNG (seed it), avoid global state.
- Control time: use fake time / clock injection (no real `sleep()`).
- Use pure fixtures: consistent inputs, hermetic outputs.
- Avoid filesystem/network unless explicitly part of unit scope.
- Run tests in randomized order locally to catch hidden coupling.

**Don’t**
- Add arbitrary sleeps.
- Add retries to make failures disappear.
- Depend on local machine timezone/locale defaults.

Common root causes:
- shared mutable globals
- reliance on system time
- unordered map/set iteration assumptions
- concurrency without synchronization

---

### Integration tests
**Do**
- Hermetic environment: compose lab + known versions.
- Reset DB state per test suite (transaction rollback or schema rebuild).
- Idempotent setup/teardown.
- Use health gates and explicit readiness checks for dependencies.
- Ensure test data is uniquely namespaced (avoid collisions).

**Don’t**
- Assume service is ready “because compose started”.
- Reuse stateful DB across suites without cleanup.
- Use random ports without publishing where needed.

Common root causes:
- DB not reset / data leaking between tests
- services start but not ready
- eventual consistency races
- parallel tests sharing the same environment

---

### E2E (Playwright)
**Do**
- Prefer stable selectors: `data-testid` attributes.
- Use Playwright auto-waits + explicit waits for state transitions (NOT sleeps).
- Seed deterministic test data (known users, known orders).
- Use network stubbing for truly external dependencies.
- Capture traces/screenshots only on failure (cost control).

**Don’t**
- `waitForTimeout()` as a fix.
- Use brittle selectors (CSS nth-child, dynamic text).
- Depend on real-time delays (animations, spinners) without waiting for completion state.

Common root causes:
- selector brittleness
- login/session instability
- slow CI runners
- environment-dependent UI timing

---

## Retries and timeouts policy (v1)
### Allowed (rare)
- One retry for a known infra transient (documented, time-bounded).
- Test tool built-in retry used only during stabilization window (tracked + ticketed).

### Forbidden
- Retries added to “green the build”.
- Sleeps added without documented reason and exit plan.

**Principle:**  
Retries should never be used to pass a failing test.

---

# Manual Quarantine Protocol (v1 — no auto-skip)

## What quarantine means (v1)
Quarantine is **governance tracking** of a test that is producing unreliable CI signal.
It does **not** automatically skip or disable tests.

Quarantine exists to:
- force ownership
- force expiry
- force evidence-based review
- prevent “forever flaky” acceptance

---

## Quarantine criteria
A test may be quarantined if:
- it is classified flaky above threshold for repeated runs **OR**
- it blocks developer velocity repeatedly **AND**
- a root cause fix is non-trivial and needs planned work

---

## Governance rules
**Required**
- Ticket created (Flaky Fix Ticket template)
- Named owner/team
- Expiry date (default max 30 days)
- Weekly review cadence (owner reports status)

**Not allowed**
- Quarantine without owner
- Quarantine without expiry
- “Quarantine forever”

---

## Exit criteria (must be explicit)
A test may be removed from quarantine when:
- fail_rate <= `stable_max_fail_rate` for N consecutive runs (recommend N=10) **and**
- it no longer appears in Top-N offenders (7d window)

Evidence to attach:
- latest `.audit/.../flaky/flaky-summary.json`
- trends showing improvement (`flaky-trends-7d.json` vs `30d`)

---

## How to record quarantine state (tracking only)

### Preferred: `test-quarantine.yml` at repo root
This file is governance-only. It must not be used to auto-skip.

Example:
```yaml
schema_version: QuarantineListV1
tests:
  - test_id: "sha256:abc123..."
    suite: "e2e-playwright"
    display_name: "Checkout.payments.cardVisa"
    reason: "Intermittent timeout waiting for payment iframe in CI"
    owner: "@team-payments"
    ticket: "GH-456"
    added_at: "2026-01-28"
    expires_at: "2026-02-27"
    evidence:
      last_run_audit_path: ".audit/2026-01-28/PIPE-RUN-123456/flaky/flaky-summary.json"
```

### Weak option (discouraged): label-only

Labels can be lost and don’t enforce expiry. Only use if repo cannot commit files.

---

## Templates (use these)
- Flaky Fix Ticket: `docs/test-infra/templates/flaky-fix-ticket.md`
- Quarantine Request: `docs/test-infra/templates/quarantine-request.md`

---

## Example evidence (sanitized)

See:
- `brik-pipe-examples/audit-samples/flaky/`

---
## Quick checklist (printable)

- [ ] Confirm infra vs test issue
- [ ] Open `.audit/.../flaky/flaky-summary.json`
- [ ] Check `policy-decision.json` for enforcement outcome
- [ ] Compare 7d vs 30d trends
- [ ] Choose action: fix / stabilize env / quarantine
- [ ] If quarantine: ticket + owner + expiry + weekly review
- [ ] Remove quarantine only with evidence-based stability