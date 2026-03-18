#!/usr/bin/env bash
set -euo pipefail

# build context = directory containing this script (Dockerfile + compose.yaml)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# runtime mount = directory where you invoke the script
HOST_PWD="$(pwd -P)"

# buildx builder (idempotent)
docker buildx create --use --name training >/dev/null 2>&1 || docker buildx use training
docker buildx inspect --bootstrap >/dev/null 2>&1 || true

# Clone/update ghidra-headless-mcp into a cache dir (not in the build context)
GHIDRA_MCP_CACHE="${GHIDRA_MCP_CACHE:-$HOME/.cache/ghidra-headless-mcp}"
GHIDRA_MCP_REPO_URL="${GHIDRA_MCP_REPO_URL:-https://github.com/mrphrazer/ghidra-headless-mcp.git}"
if [[ -d "$GHIDRA_MCP_CACHE/.git" ]]; then
  echo "[mcp] updating ghidra-headless-mcp"
  git -C "$GHIDRA_MCP_CACHE" pull --ff-only
elif [[ ! -e "$GHIDRA_MCP_CACHE" ]]; then
  echo "[mcp] cloning ghidra-headless-mcp"
  git clone --depth 1 "$GHIDRA_MCP_REPO_URL" "$GHIDRA_MCP_CACHE"
fi

GHIDRA_MCP_REF="$(
  if [[ -d "$GHIDRA_MCP_CACHE/.git" ]]; then
    git -C "$GHIDRA_MCP_CACHE" rev-parse HEAD
  else
    find "$GHIDRA_MCP_CACHE" -type f -print | sort | xargs sha256sum | sha256sum | awk '{print $1}'
  fi
)"

# Persist Claude auth/settings on the host.
CLAUDE_USER_DIR="${CLAUDE_USER_DIR:-$HOME/.claude-docker}"
mkdir -p "$CLAUDE_USER_DIR"

# Persist Codex auth/state on the host.
CODEX_USER_DIR="${CODEX_USER_DIR:-$HOME/.codex-docker}"
mkdir -p "$CODEX_USER_DIR"

IMAGE_REPO="kali-re-tools"

# Build input checksum tag (short)
DOCKERFILE_SHA="$(
  {
    printf '%s\n' "$GHIDRA_MCP_REF"
    sha256sum "$SCRIPT_DIR/Dockerfile"
    find "$SCRIPT_DIR/docker-bin" -type f -print | sort | xargs sha256sum
  } | sha256sum | awk '{print $1}'
)"
SHORT_SHA="${DOCKERFILE_SHA:0:12}"
HASH_IMAGE="${IMAGE_REPO}:${SHORT_SHA}"

# Build only if missing
if ! docker image inspect "$HASH_IMAGE" >/dev/null 2>&1; then
  echo "[build] building $HASH_IMAGE"
  build_args=(
    --build-context "ghidra-mcp-stage=$GHIDRA_MCP_CACHE"
    -t "$HASH_IMAGE"
    --load
    "$SCRIPT_DIR"
  )
  docker buildx build "${build_args[@]}"
else
  echo "[build] up to date ($HASH_IMAGE)"
fi

# Convenience tag
docker tag "$HASH_IMAGE" "${IMAGE_REPO}:latest" >/dev/null 2>&1 || true

# Seed the Docker-specific Codex directory from a host auth file when available.
if [[ ! -f "$CODEX_USER_DIR/auth.json" && -f "$HOME/.codex/auth.json" ]]; then
  cp "$HOME/.codex/auth.json" "$CODEX_USER_DIR/auth.json"
fi

# Seed the Docker-specific Claude directory from a host Linux credentials file when available.
if [[ ! -f "$CLAUDE_USER_DIR/.credentials.json" && -f "$HOME/.claude/.credentials.json" ]]; then
  cp "$HOME/.claude/.credentials.json" "$CLAUDE_USER_DIR/.credentials.json"
fi
# These must be in the environment of the docker compose process
HOST_PWD="$HOST_PWD" \
CLAUDE_USER_DIR="$CLAUDE_USER_DIR" \
CODEX_USER_DIR="$CODEX_USER_DIR" \
IMAGE_TAG="$SHORT_SHA" \
exec docker compose \
  --project-directory "$SCRIPT_DIR" \
  -f "$SCRIPT_DIR/compose.yaml" \
  run --rm --pull never kali "$@"
