# RTK

Shell commands are automatically rewritten through RTK via the PreToolUse hook
(`rtk hook antigravity`). You do not need to manually prefix commands with `rtk`.

Command output is condensed to save tokens. Treat it as the complete result.
Batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output.

## Meta-commands

- `rtk gain` / `rtk gain --history` — token savings, overall and per command.
- `rtk proxy <cmd>` — run a command unfiltered (bypasses RTK condensing), still tracked.
- `RTK_DISABLED=1 <cmd>` — skip RTK for one command entirely.
- `rtk discover` — find past commands RTK could have condensed further.
