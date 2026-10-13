# herdr 連携用エイリアス

# claude agent に「直前までのコマンドの実行が完了した」旨を送る。
# 第 1 引数で送り先を指定できる。
#   - pane_id: ":p" を含む値はそのまま送り先にする
#   - tab の label: 同じ herdr space のその tab にいる claude agent に送る
#   - 省略: 同じ herdr space の claude agent を自動判定する
# 例: npm install && Done
# 例: npm install && Done review
# 例: npm install && Done wA3:p1
Done() {
  if [ "${HERDR_ENV:-}" != 1 ]; then
    echo "Done: herdr 管理下のペインでのみ使えます" >&2
    return 1
  fi

  local arg="${1:-}"
  local target

  if [[ "$arg" == *:p* ]]; then
    target="$arg"
  else
    local tab_id=""
    if [ -n "$arg" ]; then
      tab_id=$(herdr tab list | jq -r --arg ws "$HERDR_WORKSPACE_ID" --arg label "$arg" \
        '[.result.tabs[] | select(.workspace_id == $ws and .label == $label)][0].tab_id // empty') || return 1
      if [ -z "$tab_id" ]; then
        echo "Done: 同じ space に label が $arg の tab が見つかりません" >&2
        return 1
      fi
    fi

    local agents
    agents=$(herdr agent list) || return 1

    local targets
    targets=$(echo "$agents" | jq -r --arg ws "$HERDR_WORKSPACE_ID" --arg pane "$HERDR_PANE_ID" --arg tab "$tab_id" \
      '.result.agents[] | select(.workspace_id == $ws and .agent == "claude" and .pane_id != $pane and ($tab == "" or .tab_id == $tab)) | (.name // .pane_id)')

    local count
    count=$(echo "$targets" | grep -c .)

    if [ "$count" -eq 0 ]; then
      echo "Done: 送り先の claude agent が見つかりません" >&2
      return 1
    elif [ "$count" -gt 1 ]; then
      echo "Done: claude agent が複数見つかりました。tab の label か pane_id を指定してください:" >&2
      echo "$targets" >&2
      return 1
    fi

    target="$targets"
  fi

  local cmd
  cmd="${history[$HISTCMD]}"
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  cmd="${cmd% && Done*}"

  local message="コマンドの実行が完了しました"
  if [ -n "$cmd" ]; then
    message="「${cmd}」の実行が完了しました"
  fi

  herdr agent prompt "$target" "$message" >/dev/null
}
