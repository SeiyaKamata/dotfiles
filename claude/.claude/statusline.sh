#!/usr/bin/env python3
import json, subprocess, sys, time


def parse_pct(val):
    try:
        return int(float(val))
    except (TypeError, ValueError):
        return 0

def make_bar(pct, length=10):
    filled = max(0, min(round(pct / 100 * length), length))
    return "▓" * filled + "░" * (length - filled)

GREEN  = "\033[32m"
YELLOW = "\033[33m"
RED    = "\033[31m"
CYAN   = "\033[36m"
GRAY   = "\033[90m"
RESET  = "\033[0m"

try:
    data = json.load(sys.stdin)
except: data = {}

model = data.get("model", {}).get("display_name", "Claude")

# context_window の直下に used_percentage がある
ctx = data.get("context_window") or {}
pct = parse_pct(ctx.get("used_percentage"))

# rate_limits
rate = (data.get("rate_limits") or {}).get("five_hour") or {}
rate_pct = parse_pct(rate.get("used_percentage"))
resets_at = rate.get("resets_at")

bar_color = GREEN if pct < 70 else (YELLOW if pct < 90 else RED)
bar = make_bar(pct)

# レートリセット残り時間
if resets_at:
    remaining = max(0, int(resets_at) - int(time.time()))
    h, m = divmod(remaining // 60, 60)
    reset_str = f" ({h}h{m:02d}m)" if h else f" ({remaining // 60}m)"
else:
    reset_str = ""

# 5時間レート表示
rate_color = GREEN if rate_pct < 50 else (YELLOW if rate_pct < 80 else RED)
rate_msg = f"{rate_color}rate {rate_pct}%{reset_str}{RESET}"

print(f"{model} | {bar_color}{bar}{RESET} {pct}% | {rate_msg}")
