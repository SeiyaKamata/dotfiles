git_commit_with_message() {
  git commit -m "$*"
}

git_branch_name_show_and_copy() {
  git branch --contains | cut -d' ' -f2 | tr -d '\n'
  git branch --contains | cut -d' ' -f2 | tr -d '\n' | pbcopy
}

# ブランチを選択してチェックアウト
git_checkout_branch_fzf() {
  branch=$(git branch -a | sed 's/^[* ] //g' | fzf)
  [ -n "$branch" ] && git checkout $branch
}

# 過去のコミットを選んでチェックアウト
git_checkout_commit_fzf() {
  commit=$(git log --oneline | fzf | awk '{print $1}')
  [ -n "$commit" ] && git checkout $commit
}

# 過去のコミットからファイルを復元
git_checkout_file_fzf() {
  file=$(git ls-files | fzf)
  commit=$(git log --oneline | fzf | awk '{print $1}')
  [ -n "$file" ] && [ -n "$commit" ] && git checkout $commit -- $file
}