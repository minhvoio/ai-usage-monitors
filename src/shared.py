"""Shared rendering and time helpers for cu / cou monitors.

Kept small and stdlib-only so both monitors can import without deps.
"""

from datetime import datetime, timezone

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"
CYAN = "\033[36m"


def bar(pct, width=20):
    if pct is None:
        return DIM + "░" * width + RESET
    filled = round(min(100.0, max(0.0, pct)) / 100 * width)
    return GREEN + "█" * filled + DIM + "░" * (width - filled) + RESET


def pct_color(pct):
    if pct is None:
        return DIM
    if pct >= 90:
        return RED
    if pct >= 70:
        return YELLOW
    return GREEN


def time_until(unix_ts):
    if not unix_ts:
        return "?"
    try:
        now = datetime.now(timezone.utc).timestamp()
        diff_s = unix_ts - now
        if diff_s <= 0:
            return "reset now"
        minutes = int(diff_s // 60)
        h, m = divmod(minutes, 60)
        d = h // 24
        h = h % 24
        if d > 0:
            return f"{d}d{h}h"
        return f"{h}h{m:02d}m"
    except Exception:
        return "?"


def format_window(minutes):
    if minutes is None:
        return "?"
    if minutes < 60:
        return f"{minutes}m"
    if minutes < 1440:
        return f"{minutes // 60}h"
    return f"{minutes // 1440}d"


def clamp_pct(v):
    if v is None:
        return None
    return min(100.0, max(0.0, float(v)))
