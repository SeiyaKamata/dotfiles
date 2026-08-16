# Feature (.specs/<feature>) Aliases
# prefix: tf

# .specs 配下のディレクトリ一覧を fzf で選ばせる
select_feature() {
  find .specs -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | fzf --prompt="feature> "
}

# TARGET_FEATURE をこのセッションに export する。
# herdr の ctrl+s（.specs を開くポップアップ）は別プロセスなのでこの env を見られない。
# そのため .specs/.target-feature にも同じ値を書き出し、herdr 側はそのファイルを読む。
tf() {
  local feature
  feature=$(select_feature)
  [ -n "$feature" ] || return 1

  export TARGET_FEATURE="$feature"
  echo "$feature" > .specs/.target-feature
  echo "TARGET_FEATURE=$feature"
}

# TARGET_FEATURE の選択を解除する
tfc() {
  unset TARGET_FEATURE
  rm -f .specs/.target-feature
}

# TARGET_FEATURE が指定されていればそのディレクトリ、無ければ .specs を開く
vis() {
  if [ -n "$TARGET_FEATURE" ]; then
    nvim ".specs/$TARGET_FEATURE"
  else
    nvim .specs
  fi
}
