---
title: FAQ / Common Errors
---

# FAQ / Common Errors

## “Why can’t I set runtime.version to an empty string?”
Because schema enforces **min length**. If you want defaults, omit the field:

```yaml
runtime: {}
```
## “Why can’t tool.kind be empty?”
Same reason. Omit to use matrix default:

```yaml
tool: {}
```

## “Where do I see what the validator resolved?”
Here:

```arduino
.audit/PIPE-BUILD/validation/build-config.resolved.json
```

## “What file is source-of-truth for supported versions?”
Runtime matrix:

`brik-pipe-actions/internal/vendor/runtime-matrix.yml`

## “My repo needs a special step”
Put it in the Makefile as part of `make build` or `make ci`.
Don’t change stage order.