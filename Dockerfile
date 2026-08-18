# Dockerfile — extends upstream tingly-box NPX image with dev tools and agent CLIs
#
# Base image: ghcr.io/tingly-dev/tingly-box (node:20-slim based, user "tingly")
# Adds: Claude Code, Codex CLIs, Python3 + venv, uv, npx, git, curl
# This lets you run MCP tools, perform OAuth, and install additional packages inside the container.

ARG TINGLY_VERSION=latest
FROM ghcr.io/tingly-dev/tingly-box:${TINGLY_VERSION}

USER root

# Install system packages:
# git          — required by Claude Code for repo operations
# curl         — debugging/health checks
# openssh-client — git SSH operations
# procps       — process management (pm2 etc.)
# python3 + python3-venv — Python for MCP tools that need it
# pip          — Python package installer
# build-essential — compiler toolchain for pip packages with C extensions
# jq           — JSON parsing for scripting
# bash         — already present but explicit for MCP tools that call bash
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    openssh-client \
    procps \
    python3 \
    python3-venv \
    python3-pip \
    build-essential \
    jq \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package installer/runner)
# Install to /usr/local/bin so it's accessible to all users
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh && \
    chmod 755 /usr/local/bin/uv /usr/local/bin/uvx

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Install OpenAI Codex CLI globally
RUN npm install -g @openai/codex

# Create persistent directories for OAuth tokens and Python venvs
# /home/tingly/.claude  — Claude Code OAuth tokens
# /home/tingly/.codex   — Codex OAuth tokens
# /home/tingly/.local   — uv cache, pip user installs
# /app/mcp              — workspace for any MCP tools you clone/install
RUN mkdir -p /home/tingly/.claude /home/tingly/.codex /home/tingly/.local /app/mcp && \
    chown -R tingly:tingly /home/tingly /app

# Switch back to non-root user
USER tingly

# Set PATH so uv/uvx and local bin are available
ENV PATH="/home/tingly/.local/bin:/usr/local/bin:${PATH}"

# Verify installations
RUN claude --version && codex --version && uv --version && python3 --version && npx --version

# Keep the upstream CMD intact — tingly-box via pm2