# Agentic Deobfuscation: An Attacker's Playbook

In our webinar "Agentic Deobfuscation: An Attacker's Playbook”, we explore how to turn tool-using agents into a practical capability for attacking obfuscated code. Rather than stopping at code explanations or isolated one-shot successes, we focus on building workflows that recover hidden logic, test analysis hypotheses, and turn the results into reusable deobfuscation tooling.

The webinar is built around two increasingly demanding examples. We start with a bounded deobfuscation task and follow it from initial inspection to a verified, reusable result. We formulate an analysis objective, have an agent build and refine custom tooling, and use concrete evidence to check the recovered logic. Rather than accepting a plausible explanation, we turn the results into a practical transformation that makes the code easier to analyze.

We then move to a more complex target, where interacting protection mechanisms and wider control- and data-flow dependencies demand a broader investigation. Here, the focus shifts to diagnosing analysis bottlenecks, questioning assumptions, and adapting the workflow when the current approach no longer answers the relevant question.

Along the way, we develop a practical playbook for agentic deobfuscation: defining useful objectives and verification criteria, organizing analysis tasks, preserving findings and scripts, and combining autonomous exploration with targeted methodological guidance. We look at when to let agents choose their own approach, when to intervene, and how to provide guidance that enables further independent progress. The goal is not to demonstrate a single perfect prompt, but to show how to turn reverse-engineering knowledge into an adaptable attack workflow—and carry successful techniques from one code location to the next.

The webinar will cover topics such as:

* structuring agentic deobfuscation around clear objectives and verifiable results
* balancing goal-driven autonomy with targeted analyst guidance
* having agents build, debug, and reuse custom analysis tooling
* recovering hidden logic and simplifying obfuscated code
* diagnosing bottlenecks and revisiting the scope, assumptions, or method of an analysis
* preserving analysis state, coordinating agents, and critically verifying findings

Designed for technical security professionals, reverse engineers, and malware analysts working with binaries or low-level software, this webinar focuses on practical workflows for taking obfuscated code apart. Attendees should be comfortable reading disassembly and decompilation, but no prior hands-on experience with agent-based analysis workflows is required.


## Materials and Related Resources

* Slides: [slides.pdf](./slides.pdf)
* Samples: [samples/](./samples/) contains the binaries used during the webinar
* Sample source: [Grand RE Challenge, round 1](https://grand-re-challenge.org/grand-re-challenge-round-1.zip)
* [mrphrazer/ghidra-headless-mcp](https://github.com/mrphrazer/ghidra-headless-mcp): agent integration for Ghidra
* [mrphrazer/binary-ninja-headless-mcp](https://github.com/mrphrazer/binary-ninja-headless-mcp): agent integration for Binary Ninja
* [Miasm](https://github.com/cea-sec/miasm): reverse-engineering framework with symbolic execution support
* [msynth](https://github.com/mrphrazer/msynth): deobfuscation framework for simplifying mixed Boolean-arithmetic expressions
* Talk: Deobfuscation in the Age of Agentic Reverse Engineering (REcon 2026) - [recording](https://www.youtube.com/watch?v=3-gJ6EUFoKM) and [slides](https://synthesis.to/presentations/recon26_agentic_deobfuscation.pdf)
* Workshop recording: [Semi-automatic Code Deobfuscation (r2con2020)](https://www.youtube.com/watch?v=_TsV0RXoIQE), a two-hour introduction to symbolic execution and SMT solving, applied with Miasm to remove opaque predicates from X-Tunnel malware. Useful background for the techniques covered in this webinar.
* Workshop code: [mrphrazer/r2con2020_deobfuscation](https://github.com/mrphrazer/r2con2020_deobfuscation) contains the example code, samples, and slides accompanying the recording.


## Docker Environment

This folder includes the Kali-based reverse-engineering environment used for the webinar demos. The image includes:

* Ghidra and agent integrations for Ghidra and Binary Ninja
* symbolic analysis and simplification tools, including msynth, Miasm, and Z3
* common reverse-engineering tools, emulators, Python, and compilers
* Codex, Claude Code, and Pi coding agents

Ghidra is ready to use by default. Binary Ninja can be added with your own installation archive and a license supporting headless use.


### Getting Started

From this webinar directory, build and start the environment with:

```bash
./run_docker.sh
```

The script builds the Docker image on first run and opens a shell inside the container. Subsequent runs reuse the image unless the build inputs change. The directory you launch it from is available as `/agent` inside the container, including the webinar samples in `/agent/samples`. Files you create there remain on your host after the container exits.

You can also start an agent directly:

```bash
./run_docker.sh codex
./run_docker.sh claude
./run_docker.sh pi
```

Sign in to your chosen agent on first use if needed. Authentication and settings are saved between runs in `~/.codex-docker`, `~/.claude-docker`, and `~/.pi-docker` on the host. Type `exit` to leave the container shell.


### Optional: Binary Ninja

To include Binary Ninja, place a Linux archive matching the container architecture at `binaryninja.zip` next to `run_docker.sh`, or supply its path:

```bash
BINARY_NINJA_ZIP=/path/to/binaryninja.zip ./run_docker.sh
```

The launcher reuses your license from `~/.binaryninja/license.dat` if available. Otherwise, place it at `~/.binaryninja-docker/license.dat`; an existing license there is preserved. Ghidra remains available when Binary Ninja is installed.


### Requirements

* Docker with `buildx` and Docker Compose v2 (`docker compose`)
* network access for the initial build and the chosen agent provider
* authentication for the chosen agent provider
* a matching Linux Binary Ninja archive and a license supporting headless use, only when using the Binary Ninja backend
