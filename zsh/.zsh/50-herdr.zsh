# herdr: cd するたびに space ラベルを今いるプロジェクトの略称へ更新する。
# ペイン内シェルには HERDR_ENV=1 / HERDR_WORKSPACE_ID が入っている。
# 実体は herdr プラグイン workspace-alias の alias.py（略称表は lrm-corp/CLAUDE.md）。

if [[ "$HERDR_ENV" == "1" && -n "$HERDR_WORKSPACE_ID" ]]; then
  __herdr_alias_py="$HOME/Develop/kamata/repos/dotfiles/herdr/.config/herdr/plugins/workspace-alias/alias.py"

  __herdr_update_label() {
    [[ -f "$__herdr_alias_py" ]] || return
    # cd を止めないようバックグラウンドで実行
    (python3 "$__herdr_alias_py" --cwd "$PWD" &) >/dev/null 2>&1
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd __herdr_update_label
fi
