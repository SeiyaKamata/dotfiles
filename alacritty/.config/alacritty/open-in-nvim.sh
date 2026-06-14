#!/usr/bin/env bash
set -euo pipefail
raw="${1:-}"; [ -z "$raw" ] && exit 0

path="${raw#file://}"
line=""
if [[ "$path" =~ ^(.+):([0-9]+)(:[0-9]+)?$ && -e "${BASH_REMATCH[1]}" ]]; then
  line="${BASH_REMATCH[2]}"; path="${BASH_REMATCH[1]}"
fi

pane=$(tmux list-panes -a -F '#{pane_id} #{pane_current_command}' 2>/dev/null \
        | awk '$2 ~ /^(nvim|vim|view)$/ {print $1; exit}')

if [ -z "$pane" ]; then
  alacritty -e nvim ${line:+"+$line"} "$path" &
  exit 0
fi

tmux send-keys -t "$pane" Escape
tmux send-keys -t "$pane" ":edit ${line:+"+$line "}$path" Enter
tmux select-pane -t "$pane"
