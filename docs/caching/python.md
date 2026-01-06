# Python Cache

| Tool | Cached |
| --- | --- |
| pip | `~/.cache/pip` |
| poetry | same |
| pipenv | same |

Virtualenv folders are NOT cached — only wheels.
```yaml
- uses: BrikByte-Studios/brik-pipe-actions/.github/actions/cache-python@v1
```