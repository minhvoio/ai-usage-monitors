# ai-usage-monitors - Windows installer (PowerShell)
# Installs cu + cou via npm, then offers to install the companion macu.
# cu currently only supports macOS; cou works on Windows.
#
# Usage:
#   irm https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.ps1 | iex
#
# Flags (pass as env var since piping into iex drops args):
#   $env:INSTALL_COMPANION = "yes" | "no"

$ErrorActionPreference = "Stop"

$askCompanion = if ($env:INSTALL_COMPANION) { $env:INSTALL_COMPANION } else { "auto" }

Write-Host ""
Write-Host "  ai-usage-monitors - cu + cou" -ForegroundColor Cyan
Write-Host "  Live subscription monitors for Claude Code and Codex CLI" -ForegroundColor DarkGray
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

function Require-Cmd($name, $hint) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Host "  X $name not found. $hint" -ForegroundColor Red
    exit 1
  }
}

Require-Cmd "node"   "Install Node.js >= 18 from https://nodejs.org"
Require-Cmd "npm"    "Install Node.js (npm comes bundled) from https://nodejs.org"
Require-Cmd "python" "Install Python 3 from https://www.python.org/downloads/ (ensure 'Add to PATH' is checked)"
Require-Cmd "curl"   "curl.exe ships with Windows 10+. If missing, update Windows or install curl manually."

$nodeVer = (node -v).TrimStart('v').Split('.')[0]
if ([int]$nodeVer -lt 18) {
  Write-Host "  X Node.js >= 18 required. Found: $(node -v)" -ForegroundColor Red
  exit 1
}

Write-Host "  OK Node.js $(node -v)" -ForegroundColor Green
Write-Host "  OK npm $(npm -v)" -ForegroundColor Green
Write-Host "  OK Python $((python --version) -replace '^Python\s+','')" -ForegroundColor Green
Write-Host "  OK curl" -ForegroundColor Green

$npmPrefix = (npm config get prefix).Trim()

Write-Host ""
Write-Host "  Installing ai-usage-monitors..." -ForegroundColor White

npm install -g github:minhvoio/ai-usage-monitors
if ($LASTEXITCODE -ne 0) {
  Write-Host "  X Installation failed." -ForegroundColor Red
  Write-Host "  Try manually: npm install -g github:minhvoio/ai-usage-monitors" -ForegroundColor DarkGray
  exit 1
}

$cuCmd  = Join-Path $npmPrefix "cu.cmd"
$couCmd = Join-Path $npmPrefix "cou.cmd"
if (Test-Path $cuCmd)  { Write-Host "  OK cu  -> $cuCmd"  -ForegroundColor Green }
if (Test-Path $couCmd) { Write-Host "  OK cou -> $couCmd" -ForegroundColor Green }

Write-Host ""
Write-Host "  Note: cu (Claude Code) currently only supports macOS." -ForegroundColor Yellow
Write-Host "        cou (Codex CLI) works on Windows." -ForegroundColor DarkGray

# Companion: macu
$macuCmd = Join-Path $npmPrefix "macu.cmd"
if (Test-Path $macuCmd) {
  Write-Host ""
  Write-Host "  Companion already installed: macu in PATH." -ForegroundColor DarkGray
} else {
  Write-Host ""
  Write-Host "  ━━━ Companion tool: macu ━━━" -ForegroundColor Magenta
  Write-Host ""
  Write-Host "  cu/cou show LIVE usage. macu finds HISTORICAL WASTE:" -ForegroundColor DarkGray
  Write-Host "  unused MCP tools that bloat every request by ~9,000 tokens." -ForegroundColor DarkGray
  Write-Host ""
  Write-Host "    > macu" -ForegroundColor DarkGray
  Write-Host "    Tool Frequency (last 180 days, 32,848 calls)"
  Write-Host "    Read         " -NoNewline; Write-Host "####################" -ForegroundColor Cyan -NoNewline; Write-Host "  8,421 (26%)"
  Write-Host "    Edit         " -NoNewline; Write-Host "###############     " -ForegroundColor Cyan -NoNewline; Write-Host "  6,102 (19%)"
  Write-Host "    Grep         " -NoNewline; Write-Host "############        " -ForegroundColor Cyan -NoNewline; Write-Host "  4,890 (15%)"
  Write-Host ""
  Write-Host "    Unused Tools (0 calls - pure overhead)"
  Write-Host "    X mcp__linear-*          (8 tools, ~2,400 tok/request)" -ForegroundColor Red
  Write-Host "    X mcp__slack-*           (12 tools, ~3,600 tok/request)" -ForegroundColor Red
  Write-Host ""
  Write-Host "    Before vs After"
  Write-Host "    Before  " -NoNewline; Write-Host "########################################" -ForegroundColor Yellow -NoNewline; Write-Host "  28,500 tok"
  Write-Host "    After   " -NoNewline; Write-Host "##########################              " -ForegroundColor Green -NoNewline; Write-Host "  19,500 tok"
  Write-Host "    Savings " -NoNewline; Write-Host "##############                          " -ForegroundColor Green -NoNewline; Write-Host "   9,000 tok (32%)"
  Write-Host ""

  if ($askCompanion -eq "auto") {
    try {
      $answer = Read-Host "  Install macu too? [Y/n]"
      if ($answer -match '^[nN]') { $askCompanion = "no" } else { $askCompanion = "yes" }
    } catch {
      Write-Host "  Non-interactive install. Skipping companion prompt." -ForegroundColor DarkGray
      Write-Host "  Install later:" -ForegroundColor DarkGray
      Write-Host "    npm install -g macu" -ForegroundColor DarkGray
      $askCompanion = "no"
    }
  }

  if ($askCompanion -eq "yes") {
    Write-Host ""
    Write-Host "  Installing macu..." -ForegroundColor White
    npm install -g macu 2>$null
    if ($LASTEXITCODE -ne 0) {
      npm install -g github:minhvoio/macu_minimize-ai-credit-usage
    }
    if (Test-Path $macuCmd) {
      Write-Host "  OK macu -> $macuCmd" -ForegroundColor Green
    } else {
      Write-Host "  X macu install failed." -ForegroundColor Red
      Write-Host "  Try manually: npm install -g macu" -ForegroundColor DarkGray
    }
  } else {
    Write-Host "  Skipped. Install later:" -ForegroundColor DarkGray
    Write-Host "    npm install -g macu" -ForegroundColor DarkGray
  }
}

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Done." -ForegroundColor Green
Write-Host ""
Write-Host "    cou         Codex CLI subscription usage"
Write-Host "    cou --json  JSON output"
if (Test-Path $macuCmd) {
  Write-Host "    macu        Analyze tool usage + optimize tokens"
}
Write-Host ""
