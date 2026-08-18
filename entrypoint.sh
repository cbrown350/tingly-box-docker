#!/bin/bash
# entrypoint.sh — first-boot setup for MCP tools, then starts tingly-box.
#
# Runs as root first to normalize ownership of the mounted data volumes
# (works when data/ was copied from another machine — macOS or Linux —
# where the files carry a different uid). Then drops privileges to the
# tingly user (uid 999) and runs the actual server.
#
# Scans /app/mcp/ for any subdirectory containing package.json or
# pyproject.toml and installs dependencies if not already present.
# This is generic and works with any MCP tools the user places in the
# mounted ./data/mcp/ volume.

set -e

# ─────────────────────────────────────────────
# 1. ROOT PHASE — normalize ownership of mounts
# ─────────────────────────────────────────────
if [ "$(id -u)" = "0" ]; then
    echo "=== Tingly Box Docker Entry Point (root phase) ==="

    TINGLY_UID=$(id -u tingly)
    TINGLY_GID=$(id -g tingly)

    # Fix ownership of every mounted persistent volume so the tingly user
    # can read/write them regardless of the uid they were copied with.
    # Use find to also cover dotfile dirs (.claude, .codex, .litellm...).
    # Only chown when needed (cheap check, avoids slow recursive chowns
    # on every boot when nothing changed).
    for d in /app /home/tingly; do
        [ -d "$d" ] || continue
        if [ "$(stat -c '%u' "$d")" != "$TINGLY_UID" ]; then
            echo "  Fixing ownership of $d ..."
            chown -R "$TINGLY_UID:$TINGLY_GID" "$d" 2>/dev/null || true
        else
            find "$d" -mindepth 1 -maxdepth 1 ! -user "$TINGLY_UID" -exec chown -R "$TINGLY_UID:$TINGLY_GID" {} + 2>/dev/null || true
        fi
    done

    # Re-exec ourselves as the tingly user
    exec setpriv --reuid="$TINGLY_UID" --regid="$TINGLY_GID" --clear-groups "$0" "$@"
fi

# ─────────────────────────────────────────────
# 2. USER PHASE — MCP dependency setup + run
# ─────────────────────────────────────────────
# setpriv keeps the root environment; HOME must point at the tingly home
# so tools (uv, tingly-box, npm) use /home/tingly/.cache instead of /root
export HOME=/home/tingly

# Pin Python to 3.12 for all uv-created venvs and uvx runs: 3.13/3.14 lack
# prebuilt wheels for some MCP dependencies (pydantic-core, lxml), forcing
# source builds that need cargo/libxml2. 3.12 has wheels for everything.
export UV_PYTHON=3.12

echo "=== Tingly Box Docker Entrypoint (user phase) ==="

MCP_DIR="/app/mcp"

if [ -d "$MCP_DIR" ]; then
    # ── Node MCP tools: npm install where package.json exists but node_modules doesn't ──
    for pkgjson in "$MCP_DIR"/*/package.json; do
        [ -f "$pkgjson" ] || continue
        dir=$(dirname "$pkgjson")
        name=$(basename "$dir")
        if [ ! -d "$dir/node_modules" ]; then
            echo "Installing Node dependencies for $name..."
            (cd "$dir" && npm install --production 2>&1 | tail -3) || echo "WARNING: npm install failed for $name"
        else
            echo "Node dependencies already present for $name, skipping."
        fi
    done

    # ── Python MCP tools ──
    for pyproject in "$MCP_DIR"/*/pyproject.toml; do
        [ -f "$pyproject" ] || continue
        dir=$(dirname "$pyproject")
        name=$(basename "$dir")
        if [ ! -d "$dir/.venv" ]; then
            echo "Setting up Python venv for $name..."
            (cd "$dir" && uv venv 2>&1 | tail -2)
            # Install deps: requirements.txt if present (explicit), else editable pyproject
            if [ -f "$dir/requirements.txt" ]; then
                echo "  Installing from requirements.txt for $name..."
                (cd "$dir" && uv pip install -r requirements.txt 2>&1 | tail -3) || echo "WARNING: requirements install failed for $name"
            fi
            # Editable install when pyproject declares a package ([project]) — makes the
            # module importable from any cwd (some MCP launchers don't set a working dir)
            if grep -q '^\[project\]' "$pyproject"; then
                echo "  Installing editable package for $name..."
                (cd "$dir" && uv pip install -e . 2>&1 | tail -3) || echo "WARNING: editable install failed for $name"
            fi
        else
            echo "Python venv already present for $name, skipping."
        fi
    done
fi

# ── Start tingly-box ──
echo "=== Starting Tingly Box ==="
# --config-dir /app/.tingly-box : use the mounted persistent config
#   (providers, rules, keys, db) instead of a fresh one in $HOME
exec tingly-box restart --config-dir /app/.tingly-box \
    --host "${TINGLY_HOST:-0.0.0.0}" \
    --port "${TINGLY_PORT:-12580}" \
    ${TINGLY_DEBUG:+--verbose --debug}