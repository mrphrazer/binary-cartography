# Reverse Engineering Playbook

## Tools

The Docker image provides:

- Disassembly and decompilation: Ghidra (`analyzeHeadless`, `ghidra-cli`), radare2 (`r2`), and optional Binary Ninja (`binja-cli`).
- Inspection and triage: `file`, `strings`, `readelf`, `objdump`, `nm`, elfutils, `patchelf`, Detect It Easy (`die`), `capa`, `floss`, `yara`, `ssdeep`, and `sha256sum`.
- Extraction and byte editing: `binwalk`, `unblob`, `upx`, `xxd`, `hexedit`, `bvi`, `hexwalk`, and archive utilities.
- Symbolic analysis and simplification: Z3 (`z3`) for constraint solving, Miasm (`miasm`) for intermediate representations and symbolic execution, and msynth (`msynth`) for expression simplification and synthesis (source and database in `/opt/msynth`).
- Scripting and emulation: Python with Capstone and Unicorn; QEMU user-mode emulators.
- Building custom tools: GCC/G++, Clang/LLVM, NASM, Make, CMake, and Ninja.

The MCP tool sources and documentation are in `/opt/ghidra-headless-mcp` and `/opt/binary-ninja-headless-mcp`. Use their CLI interfaces, `ghidra-cli` and `binja-cli`, for analysis. Consult local documentation and CLI help for usage.

Unless the user specifies otherwise, choose either or both backends according to availability and the task; neither is preferred. Check runtime availability before use: the presence of `binja-cli` does not imply that Binary Ninja, its Python API, or a usable headless license is installed. Binary Ninja is optional and, when installed by this image, lives in `/opt/binaryninja`.

## Analysis Workspace

Samples are in `samples/`. Give each analysis its own directory under `analysis/<analysis-name>/`.

That directory is the single source of truth for the analysis. Keep all analysis notes, custom scripts, commands, outputs, evidence, derived binaries, and tool projects/databases there. Configure tools to store persistent analysis state there where supported; document any unavoidable external state and how to restore it.

Maintain a concise `README.md` in each analysis directory as the entry point. It must record or link to:

- The objective, sample path and SHA-256, and relevant environment/tool setup.
- Current status, actions taken, commands and scripts used, and their results, including failed approaches.
- Findings with supporting evidence (such as addresses, functions, or saved outputs), clearly distinguishing verified facts from hypotheses.
- Open questions, blockers, and concrete next steps, with commands needed to resume or reproduce the work.

Update this record throughout the analysis, after meaningful findings or changes in direction, and before stopping or handing off. Keep detailed logs and artifacts in linked files so the entry point stays concise. Do not rely on chat history or agent memory as the only record.

When continuing an analysis, read its existing record and reuse its artifacts first. Another agent must be able to resume from the directory alone without repeating completed work.
