# Claude Code Sandbox

A devcontainer that runs Claude Code with `bypassPermissions` safely enabled, so you can let it modify code freely without risking your host. Built at [Trail of Bits](https://www.trailofbits.com/) for security audit workflows — useful any time you'd rather Claude not touch your host filesystem.

> **Heads up:** outbound network access is **unrestricted by default**. The container provides filesystem isolation, not network isolation. See [Network isolation](#network-isolation) below to lock it down with iptables.

## Install

You need a Docker runtime — [Docker Desktop](https://docker.com/products/docker-desktop), [OrbStack](https://orbstack.dev/), or [Colima](https://github.com/abiosoft/colima) — running. Then:

```bash
npm install -g @devcontainers/cli
git clone https://github.com/trailofbits/claude-code-devcontainer ~/.claude-devcontainer
~/.claude-devcontainer/install.sh self-install
```

This installs the `devc` command to `~/.local/bin`. Make sure that's on your `PATH`.

> **Tip:** If you'd rather sandbox folders entirely from VS Code's GUI (open any folder → `Ctrl+Shift+D` → `Cmd+Shift+P` → Reopen in Container), see [GUI-only workflow](#gui-only-workflow-no-terminal) below for a one-time keybinding setup.

## Use it

### From VS Code (recommended)

Install the Dev Containers extension (`ms-vscode-remote.remote-containers` for VS Code, `anysphere.remote-containers` for Cursor), then in the directory you want to work in:

```bash
devc open .
```

VS Code opens the folder and prompts **"Reopen in Container"**. Click it. After ~1 minute on first build (Docker image), Claude Code is ready inside an isolated container with full access to that folder and nothing else on your host.

If the project already has its own devcontainer config, VS Code shows a picker — choose **Claude Code Sandbox**.

### From terminal

```bash
devc .          # Install template + start container
devc shell      # Drop into zsh inside the container
claude          # Start Claude Code
```

## Skip the login prompt

By default, Claude Code shows the interactive login wizard every time a new container is created. To skip it:

```bash
claude setup-token                                  # on host, one-time
echo 'export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat...' >> ~/.zshrc
```

Restart your shell (and VS Code, if it was open). The token forwards into every container automatically. This works around [anthropics/claude-code#8938](https://github.com/anthropics/claude-code/issues/8938).

## Threat model & sandboxing

The threat this project addresses: **Claude Code running arbitrary commands on your host machine.** With `bypassPermissions` enabled, Claude can `rm -rf` outside your project, modify your shell config, or abuse stored credentials. The devcontainer confines all of that to a disposable container where the blast radius is `/workspace`.

The container ships with common dev tooling so you can do all your work inside it — not just Claude. Intended workflow: clone a repo, start the devcontainer, work entirely within it. Add tools to the Dockerfile for reuse, or install ad-hoc with `devc exec`.

**Sandboxed:**
- **Filesystem** — container sees `/workspace` and a read-only `~/.gitconfig`. Host files are inaccessible.
- **Config integrity** — `.devcontainer/`, `.git/config`, and `.git/hooks` are mounted read-only inside the container, blocking config-injection and git-hook escape vectors.
- **Persistent state** — Claude auth, shell history, and `gh` login persist via Docker volumes. Destroyed by `devc destroy`.

**Not sandboxed by default:**
- **Network** — full outbound access (see [Network isolation](#network-isolation))
- **SSH agent** — the host's `SSH_AUTH_SOCK` is forwarded so the container can `git push` as you. Private key material stays on the host.
- **Docker socket** — not mounted

See [`SANDBOX.md`](SANDBOX.md) for the full reference and copy-paste firewall rules.

## Commands

| Command | What it does |
|---------|--------------|
| `devc open [dir]` | Install template + open in VS Code (prompts reopen in container) |
| `devc .` | Install template + start container (terminal flow) |
| `devc up` | Start the container |
| `devc shell` | Open zsh in the container |
| `devc exec CMD` | Run a command inside the container |
| `devc rebuild` | Rebuild container (preserves persistent volumes) |
| `devc down` | Stop the container |
| `devc destroy [-f]` | Remove container, volumes, and image for current project |
| `devc upgrade` | Update Claude Code inside the container |
| `devc mount SRC DST [--readonly]` | Bind-mount a host path into the container |
| `devc sync [NAME]` | Copy session logs from devcontainers to host (for `/insights`) |
| `devc template DIR [-y]` | Copy devcontainer files to a directory |
| `devc update` | Pull latest version of devc |
| `devc self-install` | Install devc to `~/.local/bin` |

> **Note:** Always use `devc destroy` to clean up — `docker rm` leaves orphaned volumes and images that `devc destroy` won't be able to find later.

## Advanced

### GUI-only workflow (no terminal)

If you want to install the sandbox config into a folder entirely from VS Code's GUI, add a user task and keybinding once:

```bash
# VS Code user tasks
cat <<'EOF' > "$HOME/Library/Application Support/Code/User/tasks.json"
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Sandbox: Install Config",
      "type": "shell",
      "command": "devc template . -y",
      "presentation": { "reveal": "silent", "close": true },
      "problemMatcher": []
    }
  ]
}
EOF

# VS Code keybinding (Ctrl+Shift+D)
cat <<'EOF' > "$HOME/Library/Application Support/Code/User/keybindings.json"
[
  {
    "key": "ctrl+shift+d",
    "command": "runCommands",
    "args": {
      "commands": [
        { "command": "workbench.action.tasks.runTask", "args": "Sandbox: Install Config" }
      ]
    }
  }
]
EOF
```

> **Note:** These overwrite existing files. Merge manually via `Cmd+Shift+P` → **Tasks: Open User Tasks** / **Preferences: Open Keyboard Shortcuts (JSON)** if you have existing config.

Then in any folder: `Ctrl+Shift+D` (installs config silently) → `Cmd+Shift+P` → **Dev Containers: Reopen in Container** → pick **Claude Code Sandbox**.

### Network isolation

Outbound network is unrestricted by default. To block it, run inside the container:

```bash
sudo iptables -A OUTPUT -o lo -j ACCEPT                                    # loopback
sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A OUTPUT -d api.anthropic.com -j ACCEPT                     # Claude API
sudo iptables -A OUTPUT -d github.com -j ACCEPT                            # git
sudo iptables -A OUTPUT -d registry.npmjs.org -j ACCEPT                    # npm (optional)
sudo iptables -A OUTPUT -j DROP                                            # block everything else
```

Undo with `sudo iptables -F OUTPUT`. To apply automatically on container start, see [`SANDBOX.md`](SANDBOX.md).

### File sharing

**VS Code:** drag files into the Explorer panel — they copy into `/workspace/` automatically.

**Terminal:** add a bind mount and recreate the container.

```bash
devc mount ~/drop /drop                    # read-write
devc mount ~/secrets /secrets --readonly   # read-only
```

A "drop folder" pattern is useful for passing files in without exposing your home directory. Custom mounts are preserved across `devc template` updates.

> **Security note:** Avoid mounting large host directories (e.g., `$HOME`). Mounted paths are writable from the container unless `--readonly` is set, which undermines the filesystem isolation.

### Multi-repo workspaces

For client engagements with multiple related repos, put the devcontainer config in a parent directory and clone repos inside:

```bash
mkdir -p ~/sandbox/client-name
cd ~/sandbox/client-name
devc .
devc shell

# Inside container:
git clone <repo-1>
git clone <repo-2>
```

All repos share the same container, volumes, and Claude session.

### Optimizing Colima for Apple Silicon

Colima's defaults (QEMU + sshfs) are slow. For better performance:

```bash
colima stop && colima delete
colima start --cpu 4 --memory 8 --disk 100 \
  --vm-type vz --vz-rosetta --mount-type virtiofs
```

Adjust CPU/memory based on your Mac. `vz` uses Apple's Virtualization.framework (faster than QEMU), `virtiofs` is 5-10x faster than sshfs for file I/O, `--vz-rosetta` enables x86 containers.

Verify with `colima status` — should show "macOS Virtualization.Framework" and "virtiofs".

### Session sync for `/insights`

Claude's `/insights` command reads from `~/.claude/projects/` on the host, so devcontainer sessions are invisible to it. Sync them with:

```bash
devc sync              # All devcontainers
devc sync crypto       # Filter by project name (substring match)
```

Sessions are auto-discovered via Docker labels. The sync is incremental and safe to re-run.

### Token-based auth on headless servers

Same as the [Skip the login prompt](#skip-the-login-prompt) section above — the token mechanism works identically for headless servers. Set `CLAUDE_CODE_OAUTH_TOKEN` in the host shell environment, run `devc rebuild` if a container already exists.

### Container details

| Component | Details |
|-----------|---------|
| Base | Ubuntu 24.04, Node.js 22, Python 3.13 + uv, zsh |
| User | `vscode` (passwordless sudo), working dir `/workspace` |
| Tools | `rg`, `fd`, `tmux`, `fzf`, `delta`, `iptables`, `ipset` |
| Persistent volumes | `/commandhistory`, `~/.claude`, `~/.config/gh` |
| Host mounts | `~/.gitconfig`, `.devcontainer/`, `.git/config`, `.git/hooks` (all read-only) |
| Auto-installed plugins | [anthropics](https://github.com/anthropics/claude-code-plugins) + [trailofbits](https://github.com/trailofbits/claude-code-plugins) skills |

### Troubleshooting

**"devcontainer CLI not found"** — `npm install -g @devcontainers/cli`

**Container won't start** — check Docker is running, try `devc rebuild`, check logs with `docker logs $(docker ps -lq)`

**GitHub CLI auth not persisting** — `sudo chown -R $(id -u):$(id -g) ~/.config/gh` inside the container

**Claude keeps asking to log in** — the `CLAUDE_CODE_OAUTH_TOKEN` env var isn't reaching the container. Make sure it's exported in your host shell *before* VS Code launches (and fully quit VS Code, not just reload the window). Verify with `echo $CLAUDE_CODE_OAUTH_TOKEN` inside the container.

**Python/uv usage** — Python is managed via uv: `uv run script.py`, `uv add package`, `uv run --with requests script.py` for ad-hoc deps.

### Building manually

```bash
devcontainer build --workspace-folder .
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . zsh
```

## Credits

Forked from [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer). All credit for the original sandbox design, `devc` CLI, and security model goes to [Trail of Bits](https://www.trailofbits.com/).

**Changes in this fork:**

- Template installs into `.devcontainer/sandbox/` so VS Code shows a config picker and the sandbox can coexist with project-native devcontainer configs
- `devc open [dir]` command — installs template + opens folder in VS Code in one step
- `-y` flag on `devc template` for non-interactive use
- VS Code GUI workflow: keybinding + task config so the sandbox can be installed into any open folder without touching a terminal
- `SANDBOX.md` — concise capability/limitation reference, copy-paste firewall rules
- Sandbox verification test suite (`tests/`) — verifies read-only mounts, env/filesystem isolation, malicious-repo Claude hook exfiltration, network restrictions, build-time exfiltration
