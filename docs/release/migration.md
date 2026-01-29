# Migrating to BrikByteOS SemVer

## From Manual Tags

### Step 1 — Freeze Manual Tagging

Disable:

```bash
git tag
```
in documentation.

---

### Step 2 — Add Policy
Create:
```bash
.github/policy.yml
```

---

### Step 3 — Enable Workflow
Add:
```yaml
semver-tag.yml
```

---

### Step 4 — Dry Run
Run:
```yaml
dry_run: true
```

---

### Step 5 — First Release
Use:
```yaml
bump: patch
dry_run: false
```

---

## From Other CI Systems

| System | Action |
| --- | --- |
| Jenkins | Disable tagging |
| GitLab | Remove tags |
| Circle | Disable |

---

## Bootstrapping Legacy Repos
If no tags exist:
```yaml
initial_version: "v1.0.0"
```
---

## Rollout Strategy
1. warn mode
2. observe
3. block mode
4. enforce

---

## Backout Plan
Set:
```yaml
enabled: false
```
to pause.

