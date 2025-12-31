---
title: Quickstart — .NET
---

# Quickstart — .NET (v1)

## 1) Add `.brik/build.yml`

```yaml
schemaVersion: 1
stack: dotnet
workingDirectory: "."
commands:
  install: "make restore"
  lint: "make lint"
  test: "make test"
  build: "make build"
flags:
  runLint: true
  runTests: true
artifacts:
  paths: ["out/**", "TestResults/**"]
```

## 2) Linting rule (dotnet-format)
Use `dotnet-format --check` (v1 recommended).

Commit the tool manifest created by:
- `dotnet new tool-manifest`
- `dotnet tool install dotnet-format`

This creates:

```arduino
.config/dotnet-tools.json
```

## 3) Validate
Check `.audit/PIPE-BUILD/validation/validation-summary.md`.