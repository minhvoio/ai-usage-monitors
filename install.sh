#!/bin/bash
set -e

BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
RESET="\033[0m"

ASK_COMPANION="auto"
for arg in "$@"; do
  case "$arg" in
    -y|--yes)           ASK_COMPANION="yes" ;;
    --no-companion)     ASK_COMPANION="no" ;;
    --with-companion)   ASK_COMPANION="yes" ;;
  esac
done
[ "${INSTALL_COMPANION:-}" = "yes" ] && ASK_COMPANION="yes"
[ "${INSTALL_COMPANION:-}" = "no" ]  && ASK_COMPANION="no"

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

NPM_PREFIX=$(npm config get prefix 2>/dev/null || echo "")

# ── Install ai-usage-monitors ─────────────────────────

echo ""
echo -e "${BOLD}  Installing ai-usage-monitors...${RESET}"

npm install -g github:minhvoio/ai-usage-monitors 2>/dev/null || {
  echo -e "${RED}  ✗ Installation failed.${RESET}"
  echo -e "${DIM}  Try manually: npm install -g github:minhvoio/ai-usage-monitors${RESET}"
  exit 1
}

if [ -L "$NPM_PREFIX/bin/cu" ]; then
  echo -e "${GREEN}  ✓${RESET} cu  → $NPM_PREFIX/bin/cu"
else
  echo -e "${RED}  ✗ cu not found at $NPM_PREFIX/bin/cu after install.${RESET}"
  exit 1
fi

if [ -L "$NPM_PREFIX/bin/cou" ]; then
  echo -e "${GREEN}  ✓${RESET} cou → $NPM_PREFIX/bin/cou"
else
  echo -e "${RED}  ✗ cou not found at $NPM_PREFIX/bin/cou after install.${RESET}"
  exit 1
fi

case ":$PATH:" in
  *":$NPM_PREFIX/bin:"*) ;;
  *) echo ""
     echo -e "${YELLOW}  ⚠${RESET} $NPM_PREFIX/bin is not in PATH. Add it so cu/cou can be found."
     echo -e "${DIM}     On macOS /usr/bin/cu (a built-in modem tool) may shadow ours${RESET}"
     echo -e "${DIM}     if npm prefix comes later in PATH. Put it first.${RESET}" ;;
esac

# ── Platform notes ────────────────────────────────────

if [ "$(uname)" != "Darwin" ]; then
  echo ""
  echo -e "${YELLOW}  ⚠${RESET} cu requires macOS (reads Keychain). Detected: $(uname)."
  echo -e "${DIM}    cou works on this platform.${RESET}"
fi

# ── Companion: macu ───────────────────────────────────

if [ -n "$NPM_PREFIX" ] && [ -L "$NPM_PREFIX/bin/macu" ]; then
  echo ""
  echo -e "${DIM}  Companion already installed: macu in npm global prefix.${RESET}"
else
  echo ""
  echo -e "${MAGENTA}${BOLD}  ━━━ Companion tool: macu ━━━${RESET}"
  echo ""
  echo -e "${DIM}  cu/cou show LIVE usage. macu finds HISTORICAL WASTE:${RESET}"
  echo -e "${DIM}  unused MCP tools that bloat every request by ~9,000 tokens.${RESET}"
  echo ""
  echo -e "${DIM}    \$ macu${RESET}"
  echo -e "${BOLD}    Tool Frequency${RESET} ${DIM}(last 180 days, 32,848 calls)${RESET}"
  echo -e "    ${BOLD}Read${RESET}         ${CYAN}████████████████████${RESET}  8,421 ${DIM}(26%)${RESET}"
  echo -e "    ${BOLD}Edit${RESET}         ${CYAN}███████████████${RESET}       6,102 ${DIM}(19%)${RESET}"
  echo -e "    ${BOLD}Grep${RESET}         ${CYAN}████████████${RESET}          4,890 ${DIM}(15%)${RESET}"
  echo ""
  echo -e "${BOLD}    Unused Tools${RESET} ${DIM}(0 calls - pure overhead)${RESET}"
  echo -e "    ${RED}✗${RESET} mcp__linear-*          ${DIM}(8 tools, ~2,400 tok/request)${RESET}"
  echo -e "    ${RED}✗${RESET} mcp__slack-*           ${DIM}(12 tools, ~3,600 tok/request)${RESET}"
  echo ""
  echo -e "${BOLD}    Before vs After${RESET}"
  echo -e "    Before  ${YELLOW}████████████████████████████████████████${RESET}  28,500 tok"
  echo -e "    After   ${GREEN}██████████████████████████${RESET}               19,500 tok"
  echo -e "    Savings ${GREEN}${BOLD}██████████████${RESET}                       9,000 tok ${GREEN}(32%)${RESET}"
  echo ""

  if [ "$ASK_COMPANION" = "auto" ]; then
    if { exec 3< /dev/tty; } 2>/dev/null; then
      printf "  ${BOLD}Install macu too?${RESET} ${DIM}[Y/n]${RESET} "
      read -r answer <&3 || answer=""
      exec 3<&-
      case "$answer" in
        n|N|no|NO) ASK_COMPANION="no" ;;
        *)         ASK_COMPANION="yes" ;;
      esac
    else
      echo -e "${DIM}  Non-interactive install (piped). Skipping companion prompt.${RESET}"
      echo -e "${DIM}  Install macu later:${RESET}"
      echo -e "${DIM}    curl -fsSL https://raw.githubusercontent.com/minhvoio/macu_minimize-ai-credit-usage/main/install.sh | bash${RESET}"
      echo -e "${DIM}  Or rerun this with --yes to install both at once.${RESET}"
      ASK_COMPANION="no"
    fi
  fi

  if [ "$ASK_COMPANION" = "yes" ]; then
    echo ""
    echo -e "${BOLD}  Installing macu...${RESET}"
    npm install -g macu 2>/dev/null || \
    npm install -g github:minhvoio/macu_minimize-ai-credit-usage 2>/dev/null || {
      echo -e "${RED}  ✗ macu install failed.${RESET}"
      echo -e "${DIM}  Try manually: npm install -g github:minhvoio/macu_minimize-ai-credit-usage${RESET}"
    }

    if [ -L "$NPM_PREFIX/bin/macu" ]; then
      echo -e "${GREEN}  ✓${RESET} macu → $NPM_PREFIX/bin/macu"
    fi
  else
    echo -e "${DIM}  Skipped. Install later:${RESET}"
    echo -e "${DIM}    curl -fsSL https://raw.githubusercontent.com/minhvoio/macu_minimize-ai-credit-usage/main/install.sh | bash${RESET}"
  fi
fi

# ── Done ──────────────────────────────────────────────

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}${BOLD}  Done.${RESET} Run:"
echo ""
echo -e "    ${CYAN}cu${RESET}         Claude Code subscription usage (macOS + Claude Code logged in)"
echo -e "    ${CYAN}cou${RESET}        Codex CLI subscription usage (macOS/Linux + Codex logged in)"
echo -e "    ${CYAN}cu --json${RESET}  JSON output (both monitors support --json)"
if [ -n "$NPM_PREFIX" ] && [ -L "$NPM_PREFIX/bin/macu" ]; then
  echo -e "    ${CYAN}macu${RESET}       Analyze tool usage + optimize tokens"
fi
echo ""
