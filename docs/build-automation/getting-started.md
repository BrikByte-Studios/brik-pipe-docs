---
title: Getting Started
---

# Getting Started (v1)

## 0) Prereqs

- Repo must contain `.brik/build.yml`
- Your workflow must call the validator **immediately after checkout**
- Stack must be supported in the runtime matrix (ADR-PIPE-001)

> Source of truth:
> - `brik-pipe-actions/internal/vendor/runtime-matrix.yml`
> - `brik-pipe-actions/schemas/build.schema.json`

## 1) Add `.brik/build.yml`

Create the file at:  
`<repo-root>/.brik/build.yml`


Start with a stack quickstart (recommended) and customize only what you need.

## 2) Add a Makefile (recommended)

BrikByteOS v1 strongly recommends a **Makefile contract** so workflows can run consistent commands:

- `make install` (or `make deps`)
- `make lint`
- `make test` (unit by default)
- `make build`
- `make ci` (optional but recommended)

This keeps CI templates simple and prevents per-repo snowflakes.

## 3) Wire the validator in CI (first step)

In your workflow, run this as early as possible:

```yaml
- name: Validate build config
  uses: BrikByte-Studios/brik-pipe-actions/.github/actions/validate-build-config@main
  with:
    config_path: .brik/build.yml
    strict: false
    allow_unsafe_commands: false
```

If validation fails, check:
```bash
.audit/PIPE-BUILD/validation/validation-summary.md
```

## 4) Run locally (optional)

If your repo includes local tooling (future `brik-pipe validate`), run:
```bash
brik-pipe validate --config .brik/build.yml
```

Until then, you can run the action in CI and inspect `.audit` outputs.

## 5) Done definition checklist

✅ `.brik/build.yml` exists  
✅ validator runs first in CI  
✅ builds use canonical stage order  
✅ `.audit/PIPE-BUILD` is generated and understood by the team

