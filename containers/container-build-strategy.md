# BrikByteOS Container Build Strategy (v1)
**Doc ID:** PIPE-CONTAINER-STRATEGY-INIT-001  
**Related ADR:** ADR-00X – Container Build Strategy (Docker vs Kaniko)  
**Scope:** BrikByteOS services, `brik-pipe-examples/*`, and future product repos

---

## 1. Purpose & Scope

This document defines the **opinionated container build strategy** for BrikByteOS v1.

It answers:

- Which tool is used to **build images in CI** (Kaniko vs Docker-in-Docker).
- What developers should use for **local builds**.
- How **build contexts** and **Dockerfiles** are structured.
- Which **security baselines** (multi-stage, non-root) are mandatory.
- How behavior differs across **dev / staging / prod** environments.

This strategy is implemented across:

- **Meta / templates:** `BrikByte-Studios/.github`
- **Docs:** `brik-pipe-docs`
- **Examples:** `brik-pipe-examples/*`
- **Product repos:** all containerized services built on BrikByteOS

---

## 2. Tooling Strategy: Docker vs Kaniko

### 2.1 CI (GitHub-hosted runners)

**Decision (v1):**

> **All CI container builds on GitHub-hosted runners MUST use Kaniko.**  
> Docker-in-Docker (DinD) is **prohibited** on hosted runners, except in tightly controlled self-hosted scenarios explicitly documented and approved by Platform + Security.

**Rationale:**

- GitHub-hosted runners have **no long-lived Docker daemon**; DinD adds complexity and risk.
- Kaniko can build images **without privileged access** to the Docker daemon.
- Aligns with supply-chain best practices (immutable build container, explicit context).

**Implications:**

- CI templates in `BrikByte-Studios/.github` use **Kaniko** as the default image builder.
- Future **Policy Gates** can verify:
  - Non-root user in runtime image
  - Multi-stage usage
  - Approved base image families (where enforced)

### 2.2 Local Developer Machines

> **Developers SHOULD use Docker locally** (`docker build`, `docker run`).

- Docker Desktop / Docker Engine remains the **primary local developer experience**.
- Kaniko is **not required** for local builds, but can be used for parity if desired.
- Local workflows should expose a single entrypoint, e.g.:
  - `make docker-build`
  - `make docker-run`

---

## 3. Build Context & Dockerfile Conventions

### 3.1 Build Context

**Single-service repo (most examples & small services):**

- Build context: **repo root** or **service root**.
- Example (`brik-pipe-examples/node-api-example`):

  ```bash
  # In CI and locally
  docker build -t my-node-api-example ./node-api-example
  ```

**Multi-service monorepo (future products):**
- Each service has its own context under `services/<name>/`.
- Build command:
```bash
docker build -t my-service ./services/my-service
```

**Rule**:

Build context MUST be as **narrow as practical** (service folder, not monorepo root) to minimize:
- **"Build time"**
- **"Attack surface"**
- **"Unnecessary file leakage into images"**


### 3.2 Dockerfile Naming Conventions

Default:
- `Dockerfile` in the build context directory.

Specialized variants (allowed):
- `Dockerfile.node` – Node-specific optimizations.
- `Dockerfile.api` – HTTP API image.
- `Dockerfile.worker` – background worker.

**Rule of thumb:**
- Use plain `Dockerfile` whenever possible.
- Only introduce suffixes when there are **clear, documented reasons** (e.g. separate API vs worker images).

### 3.3 Location

Examples (in `brik-pipe-examples`):
- Node: `brik-pipe-examples/node-api-example/Dockerfile`
- Python: `brik-pipe-examples/python-api-example/Dockerfile`
- Java: `brik-pipe-examples/java-api-example/Dockerfile`
- Go: `brik-pipe-examples/go-api-example/Dockerfile`
- .NET: `brik-pipe-examples/dotnet-api-example/Dockerfile`


Product repos should mirror this pattern per service.

---

## 4. Security Baselines (Mandatory)

These baselines apply to all production images:

1. **Multi-stage builds are required**
2. **Runtime image MUST run as non-root**
3. **Minimal base images where practical**
4. No secrets baked into images

### 4.1 Multi-Stage Requirement
**MUST:**
- Separate **build stage** and **runtime stage**.
- All compilers, dev tools, and build-only dependencies stay in the build stage.

#### Example (Node)
```dockerfile
# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app

# Install dependencies (with caching)
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Runtime (minimal, non-root)
FROM node:20-alpine AS runtime
WORKDIR /app

# Create non-root user
RUN addgroup -S nodegrp && adduser -S nodeuser -G nodegrp

# Only copy what we need
COPY --from=build /app/dist ./dist
COPY package*.json ./

USER nodeuser
EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### 4.2 Non-root Requirement
- **Runtime stage MUST NOT run as root.**
- Use `USER <non-root>` with:
  - A dedicated uid/gid
  - Correct filesystem permissions for app directories

#### Example (Python)
```dockerfile
FROM python:3.11-slim AS runtime
WORKDIR /app

# Create app user
RUN groupadd -r app && useradd -r -g app app

COPY . .
RUN pip install --no-cache-dir -r requirements.txt

USER app
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 5. Environment-Specific Strategy
### 5.1 Dev (Local)
- **Tool:** Docker
- **Typical flow:**
```bash
make docker-build       # wraps docker build
make docker-run         # wraps docker run
```
- Environment variables from:
    - `.env`
    - Docker Compose (optional, future)

**Goals:**
- Fast feedback.
- Parity with CI image where possible.

### 5.2 Staging (CI)
- **Tool:** Kaniko (mandatory on GitHub-hosted runners)
- Images pushed to **staging registry** (e.g. `registry.example.com/stage/...`).
- Tags typically include:
    - Commit SHA
    - Branch or environment
    - Optional build metadata (build number)

### 5.3 Prod
- **Tool:** Kaniko (same pipeline as staging, but protected branch + tags).
- Requirements (v1):
    - Multi-stage build enforced.
    - Non-root enforced.
    - Reproducible builds (tagging & build args).
    - Ready for future:
        - SBOM generation
        - Image signing
        - Policy Gate checks
---

## 6. Kaniko-Based CI Pattern (Illustrative)
**Repo:** `BrikByte-Studios/.github`  
**File (future):** `.github/workflows/template-container-build-kaniko.yml`

**Conceptual pattern (simplified):**
```yaml
name: "Template: Container Build (Kaniko)"

on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
      context:
        required: true
        type: string
      dockerfile:
        required: false
        type: string
        default: "Dockerfile"

jobs:
  kaniko-build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write   # for future OIDC → registry auth
      packages: write   # if using GHCR

    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Set image tags
        id: tags
        run: |
          SHA_TAG="${GITHUB_SHA::7}"
          echo "sha_tag=${SHA_TAG}" >> "$GITHUB_OUTPUT"
          echo "full_image=${{ inputs.image-name }}:${SHA_TAG}" >> "$GITHUB_OUTPUT"

      - name: Run Kaniko build
        # NOTE: This uses Docker to run Kaniko, but Kaniko itself does NOT rely on daemon-in-VM.
        run: |
          docker run --rm \
            -v "$PWD":/workspace \
            -v /kaniko/.docker:/kaniko/.docker \
            gcr.io/kaniko-project/executor:latest \
            --context "dir://workspace/${{ inputs.context }}" \
            --dockerfile "workspace/${{ inputs.context }}/${{ inputs.dockerfile }}" \
            --destination "${{ steps.tags.outputs.full_image }}" \
            --snapshotMode=redo \
            --use-new-run \
            --reproducible
```

**Note:** actual auth and registry configuration will be included in a future IaC & registry task. This is just the **strategy-aligned** pattern.

---

## 7. Discoverability & Links

This strategy is referenced from:

- `BrikByte-Studios/.github/README.md`:
    - Section: **Container Build Strategy**
- `brik-pipe-docs/README.md`:
    - Section: **Pipelines & Containers → Container Build Strategy**

---

## 8. Follow-Up & Enforcement

Future tasks (out of scope for this doc, but referenced):

- `PIPE-CONTAINER-LINT-XXX` — Dockerfile linting (multi-stage + non-root).
- `PIPE-GOV-CONTAINER-POLICY-XXX` — Policy Gates for container rules.
- `PIPE-CONTAINER-BUILDX-XXX` — Evaluate BuildKit / buildx / cloud builders.
- `PIPE-CONTAINER-SBOM-XXX` — SBOM and signing pipeline.

---

## 9. Summary

- **CI:** Kaniko mandatory on GitHub-hosted runners.
- **Local:** Docker recommended; Kaniko optional.
- **Security:** Multi-stage + non-root runtime is non-negotiable for production.
- **Structure:** Narrow build contexts, consistent Dockerfile naming, examples in `brik-pipe-examples/*.`
- **Governance:** Strategy formalized via ADR-00X and wired into CI templates and future policy gates.