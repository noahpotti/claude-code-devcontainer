#!/bin/bash
# Verify the default egress allowlist (firewall.sh) ships and fails closed:
# loopback stays up, non-allowlisted external destinations are dropped.
# Uses localhost + a known-dropped external IP, so no real external dependency.

# Locate the firewall script: the read-only mounted instance, or — when this
# repo itself is the workspace — the template source at the root.
FW=""
for cand in /workspace/.devcontainer/sandbox/firewall.sh /workspace/firewall.sh; do
  [[ -f "$cand" ]] && FW="$cand" && break
done

if [[ -z "$FW" ]]; then
  fail "firewall.sh not found (default network policy missing)"
  return 0
fi
pass "firewall.sh present ($FW)"

# Apply the default policy from a clean slate.
sudo iptables -F OUTPUT
sudo bash "$FW" >/dev/null 2>&1

# Loopback must still work.
start_listener 18924 "/dev/null"
if curl -sf --max-time 2 http://127.0.0.1:18924/ >/dev/null 2>&1; then
  pass "loopback allowed under default firewall"
else
  fail "loopback blocked under default firewall"
fi
stop_listener "$LISTENER_PID"

# A non-allowlisted external host must be dropped (1.1.1.1 is not on the list).
if curl -sf --max-time 3 http://1.1.1.1/ >/dev/null 2>&1; then
  fail "non-allowlisted external connection allowed under default firewall"
else
  pass "non-allowlisted external connection dropped by default firewall"
fi

# Restore full access for subsequent tests.
sudo iptables -F OUTPUT
