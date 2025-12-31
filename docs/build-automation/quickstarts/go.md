---
title: Quickstart — Go
---

# Quickstart — Go (v1)

## 1) Add `.brik/build.yml`

```yaml
schemaVersion: 1
stack: go
workingDirectory: "."
commands:
  install: "make install"
  lint: "make lint"
  test: "make test"
  build: "make build"
flags:
  runLint: true
  runTests: true
artifacts:
  paths: ["bin/**", "out/**", "coverage.out"]
```

## 2) Makefile targets
Recommended:
- `make install` → `go mod download`
- `make lint` → `golangci-lint run` (or `go vet ./...` fallback)
- `make test` → `go test ./...` with junit export if needed\
- `make build` → `go build`

## 3) Validate
Evidence lives at `.audit/PIPE-BUILD/validation/`.
