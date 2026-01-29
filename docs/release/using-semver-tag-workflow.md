# Using the SemVer Tag Workflow

## Overview

BrikByteOS provides a reusable workflow:

`.github/workflows/semver-tag.yml`


It enforces:

- Policy compliance
- Guardrails
- Auditing
- Determinism

---

## Manual Release

From GitHub UI:

1. Actions
2. Select "SemVer Tag"
3. Run workflow

Inputs:

| Field | Description |
|-------|-------------|
| bump | patch/minor/major |
| dry_run | Validate only |
| ref | Optional commit |

---

## Example

```yaml
bump: minor
dry_run: false
```

---

## Reusable Workflow
In another repo:
```yaml
jobs:
  release:
    uses: BrikByte-Studios/brik-pipe-actions/.github/workflows/semver-tag.yml@main
    with:
      bump: patch
      dry_run: false
```

---

## With Custom Policy
```yaml
with:
  policy_file: .github/policy.prod.yml
```

---

## Outputs

| Output | Meaning |
| --- | --- |
| tag | New tag |
| sha | Tagged commit |
| result | PASS/FAIL |
| audit_path | Evidence |

---
## Dry Run Mode
Dry-run performs:
- Policy validation
- Guardrail checks
- Version resolution

Without creating tags.

Recommended for validation.