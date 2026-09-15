# Feature (.specs/<feature>) Aliases
# prefix: tf
#
# 対象 feature を repo ルート直下の .target_feature に書き出す。git ignore 済みで
# worktree ごとに別ファイル。herdr の ctrl+s ポップアップは別プロセスだがこのファイルは
# 読めるし、.specs は worktree 間で symlink 共有されるためファイル側が唯一の受け渡し口になる。

# 現在の対象 feature。未設定なら空。
_tf_current() { [ -f .target_feature ] && cat .target_feature; }

vis() {
  local cur; cur=$(_tf_current)
  local target=".specs"
  [ -n "$cur" ] && target=".specs/$cur"
  vim -c "NvimTreeOpen $target"
}

# 引数を渡せばそのままDiffviewOpenに渡す。無ければ作業ツリーの差分を開く。
vdiff() {
  vim -c "DiffviewOpen $*"
}

# 現在のブランチのコミット一覧を、デフォルトブランチからの分だけコミットごとに開く
vlog() {
  local default=""
  if git remote get-url origin >/dev/null 2>&1; then
    default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    if [ -z "$default" ]; then
      git remote set-head origin --auto >/dev/null 2>&1
      default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
    fi
  fi
  if [ -z "$default" ]; then
    if git show-ref --verify --quiet refs/heads/main; then
      default=main
    elif git show-ref --verify --quiet refs/heads/master; then
      default=master
    fi
  fi
  if [ -z "$default" ]; then
    echo "デフォルトブランチを解決できませんでした" >&2
    return 1
  fi
  vim -c "DiffviewFileHistory --range=${default}...HEAD --right-only --no-merges"
}

# 対象 feature の選択を解除する
tfc() { rm -f .target_feature; }
