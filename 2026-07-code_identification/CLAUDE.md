# Agent Notes: Binary Analysis With Ghidra MCP and Obfuscation Detection

This workspace has Ghidra headless MCP plus a local Ghidra obfuscation detection extension. Use
these tools when a user asks to inspect, triage, reverse engineer, explain, or prioritize work on a
local binary.

## Available Tooling

- Ghidra MCP server: available through the `mcp__ghidra_headless_mcp` tools after discovery with
  `tool_search`.
- Ghidra runtime verified in this environment: Ghidra `12.1.1`, PyGhidra `3.1.0`.
- Obfuscation detection extension root:
  `/opt/obfuscation_detection_ghidra`
- Built plugin jar:
  `/opt/obfuscation_detection_ghidra/build/libs/ObfuscationDetectionGhidra.jar`
- Installable extension zip:
  `/opt/obfuscation_detection_ghidra/dist/ghidra_12.1.1_DEV_20260701_ObfuscationDetectionGhidra.zip`
- Main headless wrapper:
  `/opt/obfuscation_detection_ghidra/scripts/run_detections.sh`
- Compatibility alias:
  `/opt/obfuscation_detection_ghidra/scripts/detect_obfuscation.sh`
- State-machine-only wrapper:
  `/opt/obfuscation_detection_ghidra/scripts/detect_state_machine.sh`
- Ghidra headless script:
  `/opt/obfuscation_detection_ghidra/ghidra_scripts/RunDetections.java`

## When To Use It

Use the obfuscation detector early when:

- The binary may be packed, obfuscated, flattened, encrypted, or intentionally difficult to follow.
- You need a ranked list of suspicious functions before manual reversing.
- You want likely string/code decryptors, dispatcher loops, high-complexity functions, crypto loops,
  or abnormal CFG shapes.
- You need to decide which functions to decompile first in Ghidra MCP.
- The user asks for "interesting functions", "obfuscation", "triage", "decryptors", "state
  machines", "control flow flattening", "RC4", or "packed binary" analysis.

Do not treat detections as proof of obfuscation. The output is a triage signal. Optimized compiler
output, libc/coreutils-style utility code, parsers, and large switch statements can produce noisy
findings.

## Quick Headless Usage

Run all detections as JSON:

```bash
/opt/obfuscation_detection_ghidra/scripts/run_detections.sh --json /path/to/binary
```

Run one detection:

```bash
/opt/obfuscation_detection_ghidra/scripts/run_detections.sh --json --only xor_decryption_loop /path/to/binary
```

Run the legacy state-machine-focused wrapper:

```bash
/opt/obfuscation_detection_ghidra/scripts/detect_state_machine.sh --json /path/to/binary
```

For large binaries, redirect JSON to a file and summarize it with `jq` instead of printing all
findings into the conversation.

## Detection IDs

These IDs are accepted by `--only`. The most useful triage signals are listed first:

- `state_machine`: high state-machine score. In general software, state machines and complex graph
  structure often indicate network protocol handlers, file format parsers, or dispatcher logic. In
  malware, this is a high-interest lead and often points to command-and-control communication,
  protocol handling, staged execution, or control-flow flattening.
- `complex_function`: high cyclomatic complexity. Treat this similarly to `state_machine`: it can
  identify protocol parsing, file parsing, large dispatchers, opaque control flow, or C2 handling.
  In malware, high-complexity functions are high-interest leads and should be inspected early.
- `large_basic_block`: high average instructions per block. In general software, large blocks often
  indicate data structure initialization. They can also indicate symmetric crypto, especially
  unrolled loops or table-heavy code.
- `most_called_function`: many callers. In general software, this often identifies API-like helper
  functions, embedded firmware service routines, or statically linked library code. In malware, this
  often identifies string decryption routines, API hashing helpers, or central unpacking helpers.
- `xor_decryption_loop`: loop with XOR-constant evidence. This is especially interesting for
  malware. It can indicate unpacking code, string decryption, code decryption, or simple
  crypto-like transforms.
- `rc4_ksa`: RC4 key-scheduling candidate. Mostly interesting for malware and protocol/crypto
  analysis.
- `rc4_prga`: RC4 pseudo-random generation candidate. Mostly interesting for malware and
  protocol/crypto analysis.
- `section_entropy`: section entropy report; JSON-only. Useful for finding packed, encrypted,
  compressed, or asset-heavy regions.
- `loop_frequency`, `irreducible_loop`, and `duplicate_subgraph`: still useful supporting signals,
  especially when they overlap with the higher-priority detections above.
- `entry_function`, `leaf_function`, and `recursive_function`: utility signals. Use them for
  context, callback discovery, and indirect-entry discovery, but do not prioritize them over the
  higher-signal heuristics above unless the binary shape suggests they matter.

## Recommended Workflow

1. Identify the binary format first:

   ```bash
   file /path/to/binary
   readelf -h /path/to/binary 2>/dev/null | rg 'Class|Type|Machine|Entry point' || true
   ```

2. Run obfuscation triage:

   ```bash
   /opt/obfuscation_detection_ghidra/scripts/run_detections.sh --json /path/to/binary > /tmp/obf.json
   ```

3. Summarize counts and top findings. For scored heuristics such as `state_machine`,
   `complex_function`, `large_basic_block`, `most_called_function`, and loop/subgraph heuristics,
   sort by the highest numeric score and inspect in descending order. For `xor_decryption_loop`,
   `rc4_ksa`, and `rc4_prga`, there is no meaningful score order; inspect each concrete finding.

   ```bash
   jq -r '.detections[] | [.id, (.findings | length)] | @tsv' /tmp/obf.json
   jq '.detections[] | select(.findings|length>0) | {id, name, top: .findings[:5]}' /tmp/obf.json
   ```

4. Open the binary with Ghidra MCP for deeper analysis:

   - Use `program_open` with `read_only: true` and `update_analysis: true`.
   - Use `program_report`, `program_summary`, `external_imports_list`, `symbol_list`, and
     `external_entrypoint_list` for orientation.
   - Use `function_report` or `decomp_function` on detector-reported addresses.
   - Use `function_callees`, `function_callers`, `reference_to`, and `reference_from` to place a
     suspicious function in context.
   - Use `memory_read` and `listing_data_at` to resolve pointer tables and dispatch tables.
   - Always close sessions with `program_close` when finished.

5. Prioritize manual reversing around:

   - Highest-scoring `state_machine` and `complex_function` findings, especially in malware.
   - Highest-scoring `large_basic_block` findings, especially table-heavy or unrolled code.
   - Highest-scoring `most_called_function` findings that are not obvious libc/import thunks.
   - `xor_decryption_loop`, `rc4_ksa`, and `rc4_prga` findings, especially in malware.
   - Supporting overlap from `loop_frequency`, `irreducible_loop`, `duplicate_subgraph`, and
     `section_entropy`.

## What The Output Can Teach You

The detector can help answer:

- Which functions are likely worth decompiling first?
- Which functions look like protocol handlers, file parsers, dispatchers, or C2 communication code?
- Which functions have unusually complex control-flow graphs and should be inspected first?
- Which high-interest malware leads may implement C2, protocol parsing, staged execution, or
  flattened control flow?
- Which large blocks may be data initialization, symmetric crypto, or unrolled-loop code?
- Which frequently called functions may be API-like helpers, statically linked library routines,
  malware string decryptors, API hashing helpers, or unpacking helpers?
- Which loops look like XOR string/code decryptors or unpacking logic?
- Whether RC4-like KSA or PRGA routines are present.
- Whether high-entropy sections may hold packed, encrypted, compressed, or asset-heavy data.

## Interpreting Results

- Cross-correlate findings. A function flagged by only one broad heuristic may be benign. A function
  flagged by `state_machine` and `complex_function` deserves closer review.
- Sort scored heuristics by their highest score and inspect descending. This applies especially to
  `state_machine`, `complex_function`, `large_basic_block`, and `most_called_function`. It also
  applies to supporting graph metrics such as `loop_frequency`, `irreducible_loop`, and
  `duplicate_subgraph`.
- Do not sort `xor_decryption_loop`, `rc4_ksa`, or `rc4_prga` by score. Treat each finding as a
  concrete lead and inspect the referenced function/instructions.
- Section entropy is not enough by itself. Compressed debug data, normal `.text`, or embedded assets
  can score high.
- `most_called_function` often finds real utility/library code. Check imports, names, and call
  behavior before labeling it as a decryptor. In malware, prioritize unresolved central helpers,
  string-reference-heavy helpers, and functions involved in API resolution.
- Address strings are Ghidra addresses, not necessarily file offsets. Use `address_space` and
  `address_offset` fields when correlating with MCP, and account for PIE image bases.
- On stripped binaries, use references, call graph shape, strings, and imported APIs to name
  functions before drawing conclusions.

## Direct Ghidra Headless Form

The wrapper scripts are preferred because they set `ghidra.external.modules` and extract JSON
cleanly. If direct headless execution is needed:

```bash
analyzeHeadless /tmp/od-project ObfuscationDetection \
  -import /path/to/binary \
  -scriptPath /opt/obfuscation_detection_ghidra/ghidra_scripts \
  -postScript RunDetections.java --json --json-markers \
  -deleteProject
```

## MCP Notes

- Use `tool_search` to expose the needed Ghidra MCP tools for the current turn.
- `program_open` can import a raw binary path directly and returns a `session_id`.
- `ghidra_script` can run a Ghidra script against an already-open MCP session if script-level
  integration is needed.
- Use read-only sessions for analysis unless the user explicitly asks to patch or annotate.
- If an ELF entry point is missing from `program_summary`, cross-check with `readelf -h` and map the
  ELF entry through Ghidra's image base.
- For startup analysis, inspect the entry function and resolve the first argument passed to
  `__libc_start_main`; on ELF binaries this often identifies `main`.

## Known Good Smoke Test

This command was verified in this environment:

```bash
/opt/obfuscation_detection_ghidra/scripts/run_detections.sh --json /bin/true
```

It returns JSON containing detection groups such as `state_machine`, `complex_function`,
`large_basic_block`, `most_called_function`, `section_entropy`, `rc4_ksa`, and `rc4_prga`.
