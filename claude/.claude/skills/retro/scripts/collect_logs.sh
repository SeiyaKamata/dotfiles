#!/usr/bin/env bash
# collect_logs.sh - 指定日のClaude Codeセッションログを全プロジェクトから収集する
# 使い方: bash collect_logs.sh [--skill-dir DIR] [YYYY-MM-DD]

# globstar は bash 4+ のみ。利用できなければ find にフォールバック
shopt -s globstar nullglob 2>/dev/null || USE_FIND=true

TARGET_DATE=""
SKILL_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)
      if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
        echo "ERROR: --skill-dir requires a value" >&2
        exit 1
      fi
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

if [[ "${USE_FIND:-}" == "true" ]]; then
  mapfile -t JSONL_FILES < <(find "$CLAUDE_PROJECTS" -name '*.jsonl' -type f 2>/dev/null)
else
  JSONL_FILES=("${CLAUDE_PROJECTS}"/**/*.jsonl)
fi

for jsonl_file in "${JSONL_FILES[@]}"; do
  [[ -f "$jsonl_file" ]] || continue

  # ファイルの最終更新日が対象日でなければスキップ
  file_date=$(date -r "$jsonl_file" +%Y-%m-%d 2>/dev/null || stat -c %y "$jsonl_file" 2>/dev/null | cut -d' ' -f1)
  [[ "$file_date" == "$TARGET_DATE" ]] || continue

  # subagents のログはメインセッションと重複するためスキップ
  parent_dir=$(basename "$(dirname "$jsonl_file")")
  if [[ "$parent_dir" == *"subagent"* ]]; then
    continue
  fi

  project_name=$(echo "$parent_dir" \
    | sed 's/^-//' \
    | sed 's/-/\//g')

  MESSAGES=$(jq -r --arg date "$TARGET_DATE" '
    # 新形式: .type == "user"/"assistant", タイムスタンプなし
    # 旧形式: .message.role == "user"/"assistant", .timestamp あり
    (
      if .type == "user" or .type == "assistant" then
        { role: .type, content: .message.content }
      elif (.message.role // "") != "" then
        if ($date == "" or ((.timestamp // "") | startswith($date))) then
          { role: .message.role, content: .message.content }
        else empty end
      else empty end
    ) |
    # user: 全テキスト, assistant: テキスト応答のみ（tool_use除外）
    select(.role == "user" or .role == "assistant") |
    (
      if (.content | type) == "string" then
        { role: .role, text: .content }
      elif (.content | type) == "array" then
        { role: .role, text: ([.content[] | select(.type == "text") | .text] | join(" ")) }
      else empty end
    ) |
    select(.text | length > 0) |
    # スキルプロンプト・システムリマインダー・コマンド出力などのノイズを除外
    select(.text | (
      startswith("Base directory for this skill:") or
      startswith("<system-reminder>") or
      startswith("<local-command-caveat>") or
      startswith("<command-name>") or
      startswith("<command-message>") or
      test("^<bash-(input|stdout|stderr)>") or
      test("^<persisted-output>")
    ) | not) |
    if .role == "assistant" then "  > \(.text)"
    else .text end
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
