#!/usr/bin/env python3
"""codex-usage - Show Codex CLI subscription usage with colored terminal bars.

Reads credentials from ~/.codex/auth.json, fires a minimal /responses request
to trigger the x-codex-* rate-limit headers, and displays primary/secondary
window utilization with colored progress bars.

Why a real request? Codex has no dedicated usage endpoint. Rate-limit data is
delivered only via response headers on inference calls. We send the cheapest
possible prompt ("hi") and parse headers from the response.

Requires: Python 3, curl, Codex CLI logged in (~/.codex/auth.json exists).
"""

import base64
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import (
    RESET,
    BOLD,
    DIM,
    GREEN,
    YELLOW,
    RED,
    CYAN,
    bar,
    pct_color,
    time_until,
    format_window,
)

HOME = Path.home()

AUTH_FILE = HOME / ".codex" / "auth.json"
CONFIG_FILE = HOME / ".codex" / "config.toml"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
TOKEN_REFRESH_URL = "https://auth.openai.com/oauth/token"

CHATGPT_BASE = "https://chatgpt.com/backend-api/codex"
API_BASE = "https://api.openai.com/v1"

CACHE_DIR = HOME / ".codex" / ".macu-cache"
CACHE_FILE = CACHE_DIR / "usage.json"
CACHE_TTL_MS = 90_000

API_TIMEOUT_S = 30

FALLBACK_MODELS = ["gpt-5.2", "gpt-5.4"]


# ── Credentials ───────────────────────────────────────────


def read_auth():
    try:
        if not AUTH_FILE.exists():
            return None
        return json.loads(AUTH_FILE.read_text())
    except Exception:
        return None


def decode_jwt_payload(jwt):
    try:
        parts = jwt.split(".")
        if len(parts) != 3:
            return None
        payload = parts[1]
        payload += "=" * (-len(payload) % 4)  # base64 padding
        decoded = base64.urlsafe_b64decode(payload)
        return json.loads(decoded)
    except Exception:
        return None


def is_token_expired(access_token, skew_seconds=60):
    payload = decode_jwt_payload(access_token)
    if not payload or "exp" not in payload:
        return False
    now_s = datetime.now(timezone.utc).timestamp()
    return payload["exp"] <= (now_s + skew_seconds)


def refresh_tokens(refresh_token):
    body = json.dumps(
        {
            "client_id": CLIENT_ID,
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
        }
    )
    try:
        result = subprocess.run(
            [
                "curl",
                "-s",
                "--max-time",
                str(API_TIMEOUT_S),
                "-X",
                "POST",
                TOKEN_REFRESH_URL,
                "-H",
                "Content-Type: application/json",
                "-d",
                body,
            ],
            capture_output=True,
            text=True,
            timeout=API_TIMEOUT_S + 2,
        )
        if result.returncode == 0 and result.stdout.strip():
            parsed = json.loads(result.stdout.strip())
            if parsed.get("access_token"):
                return {
                    "access_token": parsed["access_token"],
                    "id_token": parsed.get("id_token"),
                    "refresh_token": parsed.get("refresh_token", refresh_token),
                }
    except Exception:
        pass
    return None


def write_auth(auth, tokens):
    try:
        auth["tokens"] = {**auth.get("tokens", {}), **tokens}
        auth["last_refresh"] = (
            datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        )
        AUTH_FILE.write_text(json.dumps(auth, indent=2))
    except Exception:
        pass


# ── API ───────────────────────────────────────────────────


def read_configured_model():
    try:
        if not CONFIG_FILE.exists():
            return None
        for line in CONFIG_FILE.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith("[") and not stripped.startswith("[features]"):
                break  # stop at first section header to avoid per-profile model entries
            if stripped.startswith("model") and "=" in stripped:
                value = stripped.split("=", 1)[1].strip().strip('"').strip("'")
                if value:
                    return value
    except Exception:
        pass
    return None


def try_fetch(auth, model):
    tokens = auth.get("tokens") or {}
    access_token = tokens.get("access_token")
    account_id = tokens.get("account_id")
    if not access_token:
        return None

    auth_mode = auth.get("auth_mode") or ("chatgpt" if access_token else "apikey")
    base_url = CHATGPT_BASE if auth_mode == "chatgpt" else API_BASE
    url = f"{base_url}/responses"

    body = json.dumps(
        {
            "model": model,
            "instructions": "ok",
            "input": [
                {"role": "user", "content": [{"type": "input_text", "text": "hi"}]}
            ],
            "stream": True,
            "store": False,
        }
    )

    cmd = [
        "curl",
        "-sD",
        "-",
        "-o",
        "/dev/null",
        "--max-time",
        str(API_TIMEOUT_S),
        "-X",
        "POST",
        url,
        "-H",
        f"Authorization: Bearer {access_token}",
        "-H",
        "Content-Type: application/json",
        "-H",
        "Accept: text/event-stream",
        "-H",
        "originator: codex_cli_rs",
        "-H",
        "version: 0.0.0",
        "-d",
        body,
    ]
    if account_id:
        cmd.extend(["-H", f"ChatGPT-Account-ID: {account_id}"])

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=API_TIMEOUT_S + 5,
        )
        if result.returncode != 0:
            return None
        return parse_headers(result.stdout)
    except Exception:
        return None


def fetch_headers(auth):
    models_to_try = []
    configured = read_configured_model()
    if configured:
        models_to_try.append(configured)
    for m in FALLBACK_MODELS:
        if m not in models_to_try:
            models_to_try.append(m)

    for model in models_to_try:
        headers = try_fetch(auth, model)
        if headers:
            return headers
    return None


def parse_headers(raw):
    headers = {}
    for line in raw.split("\n"):
        if ":" not in line:
            continue
        name, _, value = line.partition(":")
        name = name.strip().lower()
        value = value.strip()
        if name.startswith("x-codex-"):
            headers[name] = value
    return headers if headers else None


# ── Parsing ───────────────────────────────────────────────


def parse_usage(headers, auth):
    def get_f(key):
        v = headers.get(key)
        try:
            return float(v) if v is not None else None
        except ValueError:
            return None

    def get_i(key):
        v = headers.get(key)
        try:
            return int(v) if v is not None else None
        except ValueError:
            return None

    def truthy(v):
        return (v or "").strip().lower() == "true"

    plan_type = headers.get("x-codex-plan-type")
    if not plan_type:
        id_token = (auth.get("tokens") or {}).get("id_token")
        if id_token:
            payload = decode_jwt_payload(id_token)
            if payload:
                plan_type = payload.get("https://api.openai.com/auth", {}).get(
                    "chatgpt_plan_type"
                )

    credits_balance = headers.get("x-codex-credits-balance")
    try:
        credits_balance = float(credits_balance) if credits_balance else None
    except ValueError:
        credits_balance = None

    return {
        "planType": plan_type,
        "activeLimit": headers.get("x-codex-active-limit"),
        "primaryPercent": get_f("x-codex-primary-used-percent"),
        "primaryWindowMinutes": get_i("x-codex-primary-window-minutes"),
        "primaryResetAt": get_i("x-codex-primary-reset-at"),
        "primaryResetAfterSeconds": get_i("x-codex-primary-reset-after-seconds"),
        "secondaryPercent": get_f("x-codex-secondary-used-percent"),
        "secondaryWindowMinutes": get_i("x-codex-secondary-window-minutes"),
        "secondaryResetAt": get_i("x-codex-secondary-reset-at"),
        "secondaryResetAfterSeconds": get_i("x-codex-secondary-reset-after-seconds"),
        "creditsHasCredits": truthy(headers.get("x-codex-credits-has-credits")),
        "creditsUnlimited": truthy(headers.get("x-codex-credits-unlimited")),
        "creditsBalance": credits_balance,
    }


# ── Cache ─────────────────────────────────────────────────


def read_cache():
    try:
        if CACHE_FILE.exists():
            return json.loads(CACHE_FILE.read_text())
    except Exception:
        pass
    return None


def write_cache(data, token_prefix=None):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        entry = {
            "timestamp": int(datetime.now(timezone.utc).timestamp() * 1000),
            "data": data,
            "tokenPrefix": token_prefix,
        }
        CACHE_FILE.write_text(json.dumps(entry, indent=2))
    except Exception:
        pass


def is_cache_valid(cache, token_prefix=None):
    if not cache or not cache.get("data"):
        return False
    if (
        token_prefix
        and cache.get("tokenPrefix")
        and cache["tokenPrefix"] != token_prefix
    ):
        return False
    age_ms = datetime.now(timezone.utc).timestamp() * 1000 - cache.get("timestamp", 0)
    return age_ms < CACHE_TTL_MS


# ── Rendering ─────────────────────────────────────────────


def format_limits(data):
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    parts = []
    if data.get("planType"):
        parts.append(data["planType"])
    if data.get("activeLimit"):
        parts.append(data["activeLimit"])
    tag_str = f"  ({BOLD}{' / '.join(parts)}{RESET})" if parts else ""

    print()
    print(f"  {BOLD}Codex CLI Usage{RESET}{tag_str}  -  {now_str}")
    print(f"  {'─' * 55}")

    p_pct = data.get("primaryPercent")
    p_win = format_window(data.get("primaryWindowMinutes"))
    p_reset_at = data.get("primaryResetAt")
    if not p_reset_at and data.get("primaryResetAfterSeconds") is not None:
        p_reset_at = int(
            datetime.now(timezone.utc).timestamp() + data["primaryResetAfterSeconds"]
        )
    p_reset = time_until(p_reset_at)
    p_c = pct_color(p_pct)
    p_label = f"{p_win} window".ljust(12)
    if p_pct is not None:
        print(
            f"  {BOLD}{p_label}{RESET} {bar(p_pct, 20)}  "
            f"{p_c}{p_pct:>5.1f}%{RESET}  resets in {p_c}{p_reset}{RESET}"
        )
    else:
        print(f"  {BOLD}{p_label}{RESET} {DIM}no data yet{RESET}")

    s_pct = data.get("secondaryPercent")
    if s_pct is not None:
        s_win = format_window(data.get("secondaryWindowMinutes"))
        s_reset_at = data.get("secondaryResetAt")
        if not s_reset_at and data.get("secondaryResetAfterSeconds") is not None:
            s_reset_at = int(
                datetime.now(timezone.utc).timestamp()
                + data["secondaryResetAfterSeconds"]
            )
        s_reset = time_until(s_reset_at)
        s_c = pct_color(s_pct)
        s_label = f"{s_win} window".ljust(12)
        print(
            f"  {BOLD}{s_label}{RESET} {bar(s_pct, 20)}  "
            f"{s_c}{s_pct:>5.1f}%{RESET}  resets in {s_c}{s_reset}{RESET}"
        )

    if data.get("creditsHasCredits"):
        if data.get("creditsUnlimited"):
            print(f"  {BOLD}Credits{RESET}    {DIM}unlimited{RESET}")
        else:
            bal = data.get("creditsBalance")
            if bal is not None:
                print(f"  {BOLD}Credits{RESET}    {DIM}{bal:>8.2f} remaining{RESET}")

    print()


# ── Main ──────────────────────────────────────────────────


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    no_cache = "--no-cache" in args or "--fresh" in args

    auth = read_auth()
    if not auth or not (auth.get("tokens") or {}).get("access_token"):
        print(
            "Error: No Codex credentials found at ~/.codex/auth.json.", file=sys.stderr
        )
        print(
            "Log in to Codex CLI first: run `codex` and complete login.",
            file=sys.stderr,
        )
        sys.exit(1)

    access_token = auth["tokens"]["access_token"]

    if is_token_expired(access_token):
        refresh_token = auth["tokens"].get("refresh_token")
        if not refresh_token:
            print(
                "Error: Codex access token expired and no refresh token available.",
                file=sys.stderr,
            )
            print("Re-login to Codex: run `codex`.", file=sys.stderr)
            sys.exit(1)
        refreshed = refresh_tokens(refresh_token)
        if not refreshed:
            print(
                "Error: Token refresh failed. Re-login to Codex: run `codex`.",
                file=sys.stderr,
            )
            sys.exit(1)
        auth["tokens"].update(refreshed)
        write_auth(auth, refreshed)
        access_token = refreshed["access_token"]

    token_prefix = access_token[:16]

    if not no_cache:
        cache = read_cache()
        if cache and is_cache_valid(cache, token_prefix):
            data = cache["data"]
            if as_json:
                print(json.dumps(data))
            else:
                format_limits(data)
            return

    headers = fetch_headers(auth)
    if not headers:
        cache = read_cache()
        if cache and cache.get("data"):
            sys.stderr.write("[stale] ")
            data = cache["data"]
            if as_json:
                print(json.dumps(data))
            else:
                format_limits(data)
            return
        print(
            "Error: Could not reach Codex API or parse rate-limit headers.",
            file=sys.stderr,
        )
        print(
            "The endpoint returned no x-codex-* headers. Try again in a moment.",
            file=sys.stderr,
        )
        sys.exit(1)

    data = parse_usage(headers, auth)
    write_cache(data, token_prefix)

    if as_json:
        print(json.dumps(data))
    else:
        format_limits(data)


if __name__ == "__main__":
    main()
