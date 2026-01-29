# Release FAQ

## Why policy-based tagging?

To ensure:

- Reproducibility
- Auditability
- Governance
- Security

---

## Can I tag manually?

No.

Manual tags violate audit policy.

---

## Why annotated tags?

They include:

- Author
- Timestamp
- Message

Required for compliance.

---

## Can I skip versions?

No.

Resolver is deterministic.

---

## Why is my branch blocked?

Because:

```yaml
allowed_branches
```
does not include it.

---

## Do I need a token?
Only if:
```ini
require_checks_passed=true
```
or enterprise setup.

---

## Can I delete tags?
No.

Use corrective release instead.

---

## What is .audit?
Evidence bundle.

Used for:
- Forensics
- Compliance
- RCA

---

## How do I see history?
```bash
git tag --sort=-creatordate
```

---

## Is prerelease supported?
Reserved for v2.

---

## Who owns releases?
Platform Engineering + Governance.