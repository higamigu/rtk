# Google Antigravity Hooks

> Part of [`hooks/`](../README.md) — see also [`src/hooks/`](../../src/hooks/README.md) for installation code

## Specifics

- **Programmatic PreToolUse Hook**: Native Rust binary command (`rtk hook antigravity`) intercepts `run_command` invocations.
- **Transparent Command Rewriting**: Automatically rewrites commands (e.g. `git status` -> `rtk git status`) before execution using Antigravity's `overwrite.CommandLine` mechanism.
- **Installation**:
  - Project scope: `rtk init --agent antigravity` (creates/patches `.agents/hooks.json`).
  - Global scope: `rtk init -g --agent antigravity` (patches `~/.gemini/config/hooks.json`).
  - Standalone script: `./hooks/antigravity/init.sh` (initializes/patches `~/.gemini/config/hooks.json`, with `--project` or `--file` options).

## JSON Protocol

### Input (`stdin`)

```json
{
  "toolCall": {
    "name": "run_command",
    "args": {
      "CommandLine": "git status"
    }
  },
  "stepIdx": 1,
  "conversationId": "..."
}
```

### Output (`stdout`, when rewritten)

```json
{
  "decision": "ask",
  "reason": "RTK auto-rewrite",
  "overwrite": {
    "CommandLine": "rtk git status"
  }
}
```

### Output (`stdout`, passthrough / no rewrite)

```json
{
  "decision": "allow"
}
```
