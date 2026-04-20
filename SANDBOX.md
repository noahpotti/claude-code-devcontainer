# Claude Code Sandbox

Hardened devcontainer for running Claude Code with `bypassPermissions` safely enabled.

## What the container CAN do

- Read and modify everything under `/workspace` (your project files)
- Run any command as `vscode` user (passwordless sudo available)
- Install packages via apt, npm, pip/uv
- Access the internet (full outbound network by default)
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

Outbound network is **unrestricted by default**. Run these commands inside the container to restrict it — no config changes or rebuild needed.

### Restrict to Claude API + GitHub only

```bash
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -d api.anthropic.com -j ACCEPT
sudo iptables -A OUTPUT -d github.com -j ACCEPT
sudo iptables -A OUTPUT -d raw.githubusercontent.com -j ACCEPT
sudo iptables -A OUTPUT -j DROP
```

### Fully offline (no network)

```bash
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -j DROP
```

### Remove restrictions

```bash
sudo iptables -F OUTPUT
```

This flushes all OUTPUT rules, restoring full network access.

### Automatic restrictions on container start

To apply firewall rules automatically, create `.devcontainer/sandbox/firewall.sh` with the rules above and update `postCreateCommand` in `.devcontainer/sandbox/devcontainer.json`:

```json
"postCreateCommand": "uv run --no-project /opt/post_install.py && sudo /workspace/.devcontainer/sandbox/firewall.sh"
```

> **Note:** `.devcontainer/` is mounted read-only inside the container, so the firewall script cannot be tampered with from within. Rules are ephemeral — they reset when the container restarts unless applied via `postCreateCommand`.

## Auth

Set `CLAUDE_CODE_OAUTH_TOKEN` on your host to skip interactive login. The container picks it up automatically via `remoteEnv`. Run `claude setup-token` on your host to generate one.
