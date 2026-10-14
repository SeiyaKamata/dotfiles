#!/usr/bin/env bash
set -uo pipefail

[ -n "${HERDR_WORKSPACE_ID:-}" ] || exit 0

input=$(cat)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

title=$(jq -r 'select(.type=="custom-title") | .customTitle // empty' "$transcript_path" 2>/dev/null | tail -n 1)
[ -n "$title" ] || exit 0

herdr workspace rename "$HERDR_WORKSPACE_ID" "$title" >/dev/null 2>&1
exit 0
