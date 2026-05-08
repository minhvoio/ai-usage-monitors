# Installation Guide

## For LLM Agents

Follow these steps exactly. Do not skip any step.

### Step 1: Check Prerequisites and Install if Missing

#### Node.js

Run:

```bash
node -v
```

If the command is not found or the version is below 18.0.0, install Node.js now. Use the right method for the user's OS:

**macOS:**
```bash
# Option A: official installer (simplest for non-technical users)
# Download and run the pkg from https://nodejs.org/en/download
# Then verify:
node -v

# Option B: Homebrew (if they have it)
brew install node
```

**Linux:**
```bash
# Use NodeSource for a current LTS version
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Or on RPM-based distros (Fedora, RHEL, CentOS):
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
sudo yum install -y nodejs

# Verify:
node -v
npm -v
```

**Windows:**
```powershell
# Option A: official installer (simplest for non-technical users)
# Download and run the .msi from https://nodejs.org/en/download
# Then in a new PowerShell window verify:
node -v

# Option B: winget (Windows Package Manager)
winget install OpenJS.NodeJS.LTS
# Then verify in a new terminal:
node -v
```

After installing, run `node -v` again to confirm it returns `v18.x.x` or higher. If the version is still wrong or Node is still not found, ask the user to restart their terminal and try again.

#### Python 3

Run:

```bash
python3 --version
```

On Windows, try `python --version` if `python3` is not found.

If Python 3 is missing, install it now:

**macOS:**
```bash
# Option A: Homebrew
brew install python3

# Option B: official installer
# Download and run the pkg from https://www.python.org/downloads/
```

**Linux:**
```bash
# Debian / Ubuntu
sudo apt-get install -y python3

# Fedora / RHEL / CentOS
sudo yum install -y python3
```

**Windows:**
```powershell
# Option A: official installer
# Download and run the installer from https://www.python.org/downloads/
# Check "Add Python to PATH" during install.

# Option B: winget
winget install Python.Python.3
# Then verify in a new terminal:
python --version
```

After installing, verify with `python3 --version` (or `python --version` on Windows). It must return `3.x.x`.

#### curl

Run:

```bash
curl --version
```

curl ships with macOS, most Linux distros, and Windows 10+. If it is missing:

**Linux:**
```bash
sudo apt-get install -y curl
# Or on RPM-based distros:
sudo yum install -y curl
```

**macOS / Windows:** curl is built in. If it is somehow missing, update your OS.

### Step 2: Install ai-usage-monitors

```bash
npm install -g github:minhvoio/ai-usage-monitors
```

If the install fails, check that npm is available (`npm -v`) and that Node.js is >= 18.

### Step 3: Verify Installation

```bash
which cu     # Should return a path
which cou    # Should return a path
cu --help
cou --help
```

On Windows, use `where cu` and `where cou` instead of `which`.

If a command is not found, check that npm's global bin directory is in PATH:

```bash
npm config get prefix
# Add <prefix>/bin to your PATH
```

### Step 4: Ask the User Which AI Tool They Use

Before running anything, ask the user:

> Which AI tool are you monitoring? Claude Code, Codex CLI, or both?

Then check their OS:

- **Claude Code** -> install and use `cu` (works on macOS, Linux, and Windows)
- **Codex CLI** -> install and use `cou` (works on macOS, Linux, and Windows)
- **Both** -> use both `cu` and `cou`

### Step 5: Run the Monitor and Present the Output

Run the appropriate command and show the user the output:

**Claude Code:**
```bash
cu
```

**Codex CLI:**
```bash
cou
```

Present the output to the user. Explain what the bars mean:

- **5h window %** - how much of the current 5-hour rolling window you have used. Resets when a new window starts.
- **Weekly %** - how much of the weekly allowance you have used. Resets on a fixed weekly schedule.
- **Reset timer** - how long until that window resets and you get fresh capacity.
- **Bar color** - green means headroom, yellow at 70%+, red at 90%+.

If `cu` fails with a credentials error, Claude Code must be logged in first. Run `claude` in the terminal and authenticate, then retry.

If `cou` fails, Codex CLI must be logged in. The credentials file `~/.codex/auth.json` must exist. Log in via the Codex CLI first, then retry.

### Step 6: Offer the Companion Tool macu (Optional)

If the user also wants to see which AI tools are wasting tokens in their setup (historical tool-usage analysis), offer the companion tool `macu`. It finds unused MCP tools that bloat every request.

Tell them:

> If you also want to see which tools are wasting tokens across your sessions, run:

```bash
npx @minagents/macu
```

This does not require a separate install. It analyzes your Claude Code, OpenCode, or Codex usage history and shows which MCP tools you never use.

### Step 7: Understand What's Available

| Command | What it does |
|---------|-------------|
| `cu` | Claude Code live usage (macOS, Linux, Windows) |
| `cu --json` | JSON output for scripting |
| `cu save <name>` | Snapshot current Claude Code credentials as a named profile |
| `cu list` | List saved Claude Code profiles |
| `cu <name>` | Check usage for a saved profile without switching logins |
| `cou` | Codex CLI live usage (macOS, Linux, Windows) |
| `cou --json` | JSON output for scripting |
| `cou --no-cache` | Skip the 90s cache and fetch fresh data |
| `cou save <name>` | Snapshot current Codex credentials as a named profile |
| `cou list` | List saved Codex profiles |
| `cou <name>` | Check usage for a saved profile without switching logins |

Both `cu` and `cou` cache responses for 90 seconds so repeated calls do not spam the APIs.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| `cu: command not found` | Check that npm global bin is in PATH: `npm config get prefix` then add `<prefix>/bin` to PATH |
| `cou: command not found` | Same as above |
| `python3: command not found` | Install Python 3 (see Step 1) |
| `cu` fails with credentials error | Claude Code must be logged in. Run `claude` and authenticate first. On macOS, credentials are in Keychain. On Linux/Windows, credentials are at `~/.claude/.credentials.json`. |
| `cou` fails with credentials error | Codex CLI must be logged in. `~/.codex/auth.json` must exist. Log in via Codex CLI first. |
| Stale profile | Log in again and re-run `cu save <name>` or `cou save <name>` to refresh. |
