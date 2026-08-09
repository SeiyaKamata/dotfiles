#!/usr/bin/env bash
# PreToolUse hook: Bash ツールでの cd をブロック
#
# Bash ツールの作業ディレクトリは呼び出し間で永続する。cd で cwd を持ち越すと
# permission prompt が増えるうえ、後続のコマンドが意図しないディレクトリで走る。
#
# サブシェル `(cd X && cmd)` も例外にしない。禁止したいのは cwd の持ち越しなのに
# 括弧の有無という別の軸で判定を分けることになり、穴が空くため。ディレクトリを
# 指定したいだけなら絶対パスか `-C` 相当のオプションで足りる。

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

[[ "$TOOL" == "Bash" ]] || exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# heredoc 本文とクォートで囲まれた文字列を落とす。コマンド文字列に混ざる「データ」を
# cd の実行として誤検出しないため（`grep "cd " file`、heredoc で書くスクリプト本文など）。
# heredoc 開始行は `<<` より前を残すので `cd /tmp << EOF` は取り逃さない。
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
  ' <<<"$1" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g"
}

# cd がコマンド位置（行頭・`;` `&&` `||` `|` `(` `{` の直後）に現れるか判定する。
# `cdk deploy` `echo abcd` `--grep=cd` のように語の一部・引数値であるものは拾わない。
if grep -qE '(^|[;&|(){}])[[:space:]]*cd([[:space:]]|;|$)' <<<"$(strip_data_sections "$CMD")"; then
  echo '{"decision": "block", "reason": "cd は禁止されています。Bash ツールの作業ディレクトリは呼び出し間で永続するため、cwd の持ち越しが後続のコマンドを意図しないディレクトリで走らせます。対象は絶対パスで指定するか、git -C / make -C / npm --prefix のようなディレクトリ指定オプションを使ってください。サブシェル (cd X && cmd) も例外なくブロックされます。ブロックは『止まって確認する』シグナルなので、別手段で同じ cd を試して迂回しないこと。"}'
fi

exit 0
