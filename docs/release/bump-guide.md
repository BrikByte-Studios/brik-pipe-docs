# BrikByteOS Version Bump Guide

## Overview

BrikByteOS follows Semantic Versioning:

### MAJOR.MINOR.PATCH


Example:

`v1.4.2`


---

## Bump Types

### PATCH

`v1.4.2 → v1.4.3`


Use for:

- Bug fixes
- Refactors
- Docs
- Internal improvements

---

### MINOR

`v1.4.2 → v1.5.0`


Use for:

- New features
- Backward-compatible APIs
- Enhancements

---

### MAJOR

`v1.4.2 → v2.0.0`


Use for:

- Breaking changes
- API redesign
- Deprecation removals

---

## Decision Matrix

| Change Type | Bump |
|-------------|------|
| Bug fix | patch |
| New endpoint | minor |
| API removal | major |
| Config change | minor |
| DB migration | major |

---

## Governance Rule

When in doubt:

> Prefer MINOR over MAJOR.

Breaking changes must be documented.

---

## Dry-Run First

Always validate with:

```yaml
dry_run: true
```

Before real tagging.

---

## Anti-Patterns
❌ Skipping versions  
❌ Re-tagging releases  
❌ Manual git tag

Always use the workflow.

