#!/usr/bin/env bash
# Default egress allowlist for the Claude Code sandbox.
#
# Applied automatically on every container start via `postStartCommand` in
# devcontainer.json. Everything not on the allowlist below is dropped.
#
# This file ships inside the read-only `.devcontainer/` mount, so it cannot be
# rewritten from within the container (even with sudo). Note that a process with
# sudo can still flush the live rules at runtime (`sudo iptables -F OUTPUT`) —
# this is a guardrail against accidental/unwanted egress, not a hard boundary
# against a fully adversarial agent.
#
# Disable for one session:   sudo iptables -F OUTPUT
# Disable permanently:       export SANDBOX_FIREWALL=0 on the host, then `devc up`
# Customize:                 add hosts to ALLOW_HOSTS and re-run, or extend in
#                            your own copy under .devcontainer/sandbox/
#
# Not using `set -e`: a host that fails to resolve must NOT skip the final DROP
# (fail closed, not open).
set -uo pipefail

# Allowed destinations. Resolved to IP(s) when each rule is inserted, so a host
# whose IPs rotate mid-session may need a re-run. Add what your workflow needs.
#
# WARNING: several of these are shared, multi-tenant hosts (storage.googleapis.com,
# raw.githubusercontent.com, github.com). The allowlist restricts WHICH hosts can
# be reached, not WHO controls the data on them — anyone can create a GCS bucket, a
# gist, or a repo. A determined agent can still exfiltrate to an attacker-controlled
# bucket/repo on these hosts. This narrows the egress surface; it does not close it.
ALLOW_HOSTS=(
  api.anthropic.com          # Claude API
  claude.ai                  # claude update (install redirect)
  storage.googleapis.com     # claude update (binary download) — shared host, see WARNING
  github.com                 # git over HTTPS
  raw.githubusercontent.com  # plugin marketplaces / raw files
  registry.npmjs.org         # npm
)

# Reset the OUTPUT chain so re-runs don't stack duplicate rules.
iptables -F OUTPUT

iptables -A OUTPUT -o lo -j ACCEPT                                  # loopback
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT   # replies to allowed conns
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT                      # DNS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT                      # DNS (TCP fallback)

for host in "${ALLOW_HOSTS[@]}"; do
  iptables -A OUTPUT -d "$host" -j ACCEPT || echo "firewall: could not resolve $host (skipped)" >&2
done

iptables -A OUTPUT -j DROP                                          # default deny

echo "firewall: egress allowlist applied (${#ALLOW_HOSTS[@]} hosts + DNS; default DROP)" >&2
