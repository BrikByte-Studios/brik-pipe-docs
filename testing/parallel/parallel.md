# BrikPipe Deterministic Parallel Execution System  
**(PIPE-PARALLEL-RUNNER-INTEG-002)**

Parallelism in BrikPipe is not a CI speed trick.  
It is a **governed execution layer** designed to preserve auditability, determinism, and replayability while safely compressing CI wall-clock time.

BrikPipe parallelism turns CI into a deterministic distributed operating system.

---

## 1. Design Doctrine

| Principle | Meaning |
|----------|--------|
| Deterministic | Same commit always produces same shard plan |
| Governed | Shard counts are capped by test class |
| Lossless | No test duplication or starvation |
| Auditable | Every shard exports evidence |
| Replayable | Any shard can be re-executed alone |

Randomized parallelism is forbidden.

---

## 2. Parallel Execution Contract

| Variable | Purpose |
|---------|--------|
| `PARALLEL` | Enables runner |
| `PARALLEL_MODE` | static / dynamic |
| `SHARD_INDEX` | 0-based shard number |
| `SHARD_TOTAL` | total shard count |
| `SELECTION_MODE` | file-split / item-split / none |
| `SELECTION_PATH` | shard file list |
| `IS_EMPTY_SHARD` | indicates empty shard |

---

## 3. Governance Caps

Shard counts are governed per test type.

| Test Type | Max Shards |
|----------|------------|
| unit | 8 |
| integration | 4 |
| e2e | 3 |

All overrides are clamped by policy.

---

## 4. Selection Modes

| Mode | Behavior |
|-----|----------|
| none | Entire suite runs (serial) |
| file-split | Test files evenly divided |
| item-split | Domain items divided (integration scenarios, E2E routes, etc.) |

Selection always produces a shard file list.

---

## 5. Deterministic Shard Planning

1. Discover test universe  
2. Sort deterministically  
3. Slice into even shards  
4. Write shard file  
5. Export metadata into `.audit`  
6. Execute only assigned shard  

---

## 6. Language Adapter Behavior

| Language | Execution Adapter |
|---------|-------------------|
| Python | pytest path filtering |
| Java | Maven include/exclude |
| Node | Jest testPathPattern |
| .NET | dotnet test --filter |
| Go | go test ./pkg/... |

---

## 7. Audit Integration

Every shard exports:

```text
.audit/parallel/
├── shard.json
├── selected-tests.txt
└── summary.json
```

This enables perfect forensic replay.

---

## 8. Usage Example

Enable 4-way deterministic integration parallelism:

```bash
PARALLEL=true
PARALLEL_MODE=static
SHARD_TOTAL=4
SELECTION_MODE=file-split
```
---

## 9. Why This Exists

Without governed deterministic parallelism:

- CI becomes nondeterministic
- Audits become invalid
- Flakiness increases
- Reproduction becomes impossible

BrikPipe replaces chaos with compute law.

This is the engine that allows BrikByteOS to scale to **hundreds of repositories with zero audit collapse**.