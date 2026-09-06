#!/usr/bin/env bash
# Test suite for hooks/antigravity/init.sh
# Verifies hook initialization, merging, idempotency, and dry-run behavior.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="${SCRIPT_DIR}/init.sh"

PASS=0
FAIL=0
TOTAL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert_eq() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  TOTAL=$((TOTAL + 1))

  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local needle="$2"
  local haystack="$3"
  TOTAL=$((TOTAL + 1))

  if echo "$haystack" | grep -Fq "$needle"; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    echo "       pattern: '$needle' not found in:"
    echo "$haystack"
    FAIL=$((FAIL + 1))
  fi
}

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

echo "============================================"
echo "  Testing Antigravity init.sh"
echo "============================================"

# Test 1: Help message
output=$("$INIT_SCRIPT" --help)
assert_contains "Help flag displays usage" "Usage: init.sh" "$output"

# Test 2: Creates new hooks.json from scratch
target_1="$TEST_TMPDIR/case1/hooks.json"
output=$("$INIT_SCRIPT" --file "$target_1")
assert_eq "Target file created" "true" "$([ -f "$target_1" ] && echo true || echo false)"
content_1=$(cat "$target_1")
assert_contains "Contains rtk-rewrite" "rtk-rewrite" "$content_1"
assert_contains "Contains rtk hook antigravity" "rtk hook antigravity" "$content_1"
assert_contains "Contains run_command matcher" "run_command" "$content_1"

# Test 3: Idempotency (running on existing initialized file)
output_re=$("$INIT_SCRIPT" --file "$target_1")
assert_contains "Detects already present hook" "already contains RTK hook" "$output_re"
content_1_re=$(cat "$target_1")
assert_eq "Content does not change on second run" "$content_1" "$content_1_re"

# Test 4: Preserves existing hooks in existing hooks.json
target_2="$TEST_TMPDIR/case2/hooks.json"
mkdir -p "$(dirname "$target_2")"
cat > "$target_2" <<'EOF'
{
  "my-linter": {
    "PostToolUse": [
      {
        "matcher": "run_command",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/lint.sh"
          }
        ]
      }
    ]
  }
}
EOF
output_merge=$("$INIT_SCRIPT" --file "$target_2")
content_2=$(cat "$target_2")
assert_contains "Preserves existing hook" "my-linter" "$content_2"
assert_contains "Adds rtk-rewrite" "rtk-rewrite" "$content_2"
assert_eq "Backup file created" "true" "$([ -f "${target_2}.bak" ] && echo true || echo false)"

# Test 5: Dry-run does not write to disk
target_3="$TEST_TMPDIR/case3/hooks.json"
output_dry=$("$INIT_SCRIPT" --dry-run --file "$target_3")
assert_contains "Dry run prints notice" "[dry-run] Nothing written." "$output_dry"
assert_eq "Dry run does not create file" "false" "$([ -f "$target_3" ] && echo true || echo false)"

# Test 6: Project flag defaults to .agents/hooks.json
(
  cd "$TEST_TMPDIR"
  "$INIT_SCRIPT" --project >/dev/null
  assert_eq "Project flag writes to .agents/hooks.json" "true" "$([ -f ".agents/hooks.json" ] && echo true || echo false)"
)

# Test 7: Fallback to python3 when jq is not in PATH
target_py="$TEST_TMPDIR/case_py/hooks.json"
mkdir -p "$(dirname "$target_py")"
cat > "$target_py" <<'EOF'
{
  "existing-tool": {
    "enabled": true
  }
}
EOF
# Run in an environment where jq is shadowed
output_py=$(PATH="/usr/bin:/bin" "$INIT_SCRIPT" --file "$target_py" 2>&1 || true)
# Verify python3 fallback works even if jq is removed from PATH:
(
  FAKE_BIN="$TEST_TMPDIR/fake_bin"
  mkdir -p "$FAKE_BIN"
  # Symlink all essential tools except jq
  for tool in bash sh rm mkdir cp mv cat mktemp dirname grep echo printf; do
    tool_path=$(command -v "$tool")
    ln -s "$tool_path" "$FAKE_BIN/$tool"
  done
  ln -s "$(command -v python3)" "$FAKE_BIN/python3"
  
  target_py_only="$TEST_TMPDIR/case_py_only/hooks.json"
  PATH="$FAKE_BIN" "$INIT_SCRIPT" --file "$target_py_only" >/dev/null
  content_py=$(cat "$target_py_only")
  assert_contains "Python fallback works without jq" "rtk-rewrite" "$content_py"
)

echo "============================================"
if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
  echo -e "  ${RED}$FAIL FAILED${NC} / $TOTAL total ($PASS passed)"
fi
echo "============================================"

exit $FAIL
