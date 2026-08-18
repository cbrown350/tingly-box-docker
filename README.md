# Tingly Box Docker

Docker deployment for [Tingly Box](https://github.com/tingly-dev/tingly-box) — an AI model gateway that proxies and routes requests across multiple AI providers. This repo packages the upstream image with dev tools and agent CLIs pre-installed.

## What's Included

- `Dockerfile` — Extends `ghcr.io/tingly-dev/tingly-box` with:
  - Claude Code (`@anthropic-ai/claude-code`)
  - OpenAI Codex (`@openai/codex`)
  - Python 3 + venv, uv/uvx, npx, git, curl, jq, build-essential
- `docker-compose.yml` — Deployment with persistent volumes and env-based configuration
- `.env.example` — Template for environment variables
- `.github/workflows/auto-rebuild.yml` — CI that polls upstream for new releases and auto-rebuilds the image to GHCR

## Quick Start

1. Copy the env template and fill in your values:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

2. Place your `config.json` in `./data/.tingly-box/config.json` (see Migrating below).

3. Build and start:
   ```bash
   docker compose up -d --build
   ```

4. Access the web UI at `http://localhost:12580/dashboard?user_auth_token=<your-token>`

## Configuration

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `TINGLY_VERSION` | `latest` | Upstream image tag to build from |
| `TINGLY_HOST` | `0.0.0.0` | Bind address inside container |
| `TINGLY_PORT` | `12580` | Host port mapped to container's 12580 |
| `TINGLY_DEBUG` | `false` | Enable verbose logging |

If your `config.json` references additional env vars for MCP tools or API keys, add them to `.env` and pass them through in `docker-compose.yml` under the `environment` section.

### Volumes

| Host path | Container path | Purpose |
|---|---|---|
| `./data/.tingly-box/` | `/app/.tingly-box` | Main data home (config.json, db, keys) |
| `./data/memory/` | `/app/memory` | Memory store |
| `./data/logs/` | `/app/logs` | Log files |
| `./data/.claude/` | `/home/tingly/.claude` | Claude Code OAuth tokens |
| `./data/.codex/` | `/home/tingly/.codex` | Codex OAuth tokens |
| `./data/mcp/` | `/app/mcp` | Workspace for MCP tools you install |
| `./data/.local/` | `/home/tingly/.local` | uv/pip user installs (persisted) |

### Migrating an Existing Instance

1. Copy your existing `~/.tingly-box/config.json` to `./data/.tingly-box/config.json`
2. Copy your `~/.tingly-box/db/` directory to `./data/.tingly-box/db/`
3. Copy your `~/.tingly-box/keys/` directory to `./data/.tingly-box/keys/`
4. Copy `~/.tingly-box/skill_locations.json` to `./data/.tingly-box/`
5. Copy `~/.tingly-box/provider_template.json` to `./data/.tingly-box/`
6. Add any API keys or env vars your config references to `.env`
7. `docker compose up -d --build`

## Claude Code & Codex OAuth

The container includes both CLIs. To perform OAuth:

1. Enter the running container:
   ```bash
   docker compose exec tingly-box bash
   ```

2. Run Claude Code login:
   ```bash
   claude login
   ```

3. Run Codex login:
   ```bash
   codex login
   ```

OAuth tokens persist in `./data/.claude/` and `./data/.codex/`, surviving container restarts.

## Installing MCP Tools Inside the Container

The image includes Python 3 + venv, uv/uvx, npx, and build-essential. You can install MCP tools at runtime:

```bash
# Enter the container
docker compose exec tingly-box bash

# Python MCP tool via uv
cd /app/mcp
git clone https://github.com/example/some-mcp.git
cd some-mcp
uv venv && uv pip install -e .
# Update config.json to point to /app/mcp/some-mcp/.venv/bin/python

# Node MCP tool via npx (no install needed — npx fetches at runtime)
# Just set command: "npx" and args: ["-y", "@some/mcp-server"]
```

The `/app/mcp` volume is persisted in `./data/mcp/`, so installed tools survive container rebuilds.

## Updating

To pull the latest upstream version:

```bash
docker compose pull
docker compose up -d --build
```

Or pin a specific release in `.env`:
```
TINGLY_VERSION=v0.260813.2
```

The GitHub Actions workflow automatically checks for new upstream releases every 6 hours and builds a new image to GHCR.

## Logs

```bash
docker compose logs -f tingly-box
```

## License

The upstream Tingly Box project is MPL-2.0. This deployment config is provided as-is.