# Claude Code Sandbox

Hardened devcontainer for running Claude Code with `bypassPermissions` safely enabled.

## What the container CAN do

- Read and modify everything under `/workspace` (your project files)
- Run any command as `vscode` user (passwordless sudo available)
- Install packages via apt, npm, pip/uv
- Reach an allowlisted set of hosts — Claude API, GitHub, npm, DNS (egress firewall on by default; see [Network access](#network-access))
- Use git with your host identity (`~/.gitconfig` mounted read-only)
- Authenticate to GitHub via `gh` CLI (persisted across restarts)

## What the container CANNOT do

- Access host files outside `/workspace` and `~/.gitconfig`
- Modify the devcontainer config (`.devcontainer/` is mounted read-only)
- Access the Docker socket (no container-in-container)

## What persists and what doesn't

`/workspace` is a **bind mount** of your host project folder. Changes to files here are written directly to your host filesystem and persist after the container is stopped or destroyed.

These **Docker volumes** survive container restarts and rebuilds (but are destroyed by `devc destroy`):

| Volume | Path | Contents |
|--------|------|----------|
| Command history | `/commandhistory` | zsh/bash history |
| Claude config | `~/.claude` | Auth, settings, session logs |
| GitHub CLI | `~/.config/gh` | `gh auth` tokens |

Everything else (installed packages, files outside `/workspace` and the volumes above) is **ephemeral** — lost when the container is removed or rebuilt.

## Network access

Outbound traffic is restricted to an **egress allowlist by default**. On every container start, `postStartCommand` runs `.devcontainer/sandbox/firewall.sh`, which drops everything except loopback, DNS, and a short list of hosts. The script ships on the read-only `.devcontainer/` mount, so it cannot be altered from inside the container.

### Allowed by default

| Destination | Why |
|-------------|-----|
| loopback (`lo`) | local services |
| DNS (udp/tcp 53) | name resolution |
| `api.anthropic.com` | Claude API |
| `claude.ai` | `claude update` (install redirect) |
| `storage.googleapis.com` | `claude update` (binary download) — shared host |
| `github.com` | git over HTTPS |
| `raw.githubusercontent.com` | plugin marketplaces / raw files |
| `registry.npmjs.org` | npm |

Everything else is dropped.

> **Exfil note:** `storage.googleapis.com`, `raw.githubusercontent.com`, and `github.com` are shared, multi-tenant hosts. The allowlist limits *which hosts* are reachable, not *who owns the data* on them — anyone can create a bucket, gist, or repo. Treat the allowlist as egress-surface reduction, not exfil prevention. Drop `claude.ai` + `storage.googleapis.com` for a tighter list (and update Claude manually with the firewall off).

### Customize the allowlist

Edit the `ALLOW_HOSTS` array in `.devcontainer/sandbox/firewall.sh` (add e.g. `pypi.org` or a client's hosts), then re-apply without a rebuild:

```bash
sudo /workspace/.devcontainer/sandbox/firewall.sh
```

### Disable

```bash
sudo iptables -F OUTPUT          # this session only — restores full network until next start
```

Permanently — set the env var on your **host** (it forwards into the container via `remoteEnv`), then start/rebuild:

```bash
export SANDBOX_FIREWALL=0
devc up
```

### Fully offline (no network)

```bash
sudo iptables -F OUTPUT
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -j DROP
```

> **Notes:** Rules are ephemeral — they reset on container restart and are re-applied by `postStartCommand`. Allowlist hosts are matched by the IP(s) resolved when the rule is inserted, so a host whose IPs rotate mid-session may need a re-run. Because `vscode` has passwordless sudo, the firewall is a guardrail against accidental egress, not a hard boundary against a fully adversarial agent.

## Auth

Set `CLAUDE_CODE_OAUTH_TOKEN` on your host to skip interactive login. The container picks it up automatically via `remoteEnv`. Run `claude setup-token` on your host to generate one.
