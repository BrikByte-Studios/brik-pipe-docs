---
title: Template — Quarantine Request (Manual, v1)
---

<!--
Docstring:
Quarantine is governance-only in v1.
It does not auto-skip tests.
It exists to enforce ownership + expiry + review.
-->

# Quarantine Request (v1 — no auto-skip)

## Test identity
- **Suite:** (unit | integration | e2e-playwright)
- **Test display name:**
- **test_id:** (sha256:...)

## Reason for quarantine (required)
Explain why we cannot fix immediately:

## Evidence (required)
- Latest `.audit/.../flaky/flaky-summary.json`:
- Latest `.audit/.../flaky/policy-decision.json`:
- Trend evidence (7d/30d) if available:

## Impact statement
- How is this affecting CI? (reruns, blocks merges, false alarms)

## Owner + plan (required)
- Owner/team:
- Ticket for fix work:
- Planned stabilization approach:
  - [ ] unit determinism
  - [ ] integration lab hermeticity
  - [ ] e2e selector/wait strategy
  - [ ] infra escalation

## Expiry (required)
- Added at (YYYY-MM-DD):
- Expires at (YYYY-MM-DD, max 30 days recommended):
- Weekly review day/time:

## Exit criteria (required)
- fail_rate <= 0.05 for 10 consecutive runs
- removed from Top-N offenders (7d)
- link to evidence that will prove it
