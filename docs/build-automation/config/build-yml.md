---
title: .brik/build.yml Configuration Guide
---

# `.brik/build.yml` (v1)

## Purpose

`.brik/build.yml` declares your repo’s **build intent** in a stable, validated shape.

The validator enforces:

- schema correctness (types, required fields)
- stack/tool compatibility
- runtime version constraints (runtime matrix)
- cross-field rules (flags vs commands, unsafe patterns, etc.)

## File location

Must exist at:

`.brik/build.yml`


> v1 does **not** support `.brik/build.<env>.yml` (future scope).

## Canonical v1 shape

```yaml
schemaVersion: 1
stack: node|python|java|dotnet|go
workingDirectory: "."
runtime:
  version: "20"       # optional override; if omitted, matrix default is used
tool:
  kind: npm|pnpm|yarn|pip|poetry|maven|gradle|dotnet|go  # optional; matrix default if omitted
flags:
  runLint: false
  runTests: true
commands:
  install: "..."       # REQUIRED in v1 (must not be empty)
  lint: "..."          # required if runLint=true
  test: "..."          # required if runTests=true
  build: "..."         # REQUIRED in v1
artifacts:
  paths: ["dist/**"]   # optional; defaults by stack
```

## Important rules (v1)
### 1) Do NOT set empty strings for required fields
If you don’t want to override runtime/tool defaults, **omit the key**.

✅ Good:

```yaml
runtime: {}
tool: {}
```

❌ Bad:
```yaml
runtime:
  version: ""
tool:
  kind: ""
```

### 2) commands.install and commands.build must not be empty
They are mandatory v1 contract inputs.

### 3) Stage order is fixed
Order is always:
1. validate
2. install
3. lint (if enabled)
4. test (if enabled)
5. build
6. artifacts export
7. evidence export

Repos may override **commands**, not **sequence**.

### 4) Unsafe failure-hiding patterns are blocked (default)
Patterns like:
- `|| true`
- `exit 0`
- `set +e`

are rejected unless `allow_unsafe_commands=true` (discouraged).

## Minimal examples
See per-stack quickstarts:
- Node: `quickstarts/node.md`
- Python: `quickstarts/python.md`
- Java: `quickstarts/java.md`
- .NET: `quickstarts/dotnet.md`
- Go: `quickstarts/go.md`