#!/bin/bash
# entrypoint.sh — generic first-boot setup for MCP tools, then starts tingly-box.
# Runs as the tingly user inside the container.
#
# Scans /app/mcp/ for any subdirectory containing package.json or pyproject.toml
# and installs dependencies if they haven't been installed yet. This is generic
# and works with any MCP tools the user places in the mounted ./data/mcp/ volume.

set -e

echo "=== Tingly Box Docker Entry Point ==="

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

    # ── Python MCP tools: uv venv + install where pyproject.toml exists but .venv doesn't ──
    for pyproject in "$MCP_DIR"/*/pyproject.toml; do
        [ -f "$pyproject" ] || continue
        dir=$(dirname "$pyproject")
        name=$(basename "$dir")
        if [ ! -d "$dir/.venv" ]; then
            echo "Setting up Python venv for $name..."
            (cd "$dir" && uv venv && uv pip install -e . 2>&1 | tail -3) || echo "WARNING: Python setup failed for $name"
        else
            echo "Python venv already present for $name, skipping."
        fi
    done
fi

# ── Start tingly-box ──
echo "=== Starting Tingly Box ==="
exec tingly-box restart --host "${TINGLY_HOST:-0.0.0.0}" --port "${TINGLY_PORT:-12580}" ${TINGLY_DEBUG:+--verbose --debug}