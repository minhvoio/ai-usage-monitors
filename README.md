# ai-usage-monitors

Live subscription usage monitors for **Claude Code** and **Codex CLI**. Two commands, colored bars, reset timers, zero configuration.

## Why

If you're on a paid Claude Code or Codex CLI plan, you want to know how much of your window you've already burned through without opening a browser or checking a dashboard. These two commands print it in your terminal in under a second.

- **`cu`** reads Claude Code credentials from macOS Keychain, calls the Anthropic OAuth usage endpoint, prints 5h / weekly / Sonnet / Opus utilization.
- **`cou`** reads Codex CLI credentials from `~/.codex/auth.json`, fires a minimal inference request (the cheapest possible: `model="gpt-5.2", instructions="ok", store=false`), parses the `x-codex-*` rate-limit headers, prints primary / secondary window utilization.

Both cache responses for 90 seconds so repeated calls don't spam the APIs.

## What you'll see

```
  Claude Code Usage  -  2026-04-18 12:13
  ───────────────────────────────────────────────────────
  5h limit   ██████████░░░░░░░░░░   51.0%  resets in 2h46m
  Weekly     ████░░░░░░░░░░░░░░░░   21.0%  resets in 5d20h
  Sonnet wk  █░░░░░░░░░░░░░░░░░░░    7.0%  resets in 5d20h
  Extra crd    9895.0 credits used
```

```
  Codex CLI Usage  (team / premium)  -  2026-04-18 12:28
  ───────────────────────────────────────────────────────
  5h window    ██░░░░░░░░░░░░░░░░░░    8.5%  resets in 4h12m
  7d window    █░░░░░░░░░░░░░░░░░░░    3.2%  resets in 5d18h
```

Bars are green when there's headroom, yellow at 70%+, red at 90%+.

---

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.ps1 | iex
```

### Any platform (direct)

```bash
npm install -g github:minhvoio/ai-usage-monitors
```

The installer will ask if you also want the companion tool [**macu**](https://github.com/minhvoio/macu_minimize-ai-credit-usage) (historical tool-usage analysis + MCP optimization). Skip the prompt:

```bash
# Monitors only (no prompt)
curl -fsSL https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.sh | bash -s -- --no-companion

# Install both at once (no prompt)
curl -fsSL https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.sh | bash -s -- --yes
```

Windows equivalent (PowerShell):

```powershell
$env:INSTALL_COMPANION = "yes"   # or "no"
irm https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.ps1 | iex
```

---

## Usage

```bash
cu                 # Claude Code usage
cu --json          # JSON output

cou                # Codex CLI usage
cou --json         # JSON output
cou --no-cache     # Skip the 90s cache, fetch fresh
```

### Multiple accounts

If you have more than one Claude Code or Codex account, you can save each one as a named profile and check usage without switching logins.

```bash
# Log into your work account, then snapshot it:
cu save work

# Log into your personal account, then snapshot it:
cu save personal

# Check either account any time - no login switching:
cu work
cu personal
cu work --json

# Same for Codex:
cou save team-a
cou save team-b
cou team-a
cou team-b

# List saved profiles:
cu list
cou list
```

Running `cu` or `cou` with no profile name still reads the live credentials, same as before.

Saved profiles auto-refresh their tokens, so they stay valid until the refresh token itself is revoked. If a profile goes stale, just log in again and re-run `cu save <name>`.

Profiles are stored at `~/.config/ai-usage-monitors/profiles/<name>/`.

### JSON shape (`cu --json`)

```json
{
  "fiveHourPercent": 51.0,
  "fiveHourResetsAt": "2026-04-18T14:59:00Z",
  "weeklyPercent": 21.0,
  "weeklyResetsAt": "2026-04-24T12:00:00Z",
  "sonnetWeeklyPercent": 7.0,
  "opusWeeklyPercent": null,
  "extraUsedCredits": 9895.0,
  "extraEnabled": true
}
```

### JSON shape (`cou --json`)

```json
{
  "planType": "team",
  "activeLimit": "premium",
  "primaryPercent": 8.5,
  "primaryWindowMinutes": 300,
  "primaryResetAt": 1729345200,
  "secondaryPercent": 3.2,
  "secondaryWindowMinutes": 10080,
  "secondaryResetAt": 1729776000,
  "creditsHasCredits": false,
  "creditsUnlimited": false
}
```

---

## Platform support

| Command | macOS | Linux | Windows |
|---------|-------|-------|---------|
| `cu`    | yes   | no    | no      |
| `cou`   | yes   | yes   | yes     |

`cu` is macOS-only because it reads Claude Code credentials from the macOS Keychain. If you need `cu` on Windows or Linux, please [open an issue](https://github.com/minhvoio/ai-usage-monitors/issues). I haven't mapped where Claude Code stores credentials on those platforms yet.

`cou` works everywhere because it reads credentials from a plain file (`~/.codex/auth.json` on macOS/Linux, `%USERPROFILE%\.codex\auth.json` on Windows).

---

## How it works

### `cu` - Claude Code

1. Reads `Claude Code-credentials` entry from macOS Keychain via `security find-generic-password`.
2. If the access token is expired, refreshes via `POST https://platform.claude.com/v1/oauth/token`.
3. Calls `GET https://api.anthropic.com/api/oauth/usage` with `anthropic-beta: oauth-2025-04-20`.
4. Renders utilization bars for each window (5h, weekly, Sonnet weekly, Opus weekly).
5. Caches the response at `~/.claude/plugins/oh-my-claudecode/.usage-cache.json` for 90s.

### `cou` - Codex CLI

Codex has **no dedicated usage endpoint**. The only way to read rate-limit state is to make an inference call and parse the `x-codex-*` response headers.

1. Reads access token + refresh token from `~/.codex/auth.json`.
2. If expired, refreshes via `POST https://auth.openai.com/oauth/token`.
3. Determines the base URL from `auth_mode`: `chatgpt` -> `https://chatgpt.com/backend-api/codex`, otherwise `https://api.openai.com/v1`.
4. Fires `POST /responses` with the minimum possible body: `{"model": "gpt-5.2", "instructions": "ok", "input": [...], "stream": true, "store": false}`. If `~/.codex/config.toml` sets a different model, tries that first, falls back to `gpt-5.2` then `gpt-5.4`.
5. Parses `x-codex-*` headers: `x-codex-primary-used-percent`, `x-codex-primary-window-minutes`, `x-codex-primary-reset-at`, plus secondary equivalents, plan type, active limit, credits balance.
6. Renders utilization bars. Caches at `~/.codex/.macu-cache/usage.json` for 90s.

`cou` needs to make a real inference call because that's the only place the headers exist. The request is as small as possible: 2 tokens of input, `store=false`, no `max_output_tokens`.

---

## Companion: macu

`cu` / `cou` show **live usage**: how much of your window you've burned through right now. The companion [**macu**](https://github.com/minhvoio/macu_minimize-ai-credit-usage) finds **historical waste**: unused MCP tools that bloat every request with thousands of tokens you never use.

Run `macu` to see which tools earn their keep and which are dead weight, then follow its action plan to clean up. On a real setup it found 54 removable tools and a 45% token reduction per message.

Install it:

```bash
curl -fsSL https://raw.githubusercontent.com/minhvoio/macu_minimize-ai-credit-usage/main/install.sh | bash
```

Or let this installer offer it at the end. It prompts `Install macu too? [Y/n]` by default.

---

## Requirements

- **Node.js >= 18** for `npm install -g` and the cross-platform command wrappers
- **Python 3** does the actual work. `python3` on macOS/Linux, `python` on Windows
- **curl** ships with macOS, most Linux distros, and Windows 10+
- **`cu` only**: macOS + Claude Code logged in (`claude` CLI)
- **`cou` only**: Codex CLI logged in (`~/.codex/auth.json` exists)

## License

MIT
