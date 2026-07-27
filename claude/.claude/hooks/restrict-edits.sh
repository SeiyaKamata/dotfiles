#!/usr/bin/env bash
# PreToolUse hook: プロジェクトディレクトリ外へのファイル書き込みをブロック
#
# Edit/Write/MultiEdit だけでなく Bash も同じ判定に通す。Edit がブロックされた後に
# `cat > 外部パス` で書き込んでガードを迂回する事故を防ぐため。
# インタプリタ経由（python -c 等）の書き込みは検出できない。

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

PROJECT_DIR=$(realpath "$PWD" 2>/dev/null || echo "$PWD")

# プロジェクト外への書き込みなら 0（ブロック）、許可なら 1 を返す
is_denied() {
  local file_path="$1"

  if [[ -z "$file_path" ]]; then
    return 1
  fi

  # チルダ展開
  file_path="${file_path/#\~/$HOME}"

  # 絶対パスに変換
  if [[ "$file_path" != /* ]]; then
    file_path="$PWD/$file_path"
  fi

  # パスを正規化（realpath できない場合はそのまま）
  local abs_path
  abs_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")

  # 他リポジトリの .specs/ 配下への書き込みは許可（PJ間連携用）
  if [[ "$abs_path" == */.specs || "$abs_path" == */.specs/* ]]; then
    return 1
  fi

  # CLAUDE.md への書き込みは許可（グローバル/各プロジェクト問わず）
  if [[ "$(basename "$abs_path")" == "CLAUDE.md" ]]; then
    return 1
  fi

  # memory ディレクトリ配下への書き込みは許可（MEMORY.md・各メモリファイル）
  if [[ "$abs_path" == */.claude/projects/*/memory || "$abs_path" == */.claude/projects/*/memory/* ]]; then
    return 1
  fi

  # セッション用スクラッチパッドへの書き込みは許可（claude の一時ディレクトリ配下）
  if [[ "$abs_path" == */claude-*/*/scratchpad || "$abs_path" == */claude-*/*/scratchpad/* ]]; then
    return 1
  fi

  if [[ "$abs_path" != "$PROJECT_DIR"/* && "$abs_path" != "$PROJECT_DIR" ]]; then
    return 0
  fi
  return 1
}

# Bash コマンドから書き込み先とみられるパスを列挙する
extract_write_targets() {
  local cmd="$1"
  {
    # リダイレクト先（`2>&1` `>&2` は & 始まりなのでマッチしない）
    grep -oE '>>?[[:space:]]*[^[:space:]<>|;&()]+' <<<"$cmd" | sed -E 's/^>>?[[:space:]]*//'

    # tee [-a ...] <path>
    grep -oE '\btee\b([[:space:]]+-[^[:space:]]+)*[[:space:]]+[^[:space:]|;&()]+' <<<"$cmd" | awk '{print $NF}'

    # sed -i / truncate は対象ファイルを直接書き換えるので、引数中のパスらしいトークンを全て見る
    if grep -qE '\bsed\b[^|;&]*[[:space:]]-i|\btruncate\b' <<<"$cmd"; then
      grep -oE '(~|\.{0,2}/)[^[:space:]|;&()]*' <<<"$cmd"
    fi

    # cp / mv / rsync / install の最終引数（＝コピー先）
    grep -oE '\b(cp|mv|rsync|install)\b[^|;&]*' <<<"$cmd" | awk '{print $NF}'

    # dd of=<path>
    grep -oE '\bof=[^[:space:]|;&()]+' <<<"$cmd" | sed -E 's/^of=//'
  } | sed -E 's/^["'"'"']+//; s/["'"'"']+$//' | grep -v '^/dev/' | sort -u
}

case "$TOOL" in
  Edit | Write | MultiEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    if is_denied "$FILE_PATH"; then
      echo "{\"decision\": \"block\", \"reason\": \"プロジェクトディレクトリ外のファイル編集はブロックされています。対象: $FILE_PATH\"}"
    fi
    ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      if is_denied "$target"; then
        echo "{\"decision\": \"block\", \"reason\": \"Bash 経由でもプロジェクトディレクトリ外への書き込みはブロックされています。対象: $target / ブロックは『止まって確認する』シグナルなので、別手段で書き込まずユーザーに確認すること。\"}"
        break
      fi
    done < <(extract_write_targets "$CMD")
    ;;
esac

exit 0
