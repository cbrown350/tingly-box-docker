#!/bin/bash
# entrypoint.sh — sets up MCP tool dependencies on first boot, then starts tingly-box
# This runs as the tingly user inside the container.

set -e

echo "=== Tingly Box Docker Entry Point ==="

# ── Install Node MCP dependencies (if package.json exists and node_modules doesn't) ──
for dir in /app/mcp/openfusion /app/mcp/redlib-mcp-server /app/mcp/medical-mcp; do
    if [ -f "$dir/package.json" ] && [ ! -d "$dir/node_modules" ]; then
        echo "Installing Node dependencies for $(basename $dir)..."
        cd "$dir" && npm install --production 2>&1 | tail -3 || echo "WARNING: npm install failed for $(basename $dir)"
    fi
done

# ── Install Python MCP: mealie-mcp ──
if [ -f "/app/mcp/mealie-mcp/pyproject.toml" ] && [ ! -d "/app/mcp/mealie-mcp/.venv" ]; then
    echo "Setting up mealie-mcp Python venv..."
    cd /app/mcp/mealie-mcp && uv venv && uv pip install -e . 2>&1 | tail -3 || echo "WARNING: mealie-mcp setup failed"
fi

# ── Install Python MCP: kb ──
if [ -f "/app/mcp/kb/pyproject.toml" ] && [ ! -d "/app/mcp/kb/.venv" ]; then
    echo "Setting up kb Python venv..."
    cd /app/mcp/kb && uv venv && uv pip install -e . 2>&1 | tail -3 || echo "WARNING: kb setup failed"
fi

# ── Start tingly-box (original CMD) ──
echo "=== Starting Tingly Box ==="
exec tingly-box restart --host ${TINGLY_HOST:-0.0.0.0} --port ${TINGLY_PORT:-12580} ${TINGLY_DEBUG:+--verbose --debug}