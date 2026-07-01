# syntax=docker/dockerfile:1.7
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ARG CAPA_VERSION=9.3.1
ARG GRADLE_VERSION=8.10.2
ARG OBFUSCATION_DETECTION_REPO=https://github.com/mrphrazer/obfuscation_detection_ghidra.git
ARG OBFUSCATION_DETECTION_REF=main

# Base utils + privilege drop helper
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo gosu curl ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*

# Node.js repo + all packages, including Ghidra and a default JDK for the extension build.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    build-essential gcc g++ clang lldb lld llvm cmake pkg-config ninja-build htop \
    binutils binutils-multiarch elfutils gdb gdb-multiarch patchelf file \
    jq ssdeep detect-it-easy \
    nasm radare2 ascii bsdextrautils \
    hexedit bvi xxd ht hexwalk \
    strace ltrace lsof procps \
    python3 python3-pip python3-venv python3-dev python3-all-dev \
    git vim wget coreutils moreutils ripgrep \
    zip unzip xz-utils p7zip-full lz4 zstd \
    binwalk \
    yara upx-ucl qemu-user yq \
    bison flex libffi-dev libncurses-dev libsqlite3-dev mcpp sqlite3 zlib1g-dev \
    ghidra openjdk-21-jdk-headless \
 && rm -rf /var/lib/apt/lists/* \
 && command -v ghidra \
 && ln -sf /usr/share/ghidra/support/analyzeHeadless /usr/local/bin/analyzeHeadless \
 && test -x /usr/local/bin/analyzeHeadless \
 && for tool in java javac; do \
      alt="$(update-alternatives --list "$tool" | grep '/java-21-openjdk-' | head -n 1)"; \
      test -n "$alt"; \
      update-alternatives --set "$tool" "$alt"; \
    done \
 && java_21_home="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")" \
 && ln -sfn "$java_21_home" /opt/java-21 \
 && java -version 2>&1 | grep -q '"21' \
 && javac -version 2>&1 | grep -q '21' \
 && node -v && npm -v

# Pin JAVA_HOME to the Java 21 install for both Gradle and Ghidra headless.
ENV JAVA_HOME=/opt/java-21
ENV PATH=/opt/java-21/bin:$PATH

# Python tooling (includes pyghidra for the MCP backend)
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    pytest ruff flare-floss uv ipython ipdb \
    capstone ropper unblob pyghidra

ENV GHIDRA_INSTALL_DIR=/usr/share/ghidra \
    OBFUSCATION_DETECTION_DIR=/opt/obfuscation_detection_ghidra

# Install a modern Gradle (the Debian ghidra package does not ship one),
# then clone and build obfuscation_detection_ghidra against the apt-installed Ghidra.
# The wrapper scripts run_detections / detect_state_machine are placed on PATH.
RUN set -eux; \
    curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
        -o /tmp/gradle.zip; \
    unzip -q /tmp/gradle.zip -d /opt; \
    ln -sf "/opt/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle; \
    rm /tmp/gradle.zip; \
    test -f "${GHIDRA_INSTALL_DIR}/support/buildExtension.gradle"; \
    git clone "${OBFUSCATION_DETECTION_REPO}" "${OBFUSCATION_DETECTION_DIR}"; \
    git -C "${OBFUSCATION_DETECTION_DIR}" checkout "${OBFUSCATION_DETECTION_REF}"; \
    cd "${OBFUSCATION_DETECTION_DIR}"; \
    gradle -PGHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR}" --no-daemon buildExtension; \
    test -f "${OBFUSCATION_DETECTION_DIR}/build/libs/ObfuscationDetectionGhidra.jar"; \
    chmod +x "${OBFUSCATION_DETECTION_DIR}"/scripts/*.sh; \
    printf '#!/usr/bin/env bash\nexec %s/scripts/run_detections.sh "$@"\n' \
        "${OBFUSCATION_DETECTION_DIR}" > /usr/local/bin/run_detections; \
    printf '#!/usr/bin/env bash\nexec %s/scripts/detect_state_machine.sh "$@"\n' \
        "${OBFUSCATION_DETECTION_DIR}" > /usr/local/bin/detect_state_machine; \
    chmod 0755 /usr/local/bin/run_detections /usr/local/bin/detect_state_machine

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
 && printf '%s\n' "export PS1='\\w\\\\$ '" > /home/agent/.bashrc \
 && chown agent:agent /home/agent/.bashrc

# Install Codex CLI (npm) and inline the codex wrapper on PATH
RUN npm i -g @openai/codex

RUN cat > /usr/local/bin/codex <<'CODEX_EOF' \
 && chmod 0755 /usr/local/bin/codex
#!/usr/bin/env bash
set -euo pipefail

REAL_CODEX="/usr/bin/codex"

should_inject_defaults=1
first_non_option=""
expect_value=0

for arg in "$@"; do
  if (( expect_value )); then
    expect_value=0
    continue
  fi

  case "$arg" in
    --)
      break
      ;;
    -c|--config|-m|--model|-p|--profile|-s|--sandbox|-a|--ask-for-approval|-C|--cd|-o|--output-last-message|-i|--image|--color|--local-provider|--output-schema)
      expect_value=1
      continue
      ;;
    -*)
      continue
      ;;
    *)
      first_non_option="$arg"
      break
      ;;
  esac
done

case "$first_non_option" in
  login|logout|mcp|mcp-server|app-server|completion|sandbox|debug|apply|cloud|features|help)
    should_inject_defaults=0
    ;;
  *)
    should_inject_defaults=1
    ;;
esac

declare -a extra_args=()
has_permission_override=0
has_model_override=0
has_config_override=0
expect_config_value=0

for arg in "$@"; do
  if (( expect_config_value )); then
    has_config_override=1
    expect_config_value=0
    continue
  fi

  case "$arg" in
    --dangerously-bypass-approvals-and-sandbox|--full-auto|-s|--sandbox|--sandbox=*|-a|--ask-for-approval|--ask-for-approval=*)
      has_permission_override=1
      ;;
    -m|--model|--model=*)
      has_model_override=1
      ;;
    -c|--config)
      expect_config_value=1
      has_config_override=1
      ;;
    -c=*|--config=*)
      has_config_override=1
      ;;
  esac
done

if (( should_inject_defaults && ! has_permission_override )); then
  extra_args+=(--dangerously-bypass-approvals-and-sandbox)
fi

if (( should_inject_defaults && ! has_model_override && ! has_config_override )); then
  extra_args+=(--model gpt-5.5)
fi

if (( should_inject_defaults && ! has_config_override )); then
  extra_args+=(-c 'model_reasoning_effort="high"')
  extra_args+=(-c 'plan_mode_reasoning_effort="high"')
  extra_args+=(-c 'suppress_unstable_features_warning=true')
  extra_args+=(-c 'features.multi_agent=true')
  extra_args+=(-c 'features.child_agents_md=true')
fi

exec "$REAL_CODEX" "${extra_args[@]}" "$@"
CODEX_EOF

# Inline the per-start MCP configurator (Ghidra-only).
RUN cat > /usr/local/bin/configure-agent-mcp.sh <<'MCP_EOF' \
 && chmod 0755 /usr/local/bin/configure-agent-mcp.sh
#!/usr/bin/env bash
set -euo pipefail

AGENT_HOME="${HOME:-/home/agent}"
CLAUDE_DIR="${AGENT_HOME}/.claude"
CLAUDE_SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CODEX_CONFIG_DIR="${AGENT_HOME}/.codex"
CODEX_CONFIG_FILE="${CODEX_CONFIG_DIR}/config.toml"
CLAUDE_PROJECT_MCP="/agent/.mcp.json"

GHIDRA_ROOT="/agent/mcp/ghidra-headless-mcp"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-/usr/share/ghidra}"

mkdir -p "${CLAUDE_DIR}" "${CODEX_CONFIG_DIR}"

python3 - "${CLAUDE_SETTINGS_FILE}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {}

trusted = list(dict.fromkeys((data.get("trustedDirectories") or []) + ["/agent", "/home/agent"]))
data["trustedDirectories"] = trusted
path.write_text(json.dumps(data))
PY

if [ ! -f "${GHIDRA_ROOT}/ghidra_headless_mcp.py" ]; then
  echo "warning: ${GHIDRA_ROOT}/ghidra_headless_mcp.py missing; MCP servers left empty" >&2
  printf '%s\n' '{"mcpServers":{}}' > "${CLAUDE_PROJECT_MCP}"
  : > "${CODEX_CONFIG_FILE}"
  exit 0
fi

cat > "${CLAUDE_PROJECT_MCP}" <<EOF
{
  "mcpServers": {
    "ghidra_headless_mcp": {
      "type": "stdio",
      "command": "python3",
      "args": ["${GHIDRA_ROOT}/ghidra_headless_mcp.py"],
      "env": {"GHIDRA_INSTALL_DIR": "${GHIDRA_INSTALL_DIR}"}
    }
  }
}
EOF

cat > "${CODEX_CONFIG_FILE}" <<EOF
[mcp_servers.ghidra_headless_mcp]
command = "python3"
args = ["${GHIDRA_ROOT}/ghidra_headless_mcp.py"]

[mcp_servers.ghidra_headless_mcp.env]
GHIDRA_INSTALL_DIR = "${GHIDRA_INSTALL_DIR}"
EOF
MCP_EOF

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

REAL_CLAUDE="${HOME:-/home/agent}/.local/bin/claude-real"

should_inject_defaults=1
first_non_option=""
expect_value=0

for arg in "$@"; do
  if (( expect_value )); then
    expect_value=0
    continue
  fi

  case "$arg" in
    --)
      break
      ;;
    --add-dir|--agent|--agents|--allowedTools|--allowed-tools|--append-system-prompt|--betas|-d|--debug|--debug-file|--effort|--fallback-model|--file|--from-pr|--input-format|--json-schema|--max-budget-usd|--mcp-config|--model|--output-format|--permission-mode|--plugin-dir|-r|--resume|--session-id|--setting-sources|--settings|--system-prompt|--tools|-w|--worktree)
      expect_value=1
      continue
      ;;
    -*)
      continue
      ;;
    *)
      first_non_option="$arg"
      break
      ;;
  esac
done

case "$first_non_option" in
  "" )
    should_inject_defaults=1
    ;;
  agents|auth|doctor|install|mcp|plugin|setup-token|update|upgrade)
    should_inject_defaults=0
    ;;
  *)
    should_inject_defaults=1
    ;;
esac

declare -a extra_args=()
has_permission_override=0
has_model_override=0
has_effort_override=0

for arg in "$@"; do
  case "$arg" in
    --dangerously-skip-permissions|--allow-dangerously-skip-permissions|--permission-mode|--permission-mode=*)
      has_permission_override=1
      ;;
    --model|--model=*)
      has_model_override=1
      ;;
    --effort|--effort=*)
      has_effort_override=1
      ;;
  esac
done

if (( should_inject_defaults )); then
  if (( ! has_permission_override )); then
    extra_args+=(--dangerously-skip-permissions)
  fi
  if (( ! has_model_override )); then
    extra_args+=(--model opus)
  fi
  if (( ! has_effort_override )); then
    extra_args+=(--effort high)
  fi
fi

exec "$REAL_CLAUDE" "${extra_args[@]}" "$@"
CLAUDE_EOF

# Entrypoint: fix HOME/USER for the final user, run the MCP configurator every start,
# and symlink ~/.claude.json into the volume-backed state file.
RUN cat > /usr/local/bin/agent-entrypoint.sh <<'EOF' \
 && chmod 0755 /usr/local/bin/agent-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

AGENT_USER="agent"
AGENT_HOME="/home/${AGENT_USER}"

export HOME="${AGENT_HOME}"
export USER="${AGENT_USER}"
export LOGNAME="${AGENT_USER}"

gosu "${AGENT_USER}" /usr/local/bin/configure-agent-mcp.sh

CLAUDE_STATE="${AGENT_HOME}/.claude/state.json"
CLAUDE_JSON="${AGENT_HOME}/.claude.json"
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
ln -sf "${CLAUDE_STATE}" "${CLAUDE_JSON}"
chown "${AGENT_USER}:${AGENT_USER}" "${CLAUDE_STATE}" "${CLAUDE_JSON}"

exec gosu "${AGENT_USER}" "$@"
EOF

WORKDIR /agent
ENTRYPOINT ["/usr/local/bin/agent-entrypoint.sh"]
CMD ["/bin/bash"]
