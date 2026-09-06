# Google Antigravity Hooks

> Part of [`hooks/`](../README.md) — see also [`src/hooks/`](../../src/hooks/README.md) for installation code

## Specifics

- **Programmatic PreToolUse Hook**: Native Rust binary command (`rtk hook antigravity`) intercepts `run_command` invocations.
- **Transparent Command Rewriting**: Automatically rewrites commands (e.g. `git status` -> `rtk git status`) before execution using Antigravity's `overwrite.CommandLine` mechanism.
- **Prompt Guidance**: `rules.md` provides complementary usage examples and meta-command instructions (`rtk gain`, `rtk discover`, `rtk proxy`).
- **Installation**:
  - Project scope: `rtk init --agent antigravity` (creates/patches `.agents/hooks.json` and writes `.agents/rules/antigravity-rtk-rules.md`).
  - Global scope: `rtk init -g --agent antigravity` (patches `~/.gemini/config/hooks.json`).

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
  "decision": "allow",
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
