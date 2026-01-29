# BrikByteOS SemVer Policy

## Overview

BrikByteOS uses a **policy-driven, deterministic Semantic Versioning (SemVer) system**
to ensure that all release tags are:

- Predictable
- Auditable
- Reproducible
- Governance-compliant

All tagging behavior is controlled by `.github/policy.yml`.

---

## Policy Location

Default:

`.github/policy.yml`


Override:

```yaml
policy-file: path/to/policy.yml
```

---
## Policy Structure

Example (v1):
```yaml
version: 1

release:
  semver:
    enabled: true
    source_of_truth: "git-tags"

    tag_prefix: "v"
    tag_pattern: "^v\\d+\\.\\d+\\.\\d+$"

    allowed_branches:
      - main
      - release/*

    enforcement_mode: block

    idempotency: fail

    tag_type: annotated

    initial_version: "v0.1.0"

    prerelease:
      enabled: false
      allowed_channels:
        - rc
        - beta

    guardrails:
      require_full_history: true
      require_checks_passed: false
      prevent_tag_move: true
```

---

## Field Reference
### enabled

| Value | Meaning |
| --- | --- |
| true | Tagging allowed |
| false | Tagging disabled |

---

### allowed_branches

List of branches/patterns allowed to release.

Supports wildcards.

Example:
```yaml
allowed_branches:
  - main
  - release/*
```

---

### enforcement_mode
| Value | Behavior |
| --- | --- |
| block | Fail workflow |
| warn | Emit warning only |

Use `warn` during rollout.

---

### idempotency

Controls existing tag behavior.

| Mode | Behavior |
| --- | --- |
| fail | Block if tag exists |
| noop | Allow if same SHA |

---

### guardrails

| Field | Purpose |
| --- | --- |
| require_full_history | Prevent shallow repos |
| require_checks_passed | Require CI success |
| prevent_tag_move | Prevent tag reassignment |

---

### Validation

Policy is validated at runtime.

Invalid policies cause:
```nginx
E_POLICY_INVALID
```

---

### Versioning

Policy schema is versioned.

Current: `version: 1`

Future versions will maintain backward compatibility.