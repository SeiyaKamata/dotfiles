# herdr 連携用エイリアス

_notify_resolve_target() {
  if [ "${HERDR_ENV:-}" != 1 ]; then
    echo "Notify: herdr 管理下のペインでのみ通知できます" >&2
    return 1
  fi

  local arg="${1:-}"

  if [[ "$arg" == *:p* ]]; then
    echo "$arg"
    return 0
  fi

  local tab_id=""
  if [ -n "$arg" ]; then
    tab_id=$(herdr tab list | jq -r --arg ws "$HERDR_WORKSPACE_ID" --arg label "$arg" \
      '[.result.tabs[] | select(.workspace_id == $ws and .label == $label)][0].tab_id // empty') || return 1
    if [ -z "$tab_id" ]; then
      echo "Notify: 同じ space に label が $arg の tab が見つかりません" >&2
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
    echo "Notify: 送り先の claude agent が見つかりません" >&2
    return 1
  elif [ "$count" -gt 1 ]; then
    echo "Notify: claude agent が複数見つかりました。-t で tab の label か pane_id を指定してください:" >&2
    echo "$targets" >&2
    return 1
  fi

  echo "$targets"
}

# コマンドを実行し、完了または失敗を claude agent に送る。
# 出力は画面に流しつつログファイルへ残し、失敗時はそのパスを claude に伝える。
# -t で送り先を指定できる。
#   - pane_id: ":p" を含む値はそのまま送り先にする
#   - tab の label: 同じ herdr space のその tab にいる claude agent に送る
#   - 省略: 同じ herdr space の claude agent を自動判定する
# 複合コマンドは sh -c に渡す。
# 例: Notify npm install
# 例: Notify -t review npm install
# 例: Notify sh -c 'npm install && npm test'
Notify() {
  local target_arg=""
  if [ "${1:-}" = -t ]; then
    if [ $# -lt 3 ]; then
      echo "Notify: -t には送り先とコマンドが必要です" >&2
      return 2
    fi
    target_arg="$2"
    shift 2
  fi

  if [ $# -eq 0 ]; then
    echo "Notify: 実行するコマンドを指定してください" >&2
    return 2
  fi

  local log
  log=$(mktemp "${TMPDIR:-/tmp}/notify.XXXXXX") || return 1

  "$@" 2>&1 | tee "$log"
  local rc=${pipestatus[1]}

  local cmdline="${(j: :)${(q-)@}}"

  local message
  if [ "$rc" -eq 0 ]; then
    message="「${cmdline}」の実行が完了しました"
    rm -f "$log"
  else
    message="「${cmdline}」の実行が失敗しました。終了コードは ${rc} です。出力は ${log} に保存しています"
  fi

  local target
  if target=$(_notify_resolve_target "$target_arg"); then
    herdr agent prompt "$target" "$message" >/dev/null
  fi

  return "$rc"
}
