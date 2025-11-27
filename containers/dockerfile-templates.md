# Dockerfile Templates for BrikByteOS Services  
_Task: PIPE-CONTAINER-DOCKER-BUILD-002_

BrikByteOS provides **canonical Dockerfile scaffolds** for each supported runtime so that teams start with:

- Multi-stage builds (builder + runtime)  
- Non-root runtime users  
- Slim, production-grade images  
- Standard OCI labels and healthcheck placeholders  

## 1. Where Templates Live

**Repo:** `BrikByte-Studios/.github`

```text
.github/
  templates/
    Dockerfile.node
    Dockerfile.python
    Dockerfile.java
    Dockerfile.dotnet
    Dockerfile.go
```

These are **reference templates**. Teams should copy & adapt them into their services.

## 2. Example Integrations

Concrete examples live in:

- `BrikByte-Studios/brik-pipe-examples/node-api-example/Dockerfile`
- `BrikByte-Studios/brik-pipe-examples/python-api-example/Dockerfile`
- `BrikByte-Studios/brik-pipe-examples/java-api-example/Dockerfile`
- `BrikByte-Studios/brik-pipe-examples/dotnet-api-example/Dockerfile`
- `BrikByte-Studios/brik-pipe-examples/go-api-example/Dockerfile`

Each example:
- Builds and runs with `docker build` / `docker run`.
- Uses non-root runtime stages.
- Exposes port `8080` for simple smoke tests.

## 3. How to Use the Templates in a New Service
1. **Choose the runtime template** (e.g. `Dockerfile.node`).
2. Copy it into your service repo as `Dockerfile`.
3. Adjust:
    - `EXPOSE` port to your app’s port.
    - `CMD` / `ENTRYPOINT` to match your actual startup command.
    - Any language-specific paths (`dist`, `build`, jar name, binary name).
4. Build and run locally:
```bash
docker build -t my-service .
docker run -p 8080:8080 my-service
```

5. Add a `/health` or `/ready` endpoint and wire a proper `HEALTHCHECK` in the Dockerfile.

## 4. Linting with hadolint

We recommend linting Dockerfiles with **hadolint**:
```bash
hadolint Dockerfile
```

CI integration will be added under separate tasks (`PIPE-CONTAINER-DOCKER-LINT-00X`), but teams can start using hadolint locally immediately.

## 5. Alignment with Container Build Strategy

These templates implement the baselines in:

- `brik-pipe-docs/containers/container-build-strategy.md`
    - Multi-stage builds are **mandatory** for production.
    - Runtime images **must not** run as root.
    - Standard labels must be preserved or extended, not removed.

For any deviation (e.g., custom base image), document it in the service `README` and, if recurring, propose an ADR.