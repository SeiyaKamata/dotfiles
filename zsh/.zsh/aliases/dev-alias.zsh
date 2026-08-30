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

# .target_feature が設定されていればそのディレクトリ、無ければ .specs を開く
vitf() {
  local feature
  if [ -f .target_feature ]; then
    feature=$(cat .target_feature)
    nvim ".specs/$feature"
  else
    nvim .specs
  fi
}

# .specs の Markdown を glow の TUI で表示する。
# .target_feature があればそのディレクトリ、無ければ .specs 全体。引数でも上書き可。
specs() {
  local target
  if [ -n "$1" ]; then
    target=".specs/$1"
  elif [ -f .target_feature ]; then
    target=".specs/$(cat .target_feature)"
  else
    target=".specs"
  fi
  glow -t "$target"
}
