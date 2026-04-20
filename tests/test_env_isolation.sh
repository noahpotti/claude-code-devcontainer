#!/bin/bash
# Verify that sensitive host environment variables are not leaked
# into the container beyond the explicitly forwarded ones.

# These should NOT be present (common host-only vars)
# Note: SSH_AUTH_SOCK is excluded — VS Code injects it for SSH agent
# forwarding, which is expected IDE behavior, not a host env leak.
for var in \
  "AWS_SECRET_ACCESS_KEY" \
  "HOME_HOST" \
  "DOCKER_HOST"; do
  if [[ -z "${!var:-}" ]]; then
    pass "$var is not set (not leaked from host)"
  else
    fail "$var is set: '${!var}' — host env leaked into container"
  fi
done

# CLAUDE_CONFIG_DIR should be set to the container path, not a host path
if [[ "${CLAUDE_CONFIG_DIR:-}" == "/home/vscode/.claude" ]]; then
  pass "CLAUDE_CONFIG_DIR points to container path"
elif [[ -z "${CLAUDE_CONFIG_DIR:-}" ]]; then
  fail "CLAUDE_CONFIG_DIR is not set"
else
  fail "CLAUDE_CONFIG_DIR points to unexpected path: $CLAUDE_CONFIG_DIR"
fi

# DEVCONTAINER should be set
if [[ "${DEVCONTAINER:-}" == "true" ]]; then
  pass "DEVCONTAINER=true is set"
else
  fail "DEVCONTAINER is not set to 'true'"
fi
