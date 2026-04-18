# ai-usage-monitors - Windows installer (PowerShell)
# Installs cu + cou via npm. cu currently only supports macOS; cou works on Windows.
#
# Usage:
#   irm https://raw.githubusercontent.com/minhvoio/ai-usage-monitors/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

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

Write-Host ""
Write-Host "  Installing ai-usage-monitors..." -ForegroundColor White

npm install -g github:minhvoio/ai-usage-monitors
if ($LASTEXITCODE -ne 0) {
  Write-Host "  X Installation failed." -ForegroundColor Red
  Write-Host "  Try manually: npm install -g github:minhvoio/ai-usage-monitors" -ForegroundColor DarkGray
  exit 1
}

if (Get-Command cu -ErrorAction SilentlyContinue) {
  Write-Host "  OK cu  -> $((Get-Command cu).Source)" -ForegroundColor Green
}
if (Get-Command cou -ErrorAction SilentlyContinue) {
  Write-Host "  OK cou -> $((Get-Command cou).Source)" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Note: cu (Claude Code) currently only supports macOS." -ForegroundColor Yellow
Write-Host "        cou (Codex CLI) works on Windows." -ForegroundColor DarkGray

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Done." -ForegroundColor Green
Write-Host ""
Write-Host "    cou         Codex CLI subscription usage (Codex CLI logged in)"
Write-Host "    cou --json  JSON output"
Write-Host ""
