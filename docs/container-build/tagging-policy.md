# 🏷️ BrikByteOS Image Tagging Policy (PIPE-CORE-1.2.5)

This policy guarantees **traceable, rollback-safe container images** across all BrikByteOS pipelines.

Every pushed image must be immutable, auditable, and predictable.

---

###  Required Tag Rules (v1)
| Scenario | Required Tags |
| --- | --- |
| Any push | SHA tag required |
| Release build | SHA + SemVer required |
| `latest` tag |	❌ Forbidden by default |
| `latest` allowed | Only if explicitly enabled |

---
### Canonical Tag Formats
| Purpose | Format | Example |
| --- | --- | --- |
| Immutable SHA anchor | `sha-<shortsha>` | `sha-2f4c9a1` |
| Release version |	`v<major>.<minor>.<patch>` |	`v1.3.0` |
| Floating alias (optional) | `latest` | 	`latest` |

Only **strict SemVer** (`vX.Y.Z`) is allowed in v1.  
Pre-releases, build metadata, and loose formats are rejected.

---
### Recommended Tag Sets
#### 🔧 Development / PR Builds
```yaml
tags: sha-${{ github.sha }}
push: true
```

Result:
```bash
ghcr.io/org/service:sha-2f4c9a1
```
---
### 🚀 Release Builds
```yaml
tags: sha-${{ github.sha }},v1.2.0
push: true
release: true
```

Result:
```bash
ghcr.io/org/service:sha-2f4c9a1
ghcr.io/org/service:v1.2.0
```

---
### Enabling `latest` (Explicit Only)

`latest` is **OFF by default** because it breaks rollback determinism.

To allow it:
```yaml
allow_latest: true
tags: sha-${{ github.sha }},v1.2.0,latest
push: true
release: true
```

---
### Policy Failures (Examples)
| Error | Why |
| --- | --- |
| `❌ Missing sha tag` |	Push without immutable anchor |
| `❌ Release build missing vX.Y.Z tag` | 	Release without version |
| `❌ latest forbidden` | latest used without allow_latest |

All failures export machine-readable evidence to:
```pgsql
.audit/PIPE-CONTAINER-BUILD/policy/
  ├─ policy-summary.json
  └─ policy-summary.md
```

---
### Disable Policy (Emergency / Pilot Only)
```yaml
enforce_tag_policy: false
```
⚠️ **Not recommended** — disables rollback safety and audit guarantees.

---
### Why This Exists
| Problem | What the Policy Solves |
| --- | --- |
| Rollbacks unreliable | SHA tags are immutable |
| Audits unclear | Evidence is exported |
| Tags inconsistent | One global standard |
| “latest” chaos | Explicit opt-in only |

---
This policy makes **BrikByteOS images boring, predictable, and safe** — which is exactly what infrastructure should be.