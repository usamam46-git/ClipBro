# Bounded REA investigation — 2026-10-18

## Obtained evidence
- Active tool inventory exposes no REA MCP tools. Consequently no binary_session or analysis schema was callable.
- `npx -y rea-agents@6.7.0 doctor --client codex --json` exited 1 and reported Codex registration missing/config_drift, live server unknown. CLI 6.7.0 advertises 207 MCP tools; this is catalog metadata, not connected capabilities.
- Doctor found Hopper installed; Ghidra, IDA, JADX and Kuna are unconfigured. Node 24.19.0 is available.
- The independent REA checkout exists alongside ClipBro and was not modified.
- Ordinary directory inspection found Raycast installed, a possible future authorized launcher reference. No reference process was launched or analyzed.

## Unresolved questions
Reference appearance/dismissal, focus/keyboard navigation, destination workflow, search/selection and window positioning are all unresolved. No runtime interaction, decompilation or function/module findings were obtained. There are no REA Evidence IDs to cite.

## Chosen independent adaptations
Use AppKit NSPanel, nonactivating key-panel behavior, Escape/outside dismissal, a captured destination NSRunningApplication, pointer-display visibleFrame centering, and a Carbon global hotkey. These are design choices using Apple APIs, not reverse-engineered findings.

## Limitation and next step
REA setup/reconnection would be required for MCP investigation. As allowed by the task, proceed with native implementation rather than change Codex configuration or interrupt the session. A later investigation can inspect a selected installed reference after registration is repaired. No REA code/assets/dependencies are shipped.
