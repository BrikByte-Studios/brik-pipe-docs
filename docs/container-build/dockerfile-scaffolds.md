# Dockerfile Scaffolds (BrikByteOS v1)

These Dockerfile scaffolds provide copy-pasteable defaults for:
- Node
- Python
- Java (Maven)
- .NET
- Go

## Design principles
- Cache-first layering (deps before source)
- Multi-stage builds for smaller images
- Non-root runtime where feasible
- OCI labels for traceability (source, revision, created)
- No secrets baked into images

## Standard build args (all stacks)
- IMAGE_SOURCE
- VCS_REF
- BUILD_DATE

## Recommended .dockerignore
Each scaffold includes a tuned `.dockerignore`. Use it. It matters.

## Where these live
- Source of truth: `brik-pipe-actions/templates/dockerfiles/*`
- Golden path validation: `brik-pipe-examples/*/Dockerfile`

## Local build example
```bash
docker build \
  --build-arg IMAGE_SOURCE="https://github.com/ORG/REPO" \
  --build-arg VCS_REF="$(git rev-parse HEAD)" \
  --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -t my-service:dev .
```

## Notes on determinism
- Node: use lockfiles + `npm ci`
- Python: build wheels and install from wheelhouse
- Java: `dependency:go-offline` cache layer
- .NET: restore layer separated from publish
- Go: pinned toolchain + static build

## Security baseline
- No secrets in Dockerfile
- Non-root runtime where feasible
- Keep base images minimal and current

