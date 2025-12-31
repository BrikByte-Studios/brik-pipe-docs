---
title: Quickstart — Java (Maven)
---

# Quickstart — Java (v1)

## 1) Add `.brik/build.yml`

```yaml
schemaVersion: 1
stack: java
workingDirectory: "."
commands:
  install: "make deps"
  lint: "make lint"
  test: "make test"
  build: "make build"
flags:
  runLint: true
  runTests: true
artifacts:
  paths: ["target/**", "out/**"]
```

## 2) Makefile targets (Maven)
Recommended contract:
- `make deps` → `mvn -B dependency:resolve`
- `make lint` → `mvn -B -DskipTests verify`
- `make test` → sharded surefire selection
- `make build` → `mvn -B clean package`

## 3) Validate in CI
Validator runs first; inspect `.audit/PIPE-BUILD/validation/`.