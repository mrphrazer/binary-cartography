# syntax=docker/dockerfile:1.7
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive \
    BN_USER_DIRECTORY=/home/agent/.binaryninja
ARG CAPA_VERSION=9.3.1
ARG INSTALL_BINARY_NINJA=0

# Base utils + privilege drop helper
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo gosu curl ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*

# Node.js and analysis tools, including Ghidra from the Kali package repository.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    build-essential gcc g++ clang lld llvm cmake pkg-config ninja-build htop \
    binutils binutils-multiarch elfutils patchelf file \
    jq ssdeep detect-it-easy \
    nasm radare2 ascii bsdextrautils \
    hexedit bvi xxd ht hexwalk \
    lsof procps \
    python3 python3-pip python3-venv python3-dev python3-all-dev \
    git vim wget coreutils moreutils ripgrep \
    zip unzip xz-utils p7zip-full lz4 zstd \
    binwalk \
    yara upx-ucl qemu-user yq \
    bison flex libffi-dev libncurses-dev libsqlite3-dev mcpp sqlite3 zlib1g-dev \
    ghidra \
 && rm -rf /var/lib/apt/lists/* \
 && command -v ghidra \
 && ln -sf /usr/share/ghidra/support/analyzeHeadless /usr/local/bin/analyzeHeadless \
 && test -x /usr/local/bin/analyzeHeadless \
 && node -v && npm -v

# Python development and binary-analysis tools
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    pytest ruff flare-floss uv ipython ipdb \
    capstone unblob 'unicorn>=2,<3'

ENV GHIDRA_INSTALL_DIR=/usr/share/ghidra

# Keep complete source checkouts, including Git history and any submodules.
# Editable installs let agents use and adapt the source directly under /opt.
RUN git clone --recurse-submodules https://github.com/mrphrazer/msynth.git /opt/msynth \
 && python3 -m pip install --no-cache-dir --break-system-packages \
      -r /opt/msynth/requirements.txt -e /opt/msynth \
 && unzip -q /opt/msynth/database/3_variables_constants_7_nodes.txt.zip -d /opt/msynth/database

RUN git clone --recurse-submodules https://github.com/mrphrazer/ghidra-headless-mcp.git /opt/ghidra-headless-mcp \
 && python3 -m pip install --no-cache-dir --break-system-packages -e /opt/ghidra-headless-mcp \
 && ghidra-headless-mcp --version \
 && python3 -c 'import unicorn; from msynth import Simplifier, Synthesizer; assert unicorn.__version__.split(".")[0] == "2"'

RUN git clone --recurse-submodules https://github.com/mrphrazer/binary-ninja-headless-mcp.git /opt/binary-ninja-headless-mcp \
 && python3 -m pip install --no-cache-dir --break-system-packages -e /opt/binary-ninja-headless-mcp \
 && binja-cli list --names-only > /dev/null

# The launcher supplies an empty context when no Binary Ninja ZIP is provided.
# Mounting the archive for this step keeps the ZIP out of the image layers.
RUN --mount=type=bind,from=binja-stage,target=/tmp/binja-stage \
    set -eu; \
    if [ "${INSTALL_BINARY_NINJA}" != "1" ]; then exit 0; fi; \
    zipfile=/tmp/binja-stage/binaryninja.zip; \
    test -f "${zipfile}"; \
    tmpdir="$(mktemp -d)"; \
    unzip -q "${zipfile}" -d "${tmpdir}"; \
    install_api="$(find "${tmpdir}" -type f -path '*/scripts/install_api.py' -print -quit)"; \
    if [ -z "${install_api}" ]; then \
      echo "Binary Ninja archive does not contain scripts/install_api.py" >&2; \
      exit 1; \
    fi; \
    bn_root="$(dirname "$(dirname "${install_api}")")"; \
    mv "${bn_root}" /opt/binaryninja; \
    python3 /opt/binaryninja/scripts/install_api.py --silent --install-on-root; \
    rm -rf "${tmpdir}"

# Install capa standalone so the bundled rules/signatures are available to all users
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) capa_asset="capa-v${CAPA_VERSION}-linux.zip" ;; \
      arm64) capa_asset="capa-v${CAPA_VERSION}-linux-arm64.zip" ;; \
      *) echo "unsupported architecture for capa: $arch" >&2; exit 1 ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "https://github.com/mandiant/capa/releases/download/v${CAPA_VERSION}/${capa_asset}" \
        -o "${tmpdir}/${capa_asset}"; \
    unzip -q "${tmpdir}/${capa_asset}" -d /opt/capa; \
    install -m 0755 /opt/capa/capa /usr/local/bin/capa; \
    rm -rf "${tmpdir}"; \
    capa --version

# detect-it-easy may expose `diec`; provide `die` alias + verify tools
RUN if ! command -v die >/dev/null 2>&1 && command -v diec >/dev/null 2>&1; then \
      ln -sf "$(command -v diec)" /usr/local/bin/die; \
    fi \
 && command -v xxd die floss ssdeep jq capa

# Create non-root user "agent" with sudo rights + workspace
RUN useradd -m -s /bin/bash agent \
 && usermod -aG sudo agent \
 && printf "agent ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/agent \
 && chmod 0440 /etc/sudoers.d/agent \
 && mkdir -p /agent && chown agent:agent /agent \
 && chown -R agent:agent /opt/msynth /opt/ghidra-headless-mcp /opt/binary-ninja-headless-mcp \
 && printf '%s\n' "export PS1='\\w\\\\$ '" > /home/agent/.bashrc \
 && chown agent:agent /home/agent/.bashrc

# Install Pi Agent with its own model and reasoning defaults.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
 && gosu agent pi --version

# Install Codex CLI (npm) and inline the codex wrapper on PATH
RUN npm i -g @openai/codex

RUN cat > /usr/local/bin/codex <<'CODEX_EOF' \
 && chmod 0755 /usr/local/bin/codex
#!/usr/bin/env bash
set -euo pipefail
REAL_CODEX=/usr/bin/codex

# Let Codex parse commands and option values. Only avoid conflicting permission
# defaults; never interpret words in the prompt after the explicit -- delimiter.
permission_config() {
  local key="${1%%=*}"
  key="${key//[[:space:]]/}"
  case "$key" in
    approval_policy|approval_policy.*|sandbox_mode|default_permissions|permissions|permissions.*|sandbox_workspace_write|sandbox_workspace_write.*) return 0 ;;
    *) return 1 ;;
  esac
}
expect_config=0
for arg in "$@"; do
  if (( expect_config )); then
    if permission_config "$arg"; then exec "$REAL_CODEX" "$@"; fi
    expect_config=0
    continue
  fi
  case "$arg" in
    --) break ;;
    --dangerously-bypass-approvals-and-sandbox|--yolo|--approve-for-me|--full-auto|-s|-s?*|--sandbox|--sandbox=*|-a|-a?*|--ask-for-approval|--ask-for-approval=*)
      exec "$REAL_CODEX" "$@" ;;
    -c|--config) expect_config=1 ;;
    --config=*)
      if permission_config "${arg#--config=}"; then exec "$REAL_CODEX" "$@"; fi ;;
    -c?*)
      value="${arg#-c}"
      if permission_config "${value#=}"; then exec "$REAL_CODEX" "$@"; fi ;;
  esac
done
exec "$REAL_CODEX" --dangerously-bypass-approvals-and-sandbox "$@"
CODEX_EOF

# Install Claude Code CLI (native installer) and inline the claude wrapper.
RUN set -eux; \
    printf '#!/bin/bash\ncurl -fsSL https://claude.ai/install.sh | bash\n' > /tmp/install-claude.sh; \
    chmod +x /tmp/install-claude.sh; \
    gosu agent env HOME=/home/agent USER=agent LOGNAME=agent /tmp/install-claude.sh; \
    rm -f /tmp/install-claude.sh; \
    mv /home/agent/.local/bin/claude /home/agent/.local/bin/claude-real

RUN cat > /home/agent/.local/bin/claude <<'CLAUDE_EOF' \
 && chmod 0755 /home/agent/.local/bin/claude \
 && chown agent:agent /home/agent/.local/bin/claude /home/agent/.local/bin/claude-real \
 && ln -sf /home/agent/.local/bin/claude /usr/local/bin/claude \
 && gosu agent env HOME=/home/agent USER=agent LOGNAME=agent claude --version
#!/usr/bin/env bash
set -euo pipefail
REAL_CLAUDE=/home/agent/.local/bin/claude-real

# Claude dispatches some commands before parsing global options. Preserve those
# entry points, and pass administrative commands through without session defaults.
case "${1:-}" in
  agents|attach|auth|auto-mode|daemon|doctor|gateway|import|install|logs|mcp|plugin|plugins|project|remote-control|respawn|rm|self-hosted-runner|setup-token|stop|kill|ultrareview|update|upgrade)
    exec "$REAL_CLAUDE" "$@" ;;
esac

# The native parser handles optional and multi-value arguments. An explicit
# permission choice takes precedence; --restricted forbids bypassPermissions.
for arg in "$@"; do
  case "$arg" in
    --) break ;;
    --dangerously-skip-permissions|--allow-dangerously-skip-permissions|--permission-mode|--permission-mode=*|--restricted)
      exec "$REAL_CLAUDE" "$@" ;;
  esac
done
exec "$REAL_CLAUDE" --dangerously-skip-permissions "$@"
CLAUDE_EOF

# Persist CLI state without generating or rewriting agent configuration.
RUN cat > /usr/local/bin/agent-entrypoint.sh <<'EOF' \
 && chmod 0755 /usr/local/bin/agent-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/agent USER=agent LOGNAME=agent
mkdir -p /home/agent/.codex /home/agent/.claude /home/agent/.pi/agent /home/agent/.binaryninja
chown agent:agent /home/agent/.codex /home/agent/.claude /home/agent/.pi /home/agent/.pi/agent /home/agent/.binaryninja

# Claude stores some state outside ~/.claude; keep it in the persistent mount.
CLAUDE_STATE=/home/agent/.claude/state.json
if [ ! -f "$CLAUDE_STATE" ]; then
  printf '%s\n' '{}' > "$CLAUDE_STATE"
fi
ln -sf "$CLAUDE_STATE" /home/agent/.claude.json
chown agent:agent "$CLAUDE_STATE" /home/agent/.claude.json

exec gosu agent "$@"
EOF

WORKDIR /agent
ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["/bin/bash"]
