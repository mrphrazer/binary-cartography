# Agentic Reverse Engineering: How Agents Are Changing Binary Analysis

In our webinar "Agentic Reverse Engineering -- How Agents Are Changing Binary Analysis", we explore how agents are starting to reshape reverse engineering in practice. In a short time, they have moved beyond simple prompt-based help: they can use tools, inspect binaries, follow workflows, and automate work that previously had to be driven step by step by a human analyst. This creates a new way of approaching binary analysis---faster, more iterative, and much more workflow-driven.

The webinar introduces the core ideas behind this shift: what an agent is in a reverse-engineering setting, how agentic workflows differ from plain prompting, and what MCP, connected tools, and reusable skills enable in practice. After a brief orientation of the analysis environment, we move straight into live examples with Ghidra, showing how agents can analyze unknown binaries, recover structure, answer targeted questions, and support patching and cracking-style workflows.

Finally, we look at where agents already provide real value, where their limits still are, and how structured workflows can turn shallow exploration into much more useful analysis. The goal of this webinar is to show what agentic reverse engineering already makes possible today — and why it is changing the way we approach binaries.

The webinar will cover topics such as:

* what agentic reverse engineering is and why it matters
* the difference between plain prompting and tool-using agents
* MCP, connected tooling, and reusable skills
* a brief orientation of the RE environment
* using agents with Ghidra
* analyzing binaries, recovering structure, and answering targeted questions
* supporting patching and cracking-style workflows
* current strengths, limitations, and practical use cases

Designed for technical security professionals, reverse engineers, and analysts with some familiarity with binaries and low-level software, this webinar focuses on how agentic workflows can extend and accelerate real reverse-engineering tasks. It is not a beginner's introduction to reverse engineering, but attendees do not need prior experience with agents or AI-driven workflows.


## Docker Environment

This repository also includes a self-contained Docker environment used for the webinar demos. The container is built on Kali Linux and is meant to provide a ready-to-use reverse-engineering workstation with the tools used during the session.

The image includes:

* Kali Linux as the base system
* common RE and debugging tools such as `gdb`, `lldb`, `binutils`, `strace`, `ltrace`, `binwalk`, `qemu-user`, `xxd`, `hexedit`, `patchelf`, and related utilities
* Python and Node.js tooling
* Ghidra
* the [`ghidra-headless-mcp`](https://github.com/mrphrazer/ghidra-headless-mcp) server, prewired as an MCP server for the agent environment
* the Codex CLI and Claude Code CLI wrappers configured for use inside the container

The runtime setup is intentionally simple:

* the directory you launch `run_docker.sh` from is mounted into the container as `/agent`
* Codex state is persisted on the host in `~/.codex-docker`
* Claude state is persisted on the host in `~/.claude-docker`
* if `/agent/.mcp.json` or the user config files are missing, the entrypoint creates the minimum config needed on startup


### Getting Started

From this repository directory, start the container with:

```bash
./run_docker.sh
```

On first run, the script will:

1. create or reuse a Docker `buildx` builder named `training`
2. clone or update `ghidra-headless-mcp` into `~/.cache/ghidra-headless-mcp`
3. build the Docker image if it is not already present locally
4. launch an interactive shell in the container

Once the container starts, you will land in `/agent`, which maps to the directory you launched the script from on the host.

If you want to run a command directly instead of opening an interactive shell, pass it to the script; for example, to run `codex`:

```bash
./run_docker.sh codex
```

To run Claude Code:

```bash
./run_docker.sh claude
```


### Requirements

To run the environment, you need:

* Docker with `buildx`
* Docker Compose v2 (`docker compose`)
* network access on the first build, because the image installs packages and fetches `ghidra-headless-mcp`
