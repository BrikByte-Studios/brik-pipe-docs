# Node Cache (npm / pnpm / yarn)
## What It Does

Caches **package manager stores**, not `node_modules`.

| Tool | Cached |
| --- | --- |
| pnpm | `~/.pnpm-store` |
| yarn | `~/.cache/yarn` |
| npm | `~/.npm` |

## Minimal Enable (copy-paste)
```yaml
- uses: BrikByte-Studios/brik-pipe-actions/.github/actions/cache-node@v1
```

## Monorepo Example
```yaml
- uses: BrikByte-Studios/brik-pipe-actions/.github/actions/cache-node@v1
  with:
    working_directory: apps/api
```

## Lockfile Precedence
```pgsql
pnpm-lock.yaml > yarn.lock > package-lock.json
```