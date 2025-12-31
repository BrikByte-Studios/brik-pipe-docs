# BrikByteOS Build Contract (v1)

**Status:** Accepted  
**ADR:** ADR-PIPE-002  
**Scope:** PIPE-CORE-1.1.x  
**Applies To:** All BrikByteOS build workflows (`build-node`, `build-python`, `build-java`, `build-dotnet`, `build-go`)

---
## 1. Purpose

This contract defines **how builds must behave** across all BrikByte pipelines.

It establishes:
- Canonical stage order
- Required semantics per stage
- What is allowed to change
- What is forbidden
- Evidence & audit obligations

This contract is the enforcement layer that turns CI into an auditable production system — not a collection of scripts.

---
## 2. Canonical Stage Order (Non-Negotiable)

All builds MUST execute in this exact sequence:

| Order | Stage | Description |
|-------|-------|-------------|
| 1	| restore / install |	Resolve and install dependencies |
| 2 | 	lint |	Static analysis (optional hook) |
| 3 |	test |	Automated verification |
| 4	| build |	Produce build artifacts |
| 5 |	artifact summary |	Generate audit evidence |

Stages may only be skipped through defined flags — never reordered or removed.

---

## 3. Stage Semantics
### 3.1 Install / Restore

**Purpose:** Dependency determinism

| Requirement | Rule |
|-------------|------|
| Input |	working_directory |
| Output |	build-install.log |
| Failure | Fail-fast |
| Evidence | MUST capture logs |

---
### 3.2 Lint (Optional)

| Requirement | Rule |
|-------------|------|
| Default	| Disabled in v1 |
| Input | lint_command |
| Output |	lint.log |
| Failure | Fail build |
| Evidence | MUST capture logs |

---
### 3.3 Test (Default On)

| Requirement | Rule |
|-------------|------|
| Default |	Enabled |
| Output |	test.log |
| Failure | Fail build |
| Evidence | MUST capture logs |

---
### 3.4 Build

| Requirement | Rule |
|-------------|------|
| Output | build.log |
| Failure | Fail build |
| Evidence | MUST capture logs |

---
### 3.5 Artifact Summary (ALWAYS)

| Requirement | Rule |
|-------------|------|
| Execution | MUST use `if: always()` |
| Output |	`.audit/PIPE-BUILD/*` |
| Purpose | Immutable build record |

---
## 4. Deterministic Verdict

Every build MUST output:
```ini
build_verdict = pass | fail
```

Rules:
- Build must succeed
- Lint/Test may be skipped
- Verdict MUST be deterministic

---
## 5. Override Law (The Law of Motion)
### 5.1 Allowed Overrides (Legal)
| Type | Examples |
|------|----------|
| runtime_version |	20.x, 3.12, 1.22.x |
| package_manager |	npm / pnpm / yarn |
| build_tool |	maven / gradle |
| working_directory | ./apps/api |
| command overrides | lint_command, test_command, build_command |
| toggles |	run_lint, run_tests |
| artifact control |	upload_artifacts |

---
### 5.2 Forbidden Overrides (Illegal)
| Forbidden	| Reason |
|------------|--------|
| Reordering stages | Breaks audit predictability |
| Disabling evidence export | Creates audit gaps |
| Custom shell scripts hiding failure (` | |	
| Bypassing validators | Breaks governance |
| Removing audit output | Breaks compliance |

Illegal overrides are treated as contract violations.

---
## 6. Conventions (Defaults by Runtime)
| Runtime | Build Output |
|---------|--------------|
| Node | `/dist` |
| Python | `__pycache__` |
| Java | `/target` |
| .NET | `/bin` |
| Go | `/bin` |

These are recommended defaults in v1 (not mandatory yet).

---
## 7. Evidence Contract

All builds MUST produce:
```pgsql
.audit/PIPE-BUILD/
├── metadata.json
├── install.log
├── lint.log
├── test.log
├── build.log
└── summary.json
```

Evidence MUST be uploaded if `upload_artifacts=true`.

---
## 8. Enforcement
| Layer | What it Enforces |
|-------|------------------|
| PIPE-CORE-1.1.2 | Workflow behavior |
| PIPE-CORE-1.1.4 | Schema validation |
| PIPE-CORE-1.1.6 | Regression tests |
| ADR-PIPE-002 | Governance authority |

---
## 9. Versioning
| Version | Rule |
|---------|------|
| v1.x | Soft-governance, input overrides allowed |
| v2.0 | Hard-governance, branch protected enforcement |

---
## 10. Final Law

Pipelines are not scripts.  
They are production systems with legal contracts.