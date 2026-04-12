#!/usr/bin/env python3
import json, subprocess, sys, os

def get_git_branch():
    try:
        r = subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, timeout=2)
        return r.stdout.strip() if r.returncode == 0 else ""
    except: return ""

def is_git_repo():
    try:
        return subprocess.run(["git", "rev-parse", "--git-dir"], capture_output=True, timeout=2).returncode == 0
    except: return False

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

bar_color = GREEN if pct < 70 else (YELLOW if pct < 90 else RED)
bar = make_bar(pct)

git_part = ""
if is_git_repo():
    branch = get_git_branch()
    if branch:
        git_part = f" {CYAN}⎇ {branch}{RESET}"

# 5時間レート表示
rate_color = GREEN if rate_pct < 50 else (YELLOW if rate_pct < 80 else RED)
rate_msg = f"{rate_color}rate {rate_pct}%{RESET}"

print(f"{model}{git_part} | {bar_color}{bar}{RESET} {pct}% | {rate_msg}")
