# Claude Code Setup — VS Code & Cursor, Any Platform

A batteries-included, cross-platform setup package that bootstraps a complete [Claude Code](https://docs.anthropic.com/en/docs/claude-code) development environment in minutes. Works with **VS Code**, **Cursor**, or CLI-only — on **macOS**, **Linux**, and **Windows (WSL2)**.

Fork this repo, edit `setup.conf`, and give your team a one-command onboarding experience.

---

## What This Does

Running `bash setup-all.sh` on a fresh machine will:

1. **Install developer tools** — nvm, Node.js LTS, pnpm, Bun (optional), GitHub CLI, Doppler CLI (optional), and Claude Code itself
2. **Install MCP servers** — configurable set of [Model Context Protocol](https://modelcontextprotocol.io/) servers (memory, sequential-thinking, GitHub, Context7, n8n) via pnpm
3. **Configure your shell** — idempotent marker-based blocks in `~/.bashrc` or `~/.zshrc` for nvm, pnpm, Bun, SSH agent, editor aliases, and an optional Doppler secrets wrapper for Claude
4. **Scan for projects** — discovers existing git repos under your configured projects root
5. **Generate `.mcp.json`** — resolves pnpm global paths so MCP servers work out of the box
6. **Generate an IDE workspace** — multi-root `.code-workspace` file with all discovered projects and platform-appropriate settings
7. **Set Claude Code defaults** — installs a rich status line (context usage, cost, git branch, rate limits) and enables Accept Edits mode
8. **Import Claude config** — optionally import `~/.claude/` from another machine (agents, commands, rules, skills) with merge-by-default so existing config isn't destroyed

Everything is **idempotent** — safe to re-run at any time.

---

## Supported Platforms

| Platform | Shell | Package Manager | IDE Detection |
|----------|-------|-----------------|---------------|
| **macOS** (Apple Silicon & Intel) | zsh | Homebrew | `/Applications/*.app` + CLI in PATH |
| **Linux** (Ubuntu/Debian) | bash | apt | `code` / `cursor` in PATH |
| **Windows via WSL2** | bash | apt | Windows-side `/mnt/c/Users/*/AppData/Local/Programs/` scan |

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/YOUR-ORG/YOUR-REPO.git ~/projects/claude-code-setup
cd ~/projects/claude-code-setup

# 2. Configure
cp setup.conf.example setup.conf
# Edit setup.conf — set your projects root, choose which tools and MCP servers to install

# 3. Run
bash setup-all.sh
```

If you skip step 2, `setup-all.sh` will prompt you interactively and create `setup.conf` for you. It also detects existing config from your shell RC (e.g., if you already have Doppler wrappers, it pre-populates the defaults).

### With a Claude config export from another machine

```bash
# On the source machine:
bash export-claude-config.sh

# Transfer the tarball, then on the new machine:
bash setup-all.sh /path/to/claude-config-YYYYMMDD-HHMMSS.tar.gz
```

---

## Configuration

All customization lives in a single file: **`setup.conf`** (copy from `setup.conf.example`).

```bash
# Where your projects live (setup scans this for existing repos)
PROJECTS_ROOT="$HOME/projects"

# Node.js major version
NODE_VERSION="22"

# Optional tools (true/false)
INSTALL_BUN="true"
INSTALL_DOPPLER="false"

# Secrets manager: "doppler" or "" (empty = env vars only)
SECRETS_MANAGER=""

# MCP servers to install (comma-separated short names)
MCP_SERVERS="memory,sequential-thinking,github,context7"
```

### Available MCP Servers

| Short Name | npm Package | Purpose |
|------------|-------------|---------|
| `memory` | `@modelcontextprotocol/server-memory` | Persistent memory across sessions |
| `sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | Enhanced chain-of-thought reasoning |
| `github` | `@modelcontextprotocol/server-github` | GitHub operations (PRs, issues, code search) |
| `context7` | `@upstash/context7-mcp` | Live documentation lookup for any library |
| `n8n-workflow-builder` | `@makafeli/n8n-workflow-builder` | n8n workflow CRUD operations |
| `n8n-mcp` | `n8n-mcp` | n8n node documentation + validation |

---

## What Gets Installed

| Category | Components |
|----------|------------|
| **Runtime** | nvm, Node.js LTS (configurable version), npm |
| **Package Managers** | pnpm (required), Bun (optional) |
| **CLI Tools** | GitHub CLI, Claude Code, Doppler CLI (optional) |
| **MCP Servers** | Configurable via `MCP_SERVERS` in setup.conf |
| **Shell Config** | nvm, pnpm, Bun, editor aliases, SSH agent, Claude wrapper |
| **IDE Workspace** | Multi-root `.code-workspace` for VS Code and Cursor |
| **Claude Defaults** | Status line script, Accept Edits mode |

---

## Scripts

| Script | Purpose |
|--------|---------|
| **`setup-all.sh`** | Master orchestrator — runs everything in order |
| `install-tools.sh` | Install nvm, Node, pnpm, Bun, gh, Doppler, Claude Code |
| `install-mcp-packages.sh` | Install MCP server packages via pnpm |
| `configure-shell.sh` | Add config blocks to `~/.bashrc` or `~/.zshrc` |
| `configure-directories.sh` | Create projects root and scan for existing repos |
| `generate-mcp-json.sh` | Generate `.mcp.json` with resolved pnpm paths |
| `generate-workspace.sh` | Generate IDE workspace with discovered projects |
| `install-defaults.sh` | Install Claude Code status line and defaults |
| `export-claude-config.sh` | Export `~/.claude/` to a transferable tarball |
| `import-claude-config.sh` | Import `~/.claude/` from tarball (merge or replace) |
| `patch-project-settings.sh` | Fix hardcoded paths in project settings after import |
| `verify.sh` | Post-setup verification checklist |

All scripts are **idempotent** — safe to re-run.

### Library Files (`lib/`)

Shared code sourced by all scripts:

| File | Purpose |
|------|---------|
| `lib/common.sh` | Colors, logging (`log`, `skip`, `warn`, `err`), `add_shell_block()`, `require_command()` |
| `lib/platform.sh` | `detect_platform()`, `detect_shell()`, `get_shell_rc()`, `get_package_manager()`, `detect_ides()`, `get_ide_cli()`, `get_ssh_agent_block()` |
| `lib/config.sh` | `load_config()`, `prompt_config()`, `validate_config()`, `get_mcp_packages()`, migration detection |

---

## Status Line

The included status line script (`templates/statusline.sh`) gives you a live two-line display in Claude Code:

```
▓▓▓▓▓▓░░░░░░░░░░░░░░ 30%  |  Opus 4.6  |  $1.24  |  3m42s  |  rate:12%
~/projects/my-app  |  feat/new-feature  |  +142/-38  |  agent:planner
```

- **Line 1:** Context window usage bar (green/yellow/red), model name, session cost, duration, rate limit percentage
- **Line 2:** Current directory, git branch, lines changed, active agent/worktree

---

## Transferring Config Between Machines

```bash
# Export from source machine
bash export-claude-config.sh
# Creates: export/claude-config-YYYYMMDD-HHMMSS.tar.gz

# Import on target machine — two modes:

# Merge (default): preserves existing files, adds only new ones
bash import-claude-config.sh /path/to/claude-config-*.tar.gz

# Replace: backs up existing ~/.claude/, then overwrites completely
bash import-claude-config.sh --replace /path/to/claude-config-*.tar.gz

# Fix any hardcoded paths from the source machine
bash patch-project-settings.sh
```

The export excludes machine-specific directories (sessions, cache, IDE state) and large vendored binaries (gstack/browse skills).

---

## Running Individual Scripts

You don't have to run `setup-all.sh`. Each script works standalone:

```bash
# Install just the tools
bash install-tools.sh
source ~/.bashrc  # or ~/.zshrc on macOS

# Install just the MCP packages
bash install-mcp-packages.sh

# Just configure the shell
bash configure-shell.sh

# Just verify everything is working
bash verify.sh
```

---

## Manual Steps

Some steps can't be automated. See [MANUAL-STEPS.md](MANUAL-STEPS.md) for:

- **Platform prerequisites** — Xcode CLI tools + Homebrew (macOS), WSL2 (Windows)
- **IDE installation** — VS Code and/or Cursor, with per-platform instructions
- **SSH key** — generation and GitHub registration
- **Authentication** — GitHub CLI, Doppler
- **Environment variables** — `.env` file for API keys

---

## Architecture

```
├── setup-all.sh              <- Master orchestrator
├── setup.conf.example        <- User config template
├── lib/
│   ├── common.sh             <- Shared logging, colors, helpers
│   ├── platform.sh           <- Platform/IDE/shell detection
│   └── config.sh             <- Config loading, prompting, validation
├── install-tools.sh          <- Tool installation (brew/apt dispatch)
├── install-mcp-packages.sh   <- Config-driven MCP server installation
├── configure-shell.sh        <- Shell RC configuration (.bashrc/.zshrc)
├── configure-directories.sh  <- Project root + repo scanning
├── generate-mcp-json.sh      <- .mcp.json generation from template
├── generate-workspace.sh     <- IDE workspace generation
├── install-defaults.sh       <- Claude Code status line + defaults
├── export-claude-config.sh   <- Export ~/.claude/ to tarball
├── import-claude-config.sh   <- Import ~/.claude/ (merge or replace)
├── patch-project-settings.sh <- Fix hardcoded paths after import
├── verify.sh                 <- Post-setup verification
├── templates/
│   ├── mcp.json.template     <- .mcp.json template with path placeholders
│   └── statusline.sh         <- Claude Code status line script
└── MANUAL-STEPS.md           <- Per-platform manual step guide
```

---

## Forking & Customizing

This repo is designed to be forked and customized for your team:

1. **Fork** this repo
2. **Edit `setup.conf.example`** with your team's defaults
3. **Edit `templates/mcp.json.template`** if you use different MCP servers
4. **Edit `templates/statusline.sh`** to customize the Claude Code status bar
5. **Ship it** — your team clones your fork, copies `setup.conf.example` to `setup.conf`, and runs `bash setup-all.sh`

---

## License

MIT
