# syntax=docker/dockerfile:1.7
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
COPY docker-bin/ /opt/docker-bin/

# Base utils + privilege drop helper
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo gosu curl ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*

# --- Node.js repo (needs curl/gnupg from above) + all packages in one pass ---
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    build-essential clang lldb lld llvm cmake pkg-config ninja-build htop \
    binutils binutils-multiarch elfutils gdb gdb-multiarch patchelf file \
    jq ssdeep \
    nasm ascii bsdextrautils \
    hexedit bvi xxd ht hexwalk \
    strace ltrace lsof procps \
    python3 python3-pip python3-venv python3-dev \
    git vim wget coreutils moreutils ripgrep \
    zip unzip xz-utils p7zip-full lz4 zstd \
    binwalk \
    upx-ucl qemu-user yq \
    bison flex libffi-dev libncurses-dev libsqlite3-dev mcpp sqlite3 zlib1g-dev \
 && rm -rf /var/lib/apt/lists/* \
 && node -v && npm -v

# Install Python tooling system-wide
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    pytest ruff uv ipython ipdb \
    unblob

# Install Ghidra
RUN apt-get update && apt-get install -y --no-install-recommends ghidra \
 && rm -rf /var/lib/apt/lists/* \
 && command -v ghidra

# Install Ghidra headless MCP into /opt/ghidra-headless-mcp
RUN --mount=type=bind,from=ghidra-mcp-stage,target=/tmp/ghidra-mcp-stage \
    cp -a /tmp/ghidra-mcp-stage /opt/ghidra-headless-mcp \
 && python3 -m pip install --no-cache-dir --break-system-packages /opt/ghidra-headless-mcp

# Verify tools
RUN command -v xxd ssdeep jq

# Create non-root user "agent" with sudo rights + workspace
RUN useradd -m -s /bin/bash agent \
 && usermod -aG sudo agent \
 && printf "agent ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/agent \
 && chmod 0440 /etc/sudoers.d/agent \
 && mkdir -p /agent && chown agent:agent /agent

# Minimal shell config for the agent user
RUN printf '%s\n' "export PS1='\\w\\\\$ '" > /home/agent/.bashrc \
 && chown agent:agent /home/agent/.bashrc

# Install Codex CLI
RUN npm i -g @openai/codex

# Wrap Codex so interactive sessions default to unrestricted execution inside the container sandbox
RUN install -m 0755 /opt/docker-bin/codex /usr/local/bin/codex

# Install Claude Code CLI (native installer)
RUN set -eux; \
    printf '#!/bin/bash\ncurl -fsSL https://claude.ai/install.sh | bash\n' > /tmp/install-claude.sh; \
    chmod +x /tmp/install-claude.sh; \
    gosu agent env HOME=/home/agent USER=agent LOGNAME=agent /tmp/install-claude.sh; \
    rm -f /tmp/install-claude.sh; \
    mv /home/agent/.local/bin/claude /home/agent/.local/bin/claude-real; \
    install -m 0755 /opt/docker-bin/claude /home/agent/.local/bin/claude; \
    chown agent:agent /home/agent/.local/bin/claude /home/agent/.local/bin/claude-real; \
    ln -sf /home/agent/.local/bin/claude /usr/local/bin/claude; \
    gosu agent env HOME=/home/agent USER=agent LOGNAME=agent claude --version

# Entrypoint:
# - force correct HOME/USER for the final user
# - ensure mounted config dirs have the minimum required files on every start
RUN cat > /usr/local/bin/agent-entrypoint.sh <<'EOF' \
 && chmod 0755 /usr/local/bin/agent-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

AGENT_USER="agent"
AGENT_HOME="/home/${AGENT_USER}"

# Fix environment for the final user
export HOME="${AGENT_HOME}"
export USER="${AGENT_USER}"
export LOGNAME="${AGENT_USER}"

mkdir -p "${AGENT_HOME}/.codex" "${AGENT_HOME}/.claude"
chown "${AGENT_USER}:${AGENT_USER}" "${AGENT_HOME}/.codex" "${AGENT_HOME}/.claude"

# Ensure .mcp.json exists in /agent (host volume may not have it)
if [ ! -f /agent/.mcp.json ]; then
  printf '%s\n' '{"mcpServers":{"ghidra_headless_mcp":{"type":"stdio","command":"python3","args":["/opt/ghidra-headless-mcp/ghidra_headless_mcp.py"],"env":{"GHIDRA_INSTALL_DIR":"/usr/share/ghidra"}}}}' > /agent/.mcp.json
  chown "${AGENT_USER}:${AGENT_USER}" /agent/.mcp.json
fi

# Ensure Codex config.toml exists with MCP section
CODEX_CFG="${AGENT_HOME}/.codex/config.toml"
if [ ! -f "${CODEX_CFG}" ]; then
  cat > "${CODEX_CFG}" <<'TOML'
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
plan_mode_reasoning_effort = "xhigh"
suppress_unstable_features_warning = true

[features]
multi_agent = true
child_agents_md = true
TOML
  chown "${AGENT_USER}:${AGENT_USER}" "${CODEX_CFG}"
fi

# Always ensure MCP server section is present (mirrors .mcp.json approach)
if ! grep -q 'mcp_servers.ghidra_headless_mcp' "${CODEX_CFG}" 2>/dev/null; then
  cat >> "${CODEX_CFG}" <<'TOML'

[mcp_servers.ghidra_headless_mcp]
command = "python3"
args = ["/opt/ghidra-headless-mcp/ghidra_headless_mcp.py"]

[mcp_servers.ghidra_headless_mcp.env]
GHIDRA_INSTALL_DIR = "/usr/share/ghidra"
TOML
  chown "${AGENT_USER}:${AGENT_USER}" "${CODEX_CFG}"
fi

# Ensure Claude settings.json exists (volume mount shadows the baked-in copy)
CLAUDE_SETTINGS="${AGENT_HOME}/.claude/settings.json"
if [ ! -f "${CLAUDE_SETTINGS}" ]; then
  printf '%s\n' '{"trustedDirectories":["/agent","/home/agent"]}' > "${CLAUDE_SETTINGS}"
  chown "${AGENT_USER}:${AGENT_USER}" "${CLAUDE_SETTINGS}"
fi

# Ensure state.json exists and has the minimum keys so Claude Code does not
# re-show the onboarding / login screen on every container start.
CLAUDE_STATE="${AGENT_HOME}/.claude/state.json"
if [ ! -f "${CLAUDE_STATE}" ]; then
  printf '%s\n' '{}' > "${CLAUDE_STATE}"
fi
python3 -c "
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
try:
    d = json.loads(p.read_text())
except (json.JSONDecodeError, FileNotFoundError):
    d = {}
changed = False
for key, val in [('hasCompletedOnboarding', True), ('numStartups', d.get('numStartups', 0))]:
    if key not in d:
        d[key] = val
        changed = True
if changed:
    p.write_text(json.dumps(d))
" "${CLAUDE_STATE}"
ln -sf "${CLAUDE_STATE}" "${AGENT_HOME}/.claude.json"
chown "${AGENT_USER}:${AGENT_USER}" "${CLAUDE_STATE}" "${AGENT_HOME}/.claude.json"

exec gosu "${AGENT_USER}" "$@"
EOF

WORKDIR /agent
ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["/bin/bash"]
