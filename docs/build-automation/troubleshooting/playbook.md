---
title: Troubleshooting Playbook
---

# Troubleshooting Playbook (v1)

## First rule: open the evidence summary
Start here:  
`.audit/PIPE-BUILD/validation/validation-summary.md`


It tells you what failed and where.

---

## Common failures

### 1) `CONFIG_NOT_FOUND`
**Cause:** `.brik/build.yml` missing or config_path wrong.  
**Fix:** create `.brik/build.yml` or update the workflow input.

---

### 2) `SCHEMA_MINLENGTH` at `/runtime/version` or `/tool/kind`
**Cause:** you set empty strings:
```yaml
runtime:
  version: ""
tool:
  kind: ""
```

Fix: omit the key to use defaults:
```yaml
runtime: {}
tool: {}
```

---
### 3) `TOOL_NOT_ALLOWED`

**Cause:** tool.kind not valid for stack.
**Fix:** pick an allowed tool for the stack (see quickstarts).

---

### 4) `RUNTIME_VERSION_NOT_ALLOWED`

**Cause:** runtime.version not in matrix allowlist.
**Fix:** use a version allowed by `internal/vendor/runtime-matrix.yml`.

---

### 5) `UNSAFE_COMMAND_PATTERN`

**Cause:** failure hiding patterns detected (`|| true`, `exit 0`, `set +e`).  
**Fix:** remove the pattern and let CI fail correctly.

---

## Performance issues (validator >5s)

The validator should:
- do filesystem IO only
- do no network calls
- read only config + schema + runtime matrix

If slow:
- ensure no extra scans (large repo traversal)
- keep schema compilation in-process
- avoid additional dependencies in action

---

## Escalation checklist

When raising an issue to Platform/QA, include:
- `.audit/PIPE-BUILD/validation/*`
- the repo’s `.brik/build.yml`
- workflow run link
- stack/runtime/tool versions