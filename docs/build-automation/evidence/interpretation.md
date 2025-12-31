---
title: Evidence Interpretation Guide
---

# Evidence Interpretation Guide (.audit/PIPE-BUILD)

BrikByteOS writes auditable evidence under:

`.audit/PIPE-BUILD/`


This evidence is produced on **pass and fail** so debugging never loses context.

## Validation evidence

Path:

`.audit/PIPE-BUILD/validation/`

Files:

- `build-config.raw.yml`  
  The exact YAML read by the validator.

- `build-config.resolved.json`  
  The normalized config after defaults + resolution.

- `validation-report.json`  
  Machine-readable report (issues, timings, files read).

- `validation-summary.md`  
  Human-readable summary with fix suggestions.

## How to read validation errors fast

### Example error
`SCHEMA_MINLENGTH` at `/tool/kind`

Meaning: your schema requires a non-empty string.  
Fix: don’t set it to `""`. Either provide a real value or omit the key.

✅ Correct:
```yaml
tool: {}
```

or
```yaml
tool:
  kind: npm
```

## Build evidence (per job)

Your build workflows will also write under:
```php-template
.audit/PIPE-BUILD/<stage>/
```

Examples (exact names may vary by template):
- `install/`
- `lint/`
- `test/`
- `build/`
- `artifacts/`

Each stage should export:
- command logs
- tool versions
- exit codes
- relevant artifacts (junit, coverage summaries, build outputs)

## Audit tips
- Keep .audit/ out of source control (recommended)
- Upload .audit as workflow artifacts for traceability
- Use it as evidence for:
  - why a build failed
  - what config was used
  - which runtime/tool versions were resolved
