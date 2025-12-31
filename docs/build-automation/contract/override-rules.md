---
title: Override & Contract Rules
---

# Override & Contract Rules (v1)

This doc explains **what you may override** and what is **enforced**.

## Enforced (cannot override)

- Stage order (install → lint → test → build)
- Runtime/tool allowlists per stack (from runtime matrix)
- Schema shape (schemaVersion, required fields)
- Evidence export paths under `.audit/PIPE-BUILD/`

## Allowed overrides

- `workingDirectory`
- runtime version (if allowed by matrix)
- tool kind (if allowed by stack)
- command strings (install/lint/test/build)
- artifact paths

## Flags behavior

- `flags.runLint=false` → lint step skipped
- `flags.runTests=false` → test step skipped
- If flag is false but command is set → warning (or error in strict mode)

## Defaults resolution

If you omit optional keys, the validator produces a resolved config:

- runtime version defaulted from runtime matrix
- tool defaults from runtime matrix
- default commands injected (only when omitted)
- artifact defaults applied

Resolved output is written to:

`.audit/PIPE-BUILD/validation/build-config.resolved.json`

Workflows should prefer this resolved config (v1+).

## “Override law” summary (simple)

- **Omit keys** to use defaults.
- **Set keys** only when you truly need an override.
- Never set required command fields to empty.