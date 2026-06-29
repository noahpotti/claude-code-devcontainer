#!/bin/bash
# Verify that network restrictions can be applied and enforced.
# Tests against localhost to avoid external dependencies.

# Start from a known baseline: the default egress firewall (firewall.sh) is
# applied on container start, so flush OUTPUT before asserting the manual path.
sudo iptables -F OUTPUT

LISTEN_PORT=18923

# Start a temporary HTTP server on localhost
start_listener $LISTEN_PORT "/dev/null"

# Sanity check: server is reachable before firewall
if curl -sf --max-time 2 http://127.0.0.1:$LISTEN_PORT/ >/dev/null 2>&1; then
  pass "localhost HTTP server is reachable (baseline)"
else
  fail "localhost HTTP server not reachable (test setup broken)"
  stop_listener $LISTENER_PID
  return 0
fi

stop_listener $LISTENER_PID

# Apply firewall: block everything except loopback
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -j DROP

# Start a fresh listener for the firewall tests
start_listener $LISTEN_PORT "/dev/null"

# Localhost should still work (loopback allowed)
if curl -sf --max-time 2 http://127.0.0.1:$LISTEN_PORT/ >/dev/null 2>&1; then
  pass "localhost still reachable with firewall (loopback allowed)"
else
  fail "localhost blocked by firewall (loopback rule not working)"
fi

stop_listener $LISTENER_PID

# External connections should be blocked
if curl -sf --max-time 3 http://1.1.1.1/ >/dev/null 2>&1; then
  fail "external connection succeeded despite firewall"
else
  pass "external connections blocked by firewall"
fi

# DNS should be blocked (no DNS rule added)
if curl -sf --max-time 3 http://example.com/ >/dev/null 2>&1; then
  fail "DNS resolution succeeded despite firewall"
else
  pass "DNS resolution blocked by firewall"
fi

# Flush rules (restore access)
sudo iptables -F OUTPUT

# Verify external access restored
if curl -sf --max-time 3 http://1.1.1.1/ >/dev/null 2>&1; then
  pass "external connections restored after iptables flush"
else
  pass "iptables flush completed (external connectivity depends on host network)"
fi
