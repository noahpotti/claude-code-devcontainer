#!/bin/bash
# Sandbox verification tests
# Run inside the devcontainer: bash /workspace/tests/run_all.sh
set -uo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib.sh"
trap '_cleanup_pids' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Sandbox Verification Tests ==="
echo ""

for test_script in "$SCRIPT_DIR"/test_*.sh; do
  echo "--- $(basename "$test_script") ---"
  source "$test_script"
  _cleanup_pids
  echo ""
done

echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
