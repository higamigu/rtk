#!/usr/bin/env bash
# Initialize RTK hook for Google Antigravity
# Adds the rtk-rewrite PreToolUse hook configuration to .gemini/config/hooks.json
#
# Usage:
#   ./hooks/antigravity/init.sh
#   ./hooks/antigravity/init.sh --dry-run
#   ./hooks/antigravity/init.sh --file /path/to/hooks.json
#   ./hooks/antigravity/init.sh --project

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

HOOK_NAME="rtk-rewrite"
HOOK_COMMAND="rtk hook antigravity"
DEFAULT_GLOBAL_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"
TARGET_FILE=""
DRY_RUN=false

show_help() {
  cat <<'EOF'
Usage: init.sh [OPTIONS] [HOOKS_FILE]

Initialize Google Antigravity lifecycle hooks for RTK.
Adds the rtk-rewrite PreToolUse hook to .gemini/config/hooks.json (global)
or a specified hooks.json file.

Arguments:
  HOOKS_FILE           Optional path to hooks.json target file

Options:
  -f, --file PATH      Path to hooks.json (default: ~/.gemini/config/hooks.json)
  -p, --project        Install to project-level .agents/hooks.json
  -n, --dry-run        Preview changes without modifying files
  -h, --help           Show this help message

Examples:
  ./init.sh
  ./init.sh --dry-run
  ./init.sh --file ~/.gemini/config/hooks.json
  ./init.sh --project
EOF
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -p|--project)
      TARGET_FILE=".agents/hooks.json"
      shift
      ;;
    -f|--file)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}[ERROR]${NC} --file requires a path argument" >&2
        exit 1
      fi
      TARGET_FILE="$2"
      shift 2
      ;;
    -*)
      echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
    *)
      if [[ -z "$TARGET_FILE" ]]; then
        TARGET_FILE="$1"
      else
        echo -e "${RED}[ERROR]${NC} Unexpected argument: $1" >&2
        show_help >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$TARGET_FILE" ]]; then
  TARGET_FILE="$DEFAULT_GLOBAL_DIR/hooks.json"
fi

# Expand ~ if present in target path
TARGET_FILE="${TARGET_FILE/#\~/$HOME}"

# Check for rtk binary
if ! command -v rtk >/dev/null 2>&1; then
  echo -e "${YELLOW}[WARN]${NC} rtk is not found in PATH."
  echo "       The hook requires rtk to be installed. Install with:"
  echo "       curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  echo ""
fi

# Determine JSON tool
JSON_TOOL=""
if command -v jq >/dev/null 2>&1; then
  JSON_TOOL="jq"
elif command -v python3 >/dev/null 2>&1; then
  JSON_TOOL="python3"
elif command -v node >/dev/null 2>&1; then
  JSON_TOOL="node"
else
  echo -e "${RED}[ERROR]${NC} Neither jq, python3, nor node is available." >&2
  echo "        Please install jq or python3 to parse and patch hooks.json." >&2
  exit 1
fi

HOOK_ENTRY_JSON='{
  "PreToolUse": [
    {
      "matcher": "run_command",
      "hooks": [
        {
          "type": "command",
          "command": "rtk hook antigravity",
          "timeout": 10
        }
      ]
    }
  ]
}'

is_hook_present() {
  local file="$1"
  if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    return 1
  fi

  if [[ "$JSON_TOOL" == "jq" ]]; then
    jq -e '
      (."rtk-rewrite" != null) or
      ([.[]? | .PreToolUse?[]? | .hooks?[]? | select(.command? | test("rtk hook antigravity"))] | length > 0)
    ' "$file" >/dev/null 2>&1
  elif [[ "$JSON_TOOL" == "python3" ]]; then
    python3 - "$file" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        content = f.read().strip()
        if not content:
            sys.exit(1)
        data = json.loads(content)
    if not isinstance(data, dict):
        sys.exit(1)
    if "rtk-rewrite" in data:
        sys.exit(0)
    for k, v in data.items():
        if isinstance(v, dict):
            for group in v.get("PreToolUse", []):
                if isinstance(group, dict):
                    for h in group.get("hooks", []):
                        if isinstance(h, dict) and "rtk hook antigravity" in h.get("command", ""):
                            sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
  else
    node - "$file" <<'JSEOF'
const fs = require('fs');
try {
  const content = fs.readFileSync(process.argv[2], 'utf8').trim();
  if (!content) process.exit(1);
  const data = JSON.parse(content);
  if (data['rtk-rewrite']) process.exit(0);
  for (const v of Object.values(data)) {
    if (v && Array.isArray(v.PreToolUse)) {
      for (const group of v.PreToolUse) {
        if (group && Array.isArray(group.hooks)) {
          for (const h of group.hooks) {
            if (h && typeof h.command === 'string' && h.command.includes('rtk hook antigravity')) {
              process.exit(0);
            }
          }
        }
      }
    }
  }
  process.exit(1);
} catch {
  process.exit(1);
}
JSEOF
  fi
}

generate_patched_json() {
  local file="$1"
  if [[ "$JSON_TOOL" == "jq" ]]; then
    if [[ -f "$file" ]] && [[ -s "$file" ]]; then
      jq --argjson hook "$HOOK_ENTRY_JSON" '.["rtk-rewrite"] = $hook' "$file"
    else
      jq -n --argjson hook "$HOOK_ENTRY_JSON" '{"rtk-rewrite": $hook}'
    fi
  elif [[ "$JSON_TOOL" == "python3" ]]; then
    python3 - "$file" <<'PYEOF'
import json, sys, os

file_path = sys.argv[1]
hook_entry = {
    "PreToolUse": [
        {
            "matcher": "run_command",
            "hooks": [
                {
                    "type": "command",
                    "command": "rtk hook antigravity",
                    "timeout": 10
                }
            ]
        }
    ]
}

data = {}
if os.path.isfile(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                data = json.loads(content)
                if not isinstance(data, dict):
                    data = {}
    except Exception:
        data = {}

data["rtk-rewrite"] = hook_entry
print(json.dumps(data, indent=2))
PYEOF
  else
    node - "$file" <<'JSEOF'
const fs = require('fs');
const filePath = process.argv[2];
const hookEntry = {
  PreToolUse: [
    {
      matcher: "run_command",
      hooks: [
        {
          type: "command",
          command: "rtk hook antigravity",
          timeout: 10
        }
      ]
    }
  ]
};
let data = {};
if (fs.existsSync(filePath)) {
  try {
    const content = fs.readFileSync(filePath, 'utf8').trim();
    if (content) {
      data = JSON.parse(content);
      if (typeof data !== 'object' || Array.isArray(data) || data === null) {
        data = {};
      }
    }
  } catch {}
}
data["rtk-rewrite"] = hookEntry;
console.log(JSON.stringify(data, null, 2));
JSEOF
  fi
}

# Check if hook already present
if is_hook_present "$TARGET_FILE"; then
  echo -e "${GREEN}[INFO]${NC} Antigravity hooks.json already contains RTK hook: $TARGET_FILE"
  exit 0
fi

PATCHED_JSON=$(generate_patched_json "$TARGET_FILE")

if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] would update: $TARGET_FILE"
  echo "[dry-run] content:"
  echo "$PATCHED_JSON"
  echo ""
  echo "[dry-run] Nothing written."
  exit 0
fi

# Ensure parent directory exists
TARGET_DIR=$(dirname "$TARGET_FILE")
if [[ ! -d "$TARGET_DIR" ]]; then
  mkdir -p "$TARGET_DIR"
  echo -e "${GREEN}[INFO]${NC} Created directory: $TARGET_DIR"
fi

# Backup existing file if present
if [[ -f "$TARGET_FILE" ]] && [[ -s "$TARGET_FILE" ]]; then
  cp "$TARGET_FILE" "${TARGET_FILE}.bak"
  echo -e "${GREEN}[INFO]${NC} Backed up existing file to ${TARGET_FILE}.bak"
fi

# Atomic write
TEMP_FILE=$(mktemp "${TARGET_DIR}/hooks.json.tmp.XXXXXX")
echo "$PATCHED_JSON" > "$TEMP_FILE"
mv "$TEMP_FILE" "$TARGET_FILE"

echo -e "${GREEN}[SUCCESS]${NC} RTK hook configured for Google Antigravity."
echo "  Target:     $TARGET_FILE"
echo "  Hook:       $HOOK_NAME ($HOOK_COMMAND)"
echo "  Event:      PreToolUse (matcher: run_command)"
echo ""
echo "Antigravity will now automatically rewrite shell commands through RTK."
