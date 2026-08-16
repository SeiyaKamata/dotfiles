# Feature (.specs/<feature>) Aliases
# prefix: tf

# .specs 配下のディレクトリ一覧を fzf で選ばせる
select_feature() {
  ls .specs | sort | fzf --prompt="feature> "
}

# TARGET_FEATURE をこのセッションに export する。
# herdr の ctrl+s（.specs を開くポップアップ）は別プロセスなのでこの env を見られない。
# .specs は worktree 間で symlink 共有されているため、そこに書くと worktree 間で
# 値を奪い合う。そのため repo ルート直下の .target_feature（git ignore 済み、
# worktree ごとに別ファイル）に書き出し、herdr 側はそのファイルを読む。
tf() {
  local feature
  feature=$(select_feature)
  [ -n "$feature" ] || return 1

  echo "$feature" > .target_feature
  echo "TARGET_FEATURE=$feature"
}

# TARGET_FEATURE の選択を解除する
tfc() {
  unset TARGET_FEATURE
  rm -f .target_feature
}
