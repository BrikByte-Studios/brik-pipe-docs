---
title: Quickstart — Node
---

# Quickstart — Node (v1)

## 1) Add `.brik/build.yml`

```yaml
schemaVersion: 1
stack: node
workingDirectory: "."
# Omit runtime/tool to use matrix defaults
commands:
  install: "make install"
  lint: "make lint"
  test: "make test"
  build: "make build"
flags:
  runLint: true
  runTests: true
artifacts:
  paths: ["dist/**"]
```
Important: do not set `runtime.version: ""` or `tool.kind: ""`.  
Omit them if you want defaults.

## 2) Add Makefile targets
Your Makefile should provide:
- `make install` → `npm ci`
- `make lint` → `npm run lint` (or fallback rules)
- `make test` → `sharded test runner` if available
- `make build` → `npm run build`

## 3) Wire validator in CI
```yaml
- uses: BrikByte-Studios/brik-pipe-actions/.github/actions/validate-build-config@main
  with:
    config_path: .brik/build.yml
```

## 4) Success check
Look for:
- `.audit/PIPE-BUILD/validation/validation-summary.md` shows PASS
- `build-config.resolved.json` contains resolved runtime/tool

