#!/bin/bash
# Verify the container cannot access host filesystem paths.

# Common host paths that should not exist or be accessible
for host_path in \
  "/host" \
  "/Users" \
  "/home/host" \
  "/var/run/docker.sock"; do
  if [[ ! -e "$host_path" ]]; then
    pass "$host_path is not accessible"
  else
    fail "$host_path is accessible from inside the container"
  fi
done

# /workspace should exist and be writable (it's the bind-mounted project)
if [[ -d /workspace && -w /workspace ]]; then
  pass "/workspace is writable (expected — bind mount)"
else
  fail "/workspace is not writable (unexpected)"
fi

# Host .gitconfig should be read-only
if [[ -f /home/vscode/.gitconfig ]]; then
  if ! { echo "test" >> /home/vscode/.gitconfig; } 2>/dev/null; then
    pass "~/.gitconfig is read-only"
  else
    fail "~/.gitconfig is writable — host git config can be modified"
  fi
else
  pass "~/.gitconfig not present (no host gitconfig mounted)"
fi
