---
title: Build Automation (v1)
description: Canonical onboarding + reference docs for BrikByteOS Build Automation v1.
---

# BrikByteOS Build Automation (v1)

BrikByteOS Build Automation standardizes builds across stacks using:

- a **per-repo contract**: `.brik/build.yml`
- a **fail-fast validator** (schema + rules + runtime matrix enforcement)
- a **canonical stage order** (PIPE-CORE-1.1.3 contract)
- an **audit/evidence ledger** under `.audit/PIPE-BUILD/`

## What you get

- **Onboard a repo in <30 minutes**
- Deterministic builds (same inputs → same behavior)
- Early failures with **human-readable error messages**
- Evidence exported on **pass and fail** for audits/troubleshooting

## Start here

1. Read: [Getting Started](./getting-started.md)
2. Pick your stack quickstart:
   - [Node](./quickstarts/node.md)
   - [Python](./quickstarts/python.md)
   - [Java](./quickstarts/java.md)
   - [.NET](./quickstarts/dotnet.md)
   - [Go](./quickstarts/go.md)
3. Configure: [.brik/build.yml Guide](./config/build-yml.md)
4. Learn contract + overrides: [Override Rules](./contract/override-rules.md)
5. Troubleshoot using evidence: [Evidence Guide](./evidence/interpretation.md)
