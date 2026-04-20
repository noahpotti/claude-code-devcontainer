# Sandbox Verification Tests

Tests that verify the devcontainer sandbox enforces its security properties. Run these **inside the container** after starting it.

## Usage

```bash
bash /workspace/tests/run_all.sh
```

## What's tested

| Test | Verifies |
|------|----------|
| `test_readonly_devcontainer.sh` | `.devcontainer/` is read-only, can't be remounted |
| `test_filesystem_isolation.sh` | Host paths (`/Users`, docker socket, etc.) are inaccessible |
| `test_env_isolation.sh` | Host env vars aren't leaked, container env is correct |
| `test_claude_settings_integrity.sh` | Claude settings exist, devcontainer.json can't be tampered with |
| `test_malicious_repo_hooks.sh` | Repo-shipped Claude hooks can't exfiltrate secrets (env + network isolation) |
| `test_network_restrictions.sh` | iptables rules block outbound, loopback survives, flush restores access |
| `test_build_exfiltration.sh` | Malicious Makefile exfiltrating env vars is blocked by firewall rules |

## Requirements

- Must be run inside the devcontainer (not on the host)
- Needs `sudo` for iptables tests (available by default in the container)
- Network tests use localhost listeners only — no external connections needed
