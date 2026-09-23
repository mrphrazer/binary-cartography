#!/usr/bin/env bash
set -euo pipefail

# build context = directory containing this script (Dockerfile + compose.yaml)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# runtime mount = directory where you invoke the script
HOST_PWD="$(pwd -P)"

# Optional Binary Ninja installation: an explicit path or a ZIP next to this script.
BINARY_NINJA_ZIP="${BINARY_NINJA_ZIP:-}"
if [[ -z "$BINARY_NINJA_ZIP" && -f "$SCRIPT_DIR/binaryninja.zip" ]]; then
  BINARY_NINJA_ZIP="$SCRIPT_DIR/binaryninja.zip"
fi
INSTALL_BINARY_NINJA=0
if [[ -n "$BINARY_NINJA_ZIP" ]]; then
  if [[ ! -f "$BINARY_NINJA_ZIP" ]]; then
    echo "[error] Binary Ninja archive not found: $BINARY_NINJA_ZIP" >&2
    exit 1
  fi
  INSTALL_BINARY_NINJA=1
  echo "[info] installing Binary Ninja from $BINARY_NINJA_ZIP"
fi

# buildx builder (idempotent)
docker buildx create --use --name training >/dev/null 2>&1 || docker buildx use training
docker buildx inspect --bootstrap >/dev/null 2>&1 || true

# Persist Claude auth/settings on the host.
CLAUDE_USER_DIR="${CLAUDE_USER_DIR:-$HOME/.claude-docker}"
mkdir -p "$CLAUDE_USER_DIR"

# Persist Codex auth/state on the host.
CODEX_USER_DIR="${CODEX_USER_DIR:-$HOME/.codex-docker}"
mkdir -p "$CODEX_USER_DIR"

# Persist Pi authentication, settings, and sessions on the host.
PI_USER_DIR="${PI_USER_DIR:-$HOME/.pi-docker}"
mkdir -p "$PI_USER_DIR/agent"

# Keep the license and Binary Ninja user state outside the image.
BINARY_NINJA_USER_DIR="${BINARY_NINJA_USER_DIR:-$HOME/.binaryninja-docker}"
mkdir -p "$BINARY_NINJA_USER_DIR"
if [[ ! -f "$BINARY_NINJA_USER_DIR/license.dat" && -f "$HOME/.binaryninja/license.dat" ]]; then
  install -m 0600 "$HOME/.binaryninja/license.dat" "$BINARY_NINJA_USER_DIR/license.dat"
fi

IMAGE_REPO="binary-cartography-deobfuscation"

# Include the optional archive so different Binary Ninja builds get distinct tags.
DOCKERFILE_SHA="$(
  {
    sha256sum < "$SCRIPT_DIR/Dockerfile"
    printf '%s\n' "INSTALL_BINARY_NINJA=$INSTALL_BINARY_NINJA"
    if [[ "$INSTALL_BINARY_NINJA" == "1" ]]; then
      sha256sum < "$BINARY_NINJA_ZIP"
    fi
  } | sha256sum | awk '{print $1}'
)"
SHORT_SHA="${DOCKERFILE_SHA:0:12}"
HASH_IMAGE="${IMAGE_REPO}:${SHORT_SHA}"

# Build only if missing
if ! docker image inspect "$HASH_IMAGE" >/dev/null 2>&1; then
  echo "[build] building $HASH_IMAGE"
  BINJA_STAGE_DIR="$(mktemp -d)"
  cleanup_binja_stage() { rm -rf "$BINJA_STAGE_DIR"; }
  trap cleanup_binja_stage EXIT
  if [[ "$INSTALL_BINARY_NINJA" == "1" ]]; then
    ln -L -- "$BINARY_NINJA_ZIP" "$BINJA_STAGE_DIR/binaryninja.zip" 2>/dev/null \
      || cp "$BINARY_NINJA_ZIP" "$BINJA_STAGE_DIR/binaryninja.zip"
  fi
  docker buildx build \
    --build-arg "INSTALL_BINARY_NINJA=$INSTALL_BINARY_NINJA" \
    --build-context "binja-stage=$BINJA_STAGE_DIR" \
    -t "$HASH_IMAGE" \
    --load \
    "$SCRIPT_DIR"
  cleanup_binja_stage
  trap - EXIT
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

# Seed Pi credentials without replacing an existing Docker login.
if [[ ! -f "$PI_USER_DIR/agent/auth.json" && -f "$HOME/.pi/agent/auth.json" ]]; then
  install -m 0600 "$HOME/.pi/agent/auth.json" "$PI_USER_DIR/agent/auth.json"
fi

# These must be in the environment of the docker compose process
HOST_PWD="$HOST_PWD" \
CLAUDE_USER_DIR="$CLAUDE_USER_DIR" \
CODEX_USER_DIR="$CODEX_USER_DIR" \
PI_USER_DIR="$PI_USER_DIR" \
BINARY_NINJA_USER_DIR="$BINARY_NINJA_USER_DIR" \
IMAGE_TAG="$SHORT_SHA" \
exec docker compose \
  --project-directory "$SCRIPT_DIR" \
  -f "$SCRIPT_DIR/compose.yaml" \
  run --rm --pull never kali "$@"
