# herdr 連携用エイリアス

# 同じ herdr space で動いている claude agent に完了通知を送る。
# 例: npm install && Done
Done() {
  if [ "${HERDR_ENV:-}" != 1 ]; then
    echo "Done: herdr 管理下のペインでのみ使えます" >&2
    return 1
  fi

  local agents
  agents=$(herdr agent list) || return 1

  local targets
  targets=$(echo "$agents" | jq -r --arg ws "$HERDR_WORKSPACE_ID" --arg pane "$HERDR_PANE_ID" \
    '.result.agents[] | select(.workspace_id == $ws and .agent == "claude" and .pane_id != $pane) | (.name // .pane_id)')

  local count
  count=$(echo "$targets" | grep -c .)

  if [ "$count" -eq 0 ]; then
    echo "Done: 同じ space に claude agent が見つかりません" >&2
    return 1
  elif [ "$count" -gt 1 ]; then
    echo "Done: 同じ space に claude agent が複数見つかりました。特定できません:" >&2
    echo "$targets" >&2
    return 1
  fi

  herdr agent prompt "$targets" "done" >/dev/null
}
