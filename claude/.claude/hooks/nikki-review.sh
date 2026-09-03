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

prompt="以下は会話の直近のやり取りです。次の2つを判定してください。
1) ユーザー自身の内省・思考パターン・行動の癖・感情の動き・判断の癖の気づき、またはユーザーにとって新しい学び・知見が含まれるか（主語はユーザー自身）
2) Claude側が訂正・注意を受けた、またはフックや権限のブロックで往復が発生したなど、改善提案に値する摩擦が含まれるか（主語はClaude自身の不備）

1と2は別物なので混同しないこと。該当するものだけ、次の形式で出力してください（該当しなければ NONE とだけ出力）。
NIKKI: <40字以内の日本語要約>
FRICTION: <40字以内の日本語要約>
両方該当する場合は2行出力してよい。

---
$exchange"

result=$(claude -p "$prompt" --model claude-haiku-4-5 2>/dev/null < /dev/null)

printf '%s\n' "$result" | grep '^NIKKI:' | sed 's/^NIKKI: *//' | while IFS= read -r line; do
  [ -n "$line" ] && nikki -n "$line" >/dev/null 2>&1
done

printf '%s\n' "$result" | grep '^FRICTION:' | sed 's/^FRICTION: *//' | while IFS= read -r line; do
  [ -n "$line" ] && printf -- '- %s [%s]\n' "$line" "$(date '+%Y-%m-%d %H:%M')" >> "$HOME/.claude/friction-log.md"
done

exit 0
