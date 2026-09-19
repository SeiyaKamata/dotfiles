#!/usr/bin/env bash
set -uo pipefail

input=$(cat)
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

exchange=$(tail -n 200 "$transcript_path" | jq -r '
  select(.message.role=="user" or .message.role=="assistant")
  | (.message.content
     | if type=="array" then map(select(.type=="text") | .text) | join("\n") else . end) as $t
  | select($t != null and $t != "")
  | "\(.message.role): \($t)"
' 2>/dev/null | tail -n 6)

[ -n "$exchange" ] || exit 0

prompt="以下は会話の直近のやり取りです。NIKKIに該当するものがあるか判定してください。

NIKKI判定基準
主語が常にユーザー自身であること。
ユーザーの内省・思考パターン・行動の癖・感情の動きの気づき、またはユーザー自身が新しく得た知識・理解・学びが対象。

該当すれば日本語要約だけを1行で出力してください。
該当しなければ NONE とだけ出力してください。

---
$exchange"

result=$(claude -p "$prompt" --model claude-haiku-4-5 --effort low 2>/dev/null < /dev/null)

if [ -n "$result" ] && [ "$result" != "NONE" ]; then
  nikki -n "$result" >/dev/null 2>&1
fi

exit 0
