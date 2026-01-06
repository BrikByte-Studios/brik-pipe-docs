# Restore Policy (PIPE-CACHE-FALLBACK-001)

BrikByteOS guarantees **progressive restoration**:
- exact
- less specific
- OS-wide fallback

So builds almost never reinstall everything.

Audit file:
```arduino
cache-policy.<stack>.json
cache-run.<stack>.json
```

These explain:
- which key matched
- whether restore hit
- why fallback was used