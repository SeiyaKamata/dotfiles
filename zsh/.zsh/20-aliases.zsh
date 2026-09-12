# Claude Code のセッションでは標準コマンド上書きの影響を避けるためエイリアスを読み込まない。
[[ -n "$CLAUDECODE" ]] && return

for config_file in $HOME/.zsh/aliases/*.zsh; do
  source $config_file
done
