#!/usr/bin/env bash
# PreToolUse hook: プロジェクトディレクトリ外へのファイル書き込みをブロック
#
# Edit/Write/MultiEdit だけでなく Bash も同じ判定に通す。Edit がブロックされた後に
# `cat > 外部パス` で書き込んでガードを迂回する事故を防ぐため。
# インタプリタ経由（python -c 等）の書き込みは検出できない。

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

PROJECT_DIR=$(realpath "$PWD" 2>/dev/null || echo "$PWD")

# `.` `..` を自前で畳む（realpath が使えない＝実在しないパス用）
normalize_path() {
  local seg segs out=()
  IFS='/' read -ra segs <<<"$1"
  for seg in "${segs[@]}"; do
    case "$seg" in
      '' | .) ;;
      ..) [[ ${#out[@]} -gt 0 ]] && unset "out[$((${#out[@]} - 1))]" ;;
      *) out+=("$seg") ;;
    esac
  done
  local IFS=/
  echo "/${out[*]}"
}

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

  # パスを正規化。realpath は実在しないパスで失敗するので、その場合は自前で畳む
  # （畳まないと `<project>/../other-repo/x` が project 内と誤判定されて素通りする）
  local abs_path
  abs_path=$(realpath "$file_path" 2>/dev/null) || abs_path=$(normalize_path "$file_path")

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

# heredoc 本文と `<...>` プレースホルダを落とす。
# コマンド文字列に混ざる「データ」を書き込み先として誤検出しないため
# （例: heredoc で書く本文中の `.specs/<feature>/review.md` は `>` + `/review.md` に見える）。
# heredoc 開始行は `<<` より前を残すので `cat > 外部パス << EOF` は取り逃さない。
strip_data_sections() {
  awk '
    BEGIN { q = sprintf("%c", 39); re = "<<-?[ \t]*" q "?\"?[A-Za-z_][A-Za-z0-9_]*" q "?\"?" }
    hd != "" {
      t = $0
      sub(/^[ \t]+/, "", t)
      sub(/[ \t]*;?[ \t]*$/, "", t)
      if (t == hd) { hd = "" }
      next
    }
    {
      line = $0
      if (match(line, re)) {
        tag = substr(line, RSTART, RLENGTH)
        sub(/^<<-?[ \t]*/, "", tag)
        gsub("[" q "\"]", "", tag)
        hd = tag
        line = substr(line, 1, RSTART - 1)
      }
      print line
    }
  ' <<<"$1" | sed -E 's/<[^<>]*>//g'
}

# Bash コマンドから書き込み先とみられるパスを列挙する
extract_write_targets() {
  local cmd
  cmd=$(strip_data_sections "$1")
  {
    # リダイレクト先（`2>&1` `>&2` は & 始まりなのでマッチしない）
    grep -oE '>>?[[:space:]]*[^[:space:]<>|;&()]+' <<<"$cmd" | sed -E 's/^>>?[[:space:]]*//'

    # tee [-a ...] <path>
    grep -oE '\btee\b([[:space:]]+-[^[:space:]]+)*[[:space:]]+[^[:space:]|;&()]+' <<<"$cmd" | awk '{print $NF}'

    # sed -i / truncate は対象ファイルを直接書き換えるので、引数中のパスらしいトークンを全て見る。
    # トークンの先頭（行頭・空白・クォート・`=` の直後）から拾う。途中の `/` から拾うと
    # `claude/.claude/x.md` が `/.claude/x.md` に化けて絶対パスと誤判定される。
    if grep -qE '\bsed\b[^|;&]*[[:space:]]-i|\btruncate\b' <<<"$cmd"; then
      grep -oE "(^|[[:space:]'\"=])(~|[A-Za-z0-9_.-]*/)[^[:space:]|;&()]*" <<<"$cmd" |
        sed -E "s/^[[:space:]'\"=]//"
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
