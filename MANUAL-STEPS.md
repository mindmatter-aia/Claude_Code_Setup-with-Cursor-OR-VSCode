# Manual Setup Steps

Steps that cannot be automated — complete these before and after running the setup scripts.

---

## Platform Prerequisites

### macOS

1. **Install Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```

2. **Install Homebrew:**
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   Follow the post-install instructions to add Homebrew to your PATH.

### Linux (Ubuntu/Debian)

Ensure these are available (usually pre-installed):
```bash
sudo apt-get update && sudo apt-get install -y git curl wget
```

### Windows (WSL2)

1. **Enable WSL2** — Open PowerShell as Administrator:
   ```powershell
   wsl --install
   ```
   Restart if prompted. Then install Ubuntu 24.04:
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
   Set a username and password when prompted.

2. Continue with the Linux setup steps inside WSL2.

---

## IDE Installation

Choose one or both:

### VS Code

| Platform | Installation |
|----------|-------------|
| **macOS** | Download from https://code.visualstudio.com. After installing, open VS Code and run `Shell Command: Install 'code' command in PATH` from the command palette (Cmd+Shift+P). |
| **Linux** | `sudo snap install code --classic` or download from https://code.visualstudio.com |
| **WSL2** | Install VS Code on Windows, then install the **WSL** extension (`ms-vscode-remote.remote-wsl`) |

### Cursor

| Platform | Installation |
|----------|-------------|
| **macOS** | Download from https://cursor.com. After installing, run `Shell Command: Install 'cursor' command in PATH` from the command palette. |
| **Linux** | Download AppImage from https://cursor.com |
| **WSL2** | Install Cursor on Windows, then install the **WSL** extension from Cursor's marketplace |

---

## Running the Setup

```bash
# Clone the repo
git clone https://github.com/YOUR-ORG/YOUR-REPO.git ~/claude-code-setup
cd ~/claude-code-setup

# Copy and edit config (optional — setup-all.sh will prompt if missing)
cp setup.conf.example setup.conf
# Edit setup.conf

# Option A: Run everything at once
bash setup-all.sh

# Option B: Run everything + import Claude config from another machine
bash setup-all.sh /path/to/claude-config-YYYYMMDD-HHMMSS.tar.gz

# Option C: Run individual scripts
bash install-tools.sh
source ~/.bashrc  # or ~/.zshrc on macOS
bash install-mcp-packages.sh
bash configure-shell.sh
source ~/.bashrc  # or ~/.zshrc
bash configure-directories.sh
bash generate-mcp-json.sh
bash generate-workspace.sh
bash install-defaults.sh
```

---

## After Running Scripts

### Generate SSH Key

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Press Enter for default location. Set a passphrase or leave empty.

### Add SSH Key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the output. Go to https://github.com/settings/ssh/new and paste it.

Test:
```bash
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated"
```

### Authenticate GitHub CLI

```bash
gh auth login
```

Choose: GitHub.com > SSH > your key > Login with browser.

### Authenticate Doppler (if using)

```bash
doppler login
```

Follow the browser authentication flow. Then configure:
```bash
cd ~/projects/dev-env
doppler setup
```

Select your project and config as needed.

### Configure Environment Variables

```bash
cd ~/projects/dev-env
cp .env.example .env
```

Edit `.env` with your actual values (API keys, etc.).

### Verify Setup

```bash
bash verify.sh
```

All checks should pass (authentication warnings are OK if you haven't completed those steps yet).

### Open Your IDE

```bash
# VS Code
code dev-env.code-workspace

# Cursor
cursor dev-env.code-workspace
```

### Test Claude Code

```bash
cd ~/projects/dev-env
claude
```

---

## Exporting Config to Transfer

On the **source machine** (the one that's already set up):

```bash
cd ~/claude-code-setup
bash export-claude-config.sh
```

This creates `export/claude-config-YYYYMMDD-HHMMSS.tar.gz`. Transfer this file to the new machine.

**Note:** The `browse/` and `gstack/` skills (vendored binaries) are excluded from the export. After import, reinstall them:

```bash
cd ~/.claude/skills
npx @anthropic-ai/gstack init
```
