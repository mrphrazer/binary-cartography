#!/usr/bin/env bash
set -euo pipefail

# build context = directory containing this script (Dockerfile + compose.yaml)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# runtime mount = directory where you invoke the script
HOST_PWD="$(pwd -P)"

# buildx builder (idempotent)
docker buildx create --use --name training >/dev/null 2>&1 || docker buildx use training
docker buildx inspect --bootstrap >/dev/null 2>&1 || true

# Ghidra headless MCP repo is cloned into the mounted workspace so the agent
# can inspect and edit it.  The extension itself is built inside the image.
MCP_DIR="$HOST_PWD/mcp"
mkdir -p "$MCP_DIR"
GHIDRA_MCP_REPO_URL="${GHIDRA_MCP_REPO_URL:-https://github.com/mrphrazer/ghidra-headless-mcp.git}"

ensure_mcp_repo() {
  local name="$1"
  local url="$2"
  local dest="$MCP_DIR/$name"

  if [[ -d "$dest/.git" ]]; then
    echo "[mcp] updating $name"
    git -C "$dest" pull --ff-only
    return
  fi

  if [[ -e "$dest" ]]; then
    echo "[warn] MCP path exists and is not a git checkout: $dest" >&2
    echo "[warn] leaving it unchanged" >&2
    return
  fi

  echo "[mcp] cloning $name"
  git clone --depth 1 "$url" "$dest"
}

ensure_mcp_repo "ghidra-headless-mcp" "$GHIDRA_MCP_REPO_URL"

# Persist Claude auth/settings on the host.
CLAUDE_USER_DIR="${CLAUDE_USER_DIR:-$HOME/.claude-docker}"
mkdir -p "$CLAUDE_USER_DIR"

# Persist Codex auth/state on the host.
CODEX_USER_DIR="${CODEX_USER_DIR:-$HOME/.codex-docker}"
mkdir -p "$CODEX_USER_DIR"

IMAGE_REPO="kali-re-tools"

# Build input checksum tag (short) — only the Dockerfile drives the image
# because every helper script is inlined into it.
DOCKERFILE_SHA="$(sha256sum "$SCRIPT_DIR/Dockerfile" | awk '{print $1}')"
SHORT_SHA="${DOCKERFILE_SHA:0:12}"
HASH_IMAGE="${IMAGE_REPO}:${SHORT_SHA}"

# Build only if missing
if ! docker image inspect "$HASH_IMAGE" >/dev/null 2>&1; then
  echo "[build] building $HASH_IMAGE"
  docker buildx build \
    -t "$HASH_IMAGE" \
    --load \
    "$SCRIPT_DIR"
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
