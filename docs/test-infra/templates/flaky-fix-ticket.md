---
title: Template — Flaky Fix Ticket (PIPE-CORE-2.5.4)
---

<!--
Docstring:
This template standardizes flaky test remediation tickets.
Copy into GitHub Issues / Jira.
Attach or link the .audit artifacts referenced below.
-->

# Flaky Fix Ticket

## Summary
- **Suite:** (unit | integration | e2e-playwright | other)
- **Test display name:** 
- **test_id:** (sha256:...)
- **Impact:** (blocks merges | causes reruns | noisy but non-blocking)

## Evidence (required)
Attach or link:
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/flaky-summary.json`
- `.audit/<YYYY-MM-DD>/PIPE-RUN-<run_id>/flaky/policy-decision.json`
Optional:
- `.audit/.../flaky/normalized-results.json`
- `test-results/flaky/trends/top-flaky-7d.json`
- `test-results/flaky/trends/flaky-trends-30d.json`

## Classification
- Current classification: (stable | flaky | consistently_failing)
- Fail rate (this run): 
- Avg fail rate (7d): 
- Avg fail rate (30d): 

## Suspected root cause
Choose one:
- [ ] Time / clock nondeterminism
- [ ] Shared state / ordering dependency
- [ ] Async race / eventual consistency
- [ ] Data collisions / environment reuse
- [ ] Selector brittleness (E2E)
- [ ] Infra / runner instability
- [ ] Unknown (investigation required)

Notes:

## Stabilization plan (step-by-step)
1.
2.
3.

## Exit criteria (must be measurable)
- Target stable threshold: fail_rate <= 0.05
- Required consecutive stable runs: 10
- Evidence that proves exit:

## Ownership
- Owner/team:
- Reviewer (QA/platform):
- Due date: