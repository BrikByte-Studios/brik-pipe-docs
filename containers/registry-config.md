# BrikByteOS Containers — Registry & Kaniko Caching Configuration

## 1. Canonical Registry

BrikByteOS Pipelines uses a **single canonical container registry** for all
first-party images:

- **Registry URL:** `ghcr.io`
- **Organization namespace:** `ghcr.io/brikbyte-studios`
- **Standard image naming:**

  ```text
  ghcr.io/brikbyte-studios/<service-name>
  ```
Examples:
- Node API: `ghcr.io/brikbyte-studios/example-node-api`
- Python service: `ghcr.io/brikbyte-studios/example-python-api`
- .NET service: `ghcr.io/brikbyte-studios/example-dotnet-api`

All CI builds using Kaniko **MUST** push to this registry path (REQ-REGISTRY-001).

---

## 2. Secret Model & Naming Convention
### 2.1. Org / Environment Secrets

To avoid per-repo ad hoc configurations, we standardize **secret names** that
callers will map into the reusable Kaniko workflow:

Recommended **Org-level or Environment-level** secrets:
- `REGISTRY_URL`
    - Example: `ghcr.io`
    - Non-secret, but useful as a central config.
- `REGISTRY_USERNAME`
    - Optional.
    - For GHCR, this is often not required; we use `github.actor` instead.
    - When using PATs tied to specific service users, store username here.
- `REGISTRY_PAT`
    - Personal access token or service token with:
      - For GHCR: `write:packages` scope (push) and `read:packages` if needed.
    - **MUST** follow least-privilege: only the minimal scopes needed.

For the **reusable Kaniko workflow** in `.github` we expose:
- Secrets (workflow_call):
    - `REGISTRY_TOKEN` (required)
      - Map from `REGISTRY_PAT` or the builtin `GITHUB_TOKEN` in caller workflows.
    - `REGISTRY_USERNAME` (optional)
        - Map from org/env `REGISTRY_USERNAME` if used.
- Input:
    - `registry` (default: `ghcr.io`)
    - Caller sets this using `REGISTRY_URL` when needed.

**Important:** Secrets **must never** be printed in logs or echoed in scripts
(REQ-REGISTRY-002, TC-REGISTRY-LOG-001).

---

## 3. Kaniko Caching Strategy
### 3.1. Why Caching?

Kaniko caching significantly speeds up repeated builds by reusing base image
layers and intermediate build steps:
- First build: builds all layers, pushes image and cache.
- Subsequent builds (with unchanged Dockerfile/deps): reuse cached layers.

This supports **faster CI** and lower registry traffic (REQ-REGISTRY-003).

### 3.2. Cache Repository Convention

We derive cache repositories from the image name:
- Default pattern (in reusable workflow):
    ```text
    <image_name>-cache
    ```

Examples:
- For `ghcr.io/brikbyte-studios/example-node-api`:
    - Cache repo: `ghcr.io/brikbyte-studios/example-node-api-cache`

This ensures:
- Cache is scoped per service.
- Minimal cross-service cache pollution.

Alternatively, callers may specify a dedicated cache repo via the
cache_repo input:
```yaml
with:
  cache_repo: ghcr.io/brikbyte-studios/cache/example-node-api
```

---

## 4. Reusable Workflow Behavior

The reusable workflow in `BrikByte-Studios/.github`:
- File: `.github/workflows/ci-build-kaniko.yml`
- Core behaviors:
  - Accepts:
    - `image_name`, `dockerfile`, `context`, `tags`, `registry`
    - `cache_enabled`, `cache_repo`
  - Performs:
    - Registry login using `docker/login-action`:
      - `registry`: input (default `ghcr.io`)
      - `username`: REGISTRY_USERNAME secret if present, else `github.actor`
      - `password`: REGISTRY_TOKEN secret
    - Tag normalization (comma or newline → newline).
    - Combines `image_name` + `tag` into full destinations:
      - `ghcr.io/brikbyte-studios/<service>:<tag>`
    - Kaniko build with caching:
      - `cache`: true or false based on `cache_enabled`.
      - `cache-repository` either:
        - Explicit `cache_repo`, or
        - Derived `<image_name>-cache`.

---

## 5. Onboarding a New Repo to Use Registry + Cache
### Step 1 — Select Image Name

Pick a canonical name under `ghcr.io/brikbyte-studios`:
```text
ghcr.io/brikbyte-studios/<service-name>
# e.g. ghcr.io/brikbyte-studios/church_business_directory-api
```

### tep 2 — Configure Secrets

At org or environment level:
- Create/update:
    - `REGISTRY_URL = ghcr.io`
    - `REGISTRY_PAT = <GHCR PAT or rely on GITHUB_TOKEN>`
    - (Optional) `REGISTRY_USERNAME = <gh-username-or-service-account>`

In the repo workflow, map these into the reusable workflow:
```yaml
secrets:
  REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }} # or: secrets.REGISTRY_PAT
  REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
```

For GHCR, `GITHUB_TOKEN` is sufficient as long as the repo has
`packages: write` permission.

### Step 3 — Add or Update the Caller Workflow

Example (Node API monorepo):
```yaml
jobs:
  build-and-push:
    uses: BrikByte-Studios/.github/.github/workflows/ci-build-kaniko.yml@main
    with:
      image_name: ghcr.io/brikbyte-studios/example-node-api
      context: .
      dockerfile: ./node-api-example/Dockerfile
      tags: |
        v0.1.0
        sha-${{ github.sha }}
      registry: ghcr.io
      cache_enabled: true
      # Optional override for cache repo:
      # cache_repo: ghcr.io/brikbyte-studios/cache/example-node-api
    secrets:
      REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
```

### Step 4 — Validate Caching

1. Run the workflow once:
    - Build should complete and push image + cache.

2. Run the workflow again with no code change:
    - Kaniko logs should show **cache hits** for multiple layers.
    - Overall build time should be noticeably lower.

---

## 6. Security & Compliance
- Tokens **must** be:
    - Stored as GitHub secrets only.
    - Scoped minimally (GHCR: `write:packages`).
- Rotation:
    - Follow org-level token rotation practices.
    - Update `REGISTRY_PAT` at org/env level; no per-repo changes needed.
- Verification:
    - A Security Engineer should:
        - Confirm scopes.
        - Review logs from sample runs to ensure no secret leakage.