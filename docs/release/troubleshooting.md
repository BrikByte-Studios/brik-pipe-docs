# Release Troubleshooting

## Common Errors

---

### E_BRANCH_NOT_ALLOWED

Cause:

Wrong branch.

Fix:

```bash
git checkout main
```

---

### E_SHALLOW_REPO

Cause:

fetch-depth ≠ 0

Fix:
```yaml
fetch-depth: 0
fetch-tags: true
```

---

### E_TAG_CONFLICT

Cause:

Tag exists on different commit.

Fix:

Do NOT delete manually.  
Investigate release history.

---

### E_CHECKS_NOT_PASSED

Cause:

CI failed.

Fix:

Repair failing tests.

---

### E_POLICY_INVALID

Cause:

Broken policy.

Fix:

Validate YAML.

---

### Debug Mode

Add step:
```yaml
- run: git tag --list
```

---

### Audit Files Missing

Ensure:
```yaml
include-hidden-files: true
```

---

### Git Identity Error

If tagging fails:
```bash
git config user.name "brikbyte-bot"
git config user.email "bot@brikbyte.io"
```

---

### Support

If unresolved:

Open issue with:
- Run ID
- Audit bundle
- Error code