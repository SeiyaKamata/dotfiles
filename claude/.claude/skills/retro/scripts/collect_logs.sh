#!/bin/bash
# collect_logs.sh - 指定日のClaude Codeセッションログを全プロジェクトから収集する
# 使い方: bash collect_logs.sh [--projects-dir DIR] [YYYY-MM-DD]

TARGET_DATE=""
SKILL_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)
      SKILL_DIR="$2"
      shift 2
      ;;
    *)
      TARGET_DATE="$1"
      shift
      ;;
  esac
done

TARGET_DATE="${TARGET_DATE:-$(date +%Y-%m-%d)}"

# skill-dir のパスから .claude-p か .claude かを判定する
if [[ "$SKILL_DIR" == *".claude-p"* ]]; then
  CLAUDE_PROJECTS="${HOME}/.claude-p/projects"
else
  CLAUDE_PROJECTS="${HOME}/.claude/projects"
fi

if [[ ! -d "$CLAUDE_PROJECTS" ]]; then
  echo "ERROR: ${CLAUDE_PROJECTS} が見つかりません" >&2
  exit 1
fi

FOUND=0

for jsonl_file in "${CLAUDE_PROJECTS}"/**/*.jsonl "${CLAUDE_PROJECTS}"/*/*.jsonl; do
  [[ -f "$jsonl_file" ]] || continue

  project_name=$(basename "$(dirname "$jsonl_file")" \
    | sed 's/^-//' \
    | sed 's/-/\//g')

  MESSAGES=$(jq -r --arg date "$TARGET_DATE" '
    select((.timestamp // "") | startswith($date)) |
    select(.message.role == "user") |
    (
      if (.message.content | type) == "string" then .message.content
      elif (.message.content | type) == "array" then
        [.message.content[] | select(.type == "text") | .text] | join(" ")
      else "" end
    ) | select(length > 0)
  ' "$jsonl_file" 2>/dev/null || true)

  if [[ -n "$MESSAGES" ]]; then
    echo "=== プロジェクト: ${project_name} ==="
    echo "$MESSAGES"
    echo ""
    FOUND=$((FOUND + 1))
  fi
done

if [[ $FOUND -eq 0 ]]; then
  echo "NO_LOGS_FOUND"
else
  echo "PROJECTS_FOUND: ${FOUND}" >&2
fi
