vis() {
  vim -c "NvimTreeOpen .specs"
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
