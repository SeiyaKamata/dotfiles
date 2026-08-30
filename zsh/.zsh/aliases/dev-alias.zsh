# Feature (.specs/<feature>) Aliases
# prefix: tf
#
# 対象 feature を repo ルート直下の .target_feature に書き出す。git ignore 済みで
# worktree ごとに別ファイル。herdr の ctrl+s ポップアップは別プロセスだがこのファイルは
# 読めるし、.specs は worktree 間で symlink 共有されるためファイル側が唯一の受け渡し口になる。

# 現在の対象 feature。未設定なら空。
_tf_current() { [ -f .target_feature ] && cat .target_feature; }

_tf_pick() {
  ls -1 .specs 2>/dev/null | fzf --prompt="feature> " \
    --preview 'glow -s dark .specs/{}/requirements.md 2>/dev/null || ls .specs/{}' \
    --preview-window=right,60%
}

# 引数があればそれを設定。無ければ fzf。無くて設定済みなら現在値を表示。
tf() {
  local feature="${1:-$(_tf_pick)}"
  if [ -z "$feature" ]; then
    local cur; cur=$(_tf_current)
    [ -n "$cur" ] && echo "target: $cur (変更なし)" || echo "対象 feature 未設定"
    return
  fi
  [ -d ".specs/$feature" ] || { echo ".specs/$feature がありません" >&2; return 1; }
  echo "$feature" > .target_feature
  echo "target: $feature"
}

# 対象 feature の選択を解除する
tfc() { rm -f .target_feature; }

# 引数 > 対象 feature > .specs 全体
tfs() {
  local f="${1:-$(_tf_current)}"
  [ -n "$f" ] && glow -t ".specs/$f" || glow -t .specs
}
