#!/bin/bash
set -e

BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo ""
echo -e "${CYAN}${BOLD}  ai-usage-monitors${RESET}${DIM} - cu + cou${RESET}"
echo -e "${DIM}  Live subscription monitors for Claude Code and Codex CLI${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
echo ""

# ── Prerequisites ─────────────────────────────────────

if ! command -v node &>/dev/null; then
  echo -e "${RED}  ✗ Node.js not found.${RESET} Install it: https://nodejs.org"
  exit 1
fi

NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo -e "${RED}  ✗ Node.js >= 18 required.${RESET} Found: $(node -v)"
  exit 1
fi

if ! command -v npm &>/dev/null; then
  echo -e "${RED}  ✗ npm not found.${RESET}"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}  ✗ Python 3 not found.${RESET} Install it: brew install python3 (macOS) or apt install python3 (Linux)"
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo -e "${RED}  ✗ curl not found.${RESET}"
  exit 1
fi

echo -e "${GREEN}  ✓${RESET} Node.js $(node -v)"
echo -e "${GREEN}  ✓${RESET} npm $(npm -v)"
echo -e "${GREEN}  ✓${RESET} Python $(python3 --version | awk '{print $2}')"
echo -e "${GREEN}  ✓${RESET} curl"

# ── Install ai-usage-monitors ─────────────────────────

echo ""
echo -e "${BOLD}  Installing ai-usage-monitors...${RESET}"

npm install -g github:minhvoio/ai-usage-monitors 2>/dev/null || {
  echo -e "${RED}  ✗ Installation failed.${RESET}"
  echo -e "${DIM}  Try manually: npm install -g github:minhvoio/ai-usage-monitors${RESET}"
  exit 1
}

if command -v cu &>/dev/null; then
  echo -e "${GREEN}  ✓${RESET} cu  → $(which cu)"
else
  echo -e "${RED}  ✗ cu not found in PATH after install.${RESET}"
  exit 1
fi

if command -v cou &>/dev/null; then
  echo -e "${GREEN}  ✓${RESET} cou → $(which cou)"
else
  echo -e "${RED}  ✗ cou not found in PATH after install.${RESET}"
  exit 1
fi

# ── Platform notes ────────────────────────────────────

echo ""
if [ "$(uname)" != "Darwin" ]; then
  echo -e "${YELLOW}  ⚠${RESET} cu requires macOS (reads Keychain). Detected: $(uname)."
  echo -e "${DIM}    cou works on this platform.${RESET}"
fi

# ── Done ──────────────────────────────────────────────

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}${BOLD}  Done.${RESET} Run:"
echo ""
echo -e "    ${CYAN}cu${RESET}         Claude Code subscription usage (macOS + Claude Code logged in)"
echo -e "    ${CYAN}cou${RESET}        Codex CLI subscription usage (macOS/Linux + Codex logged in)"
echo -e "    ${CYAN}cu --json${RESET}  JSON output (both monitors support --json)"
echo ""
