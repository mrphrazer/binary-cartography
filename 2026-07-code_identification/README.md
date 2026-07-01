# Pinpointing Interesting Code in Binaries: Heuristics, Statistics, and Agents

In our webinar "Pinpointing Interesting Code in Binaries: Heuristics, Statistics, and Agents", we explore how to identify core functionality in unknown binaries. Usually, an analyst would start by looking around the entry point and then follow code locations that reference interesting API functions, strings, or other obvious artifacts. However, in many real-world cases, this quickly reaches its limits. Modern binaries are often large and noisy, mixing relevant logic with initialization paths, library code, and framework-specific glue. As a consequence, they often leave the analyst with too many possible starting points and not enough guidance on where the actually relevant logic is located.

In such cases, heuristics and statistical signals can help identify structural patterns that point to relevant code constructs such as network protocol handlers, file parsers, and cryptographic routines. In malware analysis, other structural patterns may point to command-and-control dispatching logic, API hashing, or string decryption routines.

In this webinar, we walk through a selection of these heuristics and explain how they work. Across various use cases, we show how to apply them in practice and discuss where they provide useful signal. In the final part, we combine these heuristics with agentic reverse engineering. We will see that agents are not only useful for pruning false-positive detections, but that such heuristics are also a powerful instrument for pointing agents directly to core functionality, giving them a significant head start in binary analysis.

The webinar will cover topics such as:

* why strings, imports, and cross-references are often not enough to explore an unknown binary
* what code parts are usally "interesting"
* heuristics and statistical signals for identifying structural patterns
* control-flow-based detections such as state machines, complex functions, and loop shapes
* how to identify cryptographic code, RC4 implementations and string decryption routines in malware
* entropy and uncommon-instruction analysis for spotting decoders, packers, and embedded payloads
* applying detections across a range of binaries and interpreting their output
* combining heuristics with agents to reduce false positives
* using agents on top of heuristics to identify concrete core functionality

Designed for technical security professionals, reverse engineers, and malware analysts working with binaries or low-level software, this webinar focuses on how heuristic and statistical detections — combined with agents — can accelerate the identification of the code that matters. It is not a beginner's introduction to reverse engineering; attendees should be comfortable reading disassembly and decompilation, but no prior experience with agent-based workflows is required.


## Materials and Related Resources

SLides and samples:

* Slides: [slides.pdf](./slides.pdf)
* Samples: [samples/](./samples/) contains the live samples used during the webinar

Plugins used in the webinar:

* [`mrphrazer/obfuscation_detection`](https://github.com/mrphrazer/obfuscation_detection) — the original Binary Ninja plugin that automatically detects obfuscated code and other interesting code constructs (state machines, decryption loops, cyrptographic code, ...).
* [`mrphrazer/obfuscation_detection_ghidra`](https://github.com/mrphrazer/obfuscation_detection_ghidra) — the Ghidra Java port of the same detection suite; deployed in the Docker image.

Background reading about these heuristics:

* [Automated Detection of Control-flow Flattening](https://synthesis.to/2021/03/03/flattening_detection.html) — state-machine / dispatcher detection.
* [Automated Detection of Obfuscated Code](https://synthesis.to/2021/08/10/obfuscation_detection.html) — the broader heuristic catalogue behind the plugins.
* [Statistical Analysis to Detect Uncommon Code](https://synthesis.to/2023/01/26/uncommon_instruction_sequences.html) — the statistics pillar of the webinar.
* [Identification of API Functions in Binaries](https://synthesis.to/2023/08/02/api_functions.html) — statistical identification of API-like functions.


## Docker Environment

Kali-based reverse-engineering workspace with agent tooling preinstalled and a
Ghidra headless MCP backend wired up at container startup. The container also
ships a compiled build of `obfuscation_detection_ghidra`, so the agent can
invoke the detection scripts directly.

The project folder only requires three files:

* `Dockerfile` — image definition (all helper scripts are inlined)
* `compose.yaml` — service definition for `docker compose`
* `run_docker.sh` — bootstrapper that builds the image and launches the container

Any other file next to them (e.g. this README) is optional.

## Getting Started

```bash
./run_docker.sh
```

On first run, the script will:

1. create or reuse a Docker `buildx` builder named `training`
2. clone [`ghidra-headless-mcp`](https://github.com/mrphrazer/ghidra-headless-mcp) into `./mcp/`
3. build the image (Kali + tooling + Ghidra + the obfuscation-detection extension)
4. launch an interactive shell in the container

The current working directory is bind-mounted as `/agent`. Claude state is
persisted in `~/.claude-docker`, Codex state in `~/.codex-docker`.

You can also run a command directly:

```bash
./run_docker.sh codex
./run_docker.sh claude
./run_docker.sh run_detections --json /path/to/binary
```

## What's Preinstalled

* Ghidra (from the Kali `ghidra` package) with `analyzeHeadless` on `PATH`
* `pyghidra` and the Ghidra headless MCP server (wired up automatically)
* The `obfuscation_detection_ghidra` extension at `/opt/obfuscation_detection_ghidra`,
  built from source against the installed Ghidra
* `run_detections` and `detect_state_machine` wrappers on `PATH`
* Standard RE tooling: `radare2`, `gdb-multiarch`, `binutils`, `capa`,
  `floss`, `yara`, `ssdeep`, `detect-it-easy`, `binwalk`, `unblob`, `upx`, `hexwalk`
* Codex CLI and Claude Code CLI wrappers

## Running the Detections

Inside the container:

```bash
run_detections --json /path/to/binary | jq .
run_detections --json --only xor_decryption_loop /path/to/binary | jq .
detect_state_machine --json /path/to/binary | jq .
```

The wrappers call the upstream scripts at
`/opt/obfuscation_detection_ghidra/scripts/` and use the extension jar under
`/opt/obfuscation_detection_ghidra/build/libs/`.

## Requirements

* Docker with `buildx`
* Docker Compose v2 (`docker compose`)
* network access on the first build
