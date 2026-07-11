#!/usr/bin/env bash
# PreToolUse hook: プロジェクトディレクトリ外のファイル編集をブロック

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

if [[ "$TOOL" != "Edit" && "$TOOL" != "Write" && "$TOOL" != "MultiEdit" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# チルダ展開
FILE_PATH="${FILE_PATH/#\~/$HOME}"

# 絶対パスに変換
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="$PWD/$FILE_PATH"
fi

PROJECT_DIR=$(realpath "$PWD" 2>/dev/null || echo "$PWD")

# パスを正規化（realpath できない場合はそのまま）
ABS_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# 他リポジトリの .specs/ 配下への書き込みは許可（PJ間連携用）
if [[ "$ABS_PATH" == */.specs || "$ABS_PATH" == */.specs/* ]]; then
  exit 0
fi

# CLAUDE.md への書き込みは許可（グローバル/各プロジェクト問わず）
if [[ "$(basename "$ABS_PATH")" == "CLAUDE.md" ]]; then
  exit 0
fi

# memory ディレクトリ配下への書き込みは許可（MEMORY.md・各メモリファイル）
if [[ "$ABS_PATH" == */.claude/projects/*/memory || "$ABS_PATH" == */.claude/projects/*/memory/* ]]; then
  exit 0
fi

if [[ "$ABS_PATH" != "$PROJECT_DIR"/* && "$ABS_PATH" != "$PROJECT_DIR" ]]; then
  echo "{\"decision\": \"block\", \"reason\": \"プロジェクトディレクトリ外のファイル編集はブロックされています。対象: $FILE_PATH\"}"
fi

exit 0
