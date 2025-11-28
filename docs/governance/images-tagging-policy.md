# Container Image Tagging Policy (SHA + SemVer)

**ID:** GOV-IMAGES-TAG-POLICY-CONFIG-001  
**Domain:** Governance / Security / Containers

## 1. Requirements

Every CI-built image **MUST** have:

1. A **SHA tag**

   - Format: `sha-<short-or-full-hex-sha>`
   - Example: `sha-0f9b9113`

2. A **SemVer-style tag**

   - Format: `vX.Y.Z` or `X.Y.Z` (with optional suffix)
   - Examples:
     - `v1.2.3`
     - `1.0.0`
     - `v1.2.3-beta.1`

`latest` (and environment tags like `staging`, `prod`) are allowed only in addition to these tags, never as the sole tag.

## 2. Enforcement

- Policy is defined in `.github/policy.yml → images.tagging`.
- CI pipelines using the Kaniko reusable workflow:
  - Write `out/image-tags.json` with image + tags.
  - Run `.github/scripts/check-image-tags.mjs --config out/image-tags.json`.
- The job fails if:
  - No SHA tag.
  - No SemVer tag.
  - Only `latest` present.

## 3. Examples

**Good:**

- `["v1.0.0", "sha-0f9b9113"]`
- `["1.2.3", "sha-abc1234", "latest"]`

**Bad:**

- `["latest"]`
- `["sha-0f9b9113"]`
- `["v1.0.0"]`
