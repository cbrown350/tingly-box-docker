# VisionBridge Dockerfile — builds VisionBridge from source, pinned to a commit SHA.
#
# VisionBridge (https://github.com/thomasunise/visionbridge) has no released image
# and no git tags/releases yet, so there is nothing to pull from a registry. We
# build from source and pin the exact upstream commit so builds are reproducible.
# Bump VISIONBRIDGE_SHA when you want a newer upstream commit.
#
# Build: docker build -f visionbridge.Dockerfile -t visionbridge:local .
# Or in compose: build: { context: ., dockerfile: visionbridge.Dockerfile }

ARG VISIONBRIDGE_SHA=92c793feaee0df688a20cf71c4f135ba00ef9bd2
ARG VISIONBRIDGE_REPO=https://github.com/thomasunise/visionbridge

FROM python:3.12-slim AS builder

# ARGs reset at each FROM — re-declare inside this stage
ARG VISIONBRIDGE_SHA
ARG VISIONBRIDGE_REPO

# Tools to clone + build from source
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# GitHub disables uploadpack.allowReachableSHA1InWant, so we cannot
# `git fetch origin <sha>` directly. Instead clone the default branch
# (full history — repo is small) and checkout the pinned commit.
RUN git clone ${VISIONBRIDGE_REPO} /src/repo && \
    cd /src/repo && \
    git checkout ${VISIONBRIDGE_SHA}

# Install the package into a clean wheel/site-packages layer
WORKDIR /src/repo
RUN pip install --no-cache-dir --user .

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Copy the installed package from the builder (no git/build tools needed at runtime)
COPY --from=builder /root/.local /root/.local

ENV PATH="/root/.local/bin:${PATH}"

EXPOSE 8080

# Healthcheck against the OpenAI-compatible /v1/models endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:8080/v1/models', timeout=5)" || exit 1

CMD ["visionbridge", "serve", "--host", "0.0.0.0", "--port", "8080"]
