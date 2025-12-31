---
title: Quickstart — Python
---

# Quickstart — Python (v1)

## 1) Add `.brik/build.yml`

```yaml
schemaVersion: 1
stack: python
workingDirectory: "."
commands:
  install: "make deps"
  lint: "make lint"
  test: "make test-unit"
  build: "make build"
flags:
  runLint: true
  runTests: true
artifacts:
  paths: ["__pycache__/**", "dist/**", "out/**"]
```

## 2) Makefile targets
Recommended:
- `make deps` (pip install -r requirements.txt)
- `make lint` (ruff/flake8/etc.)
- `make test` (pytest)
- `make build` (optional packaging)

## 3) Validate
Check `.audit/PIPE-BUILD/validation/validation-summary.md`.

