#!/usr/bin/env python3
import json, os, subprocess, sys, time

CYAN = "\033[36m"
MAGENTA = "\033[35m"

R = "\033[0m"
DIM = "\033[2m"
BOLD = "\033[1m"


def parse_pct(val):
    try:
        return float(val)
    except (TypeError, ValueError):
        return None


def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f"\033[38;2;{r};200;80m"
    g = int(200 - (pct - 50) * 4)
    return f"\033[38;2;255;{max(g, 0)};60m"


def reset_str(resets_at):
    if not resets_at:
        return ""
    minutes = max(0, int(resets_at) - int(time.time())) // 60
    d, rem = divmod(minutes, 1440)
    h, m = divmod(rem, 60)
    units = [(d, "d"), (h, "h"), (m, "m")]
    shown = [f"{n}{u}" for n, u in units if n] or [f"{m}m"]
    return f" {DIM}{''.join(shown[:2])}{R}"


def fmt(label, pct, resets_at=None):
    return f"{DIM}{label}{R} {gradient(pct)}●{R} {round(pct)}%{reset_str(resets_at)}"


try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

model = data.get("model", {}).get("display_name", "Claude")
effort = (data.get("effort") or {}).get("level")
rate = data.get("rate_limits") or {}

cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or os.getcwd()
branch = subprocess.run(
    ["git", "-C", cwd, "branch", "--show-current"],
    capture_output=True, text=True,
).stdout.strip()

parts = [f"{CYAN}{os.path.basename(cwd)}{R}"]
if branch:
    parts.append(f"{MAGENTA}{branch}{R}")
parts.append(f"{BOLD}{model}{R}")
if effort:
    parts.append(f"{DIM}{effort}{R}")

for label, src in [
    ("ctx", data.get("context_window") or {}),
    ("5h", rate.get("five_hour") or {}),
    ("7d", rate.get("seven_day") or {}),
]:
    pct = parse_pct(src.get("used_percentage"))
    if pct is not None:
        parts.append(fmt(label, pct, src.get("resets_at")))

print(f" {DIM}|{R} ".join(parts))
