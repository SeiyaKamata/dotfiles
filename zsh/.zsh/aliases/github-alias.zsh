# GIthub Aliases
# prefix: gh

alias ghs='gh pr status'
alias ghv='gh pr view --web'
alias ghw='gh pr checks --watch --fail-fast'
alias ghr='gh pr ready'
alias gha='gh pr edit --add-assignee @me'

# レビュー
# PR / ブランチをチェックアウトせず hunk で開く。カレントブランチも HEAD も動かさない。
# hunk の中で commit-stepper（ctrl+n / ctrl+p）を使うとコミット単位で歩ける。
#   ghh 123          PR 番号
#   ghh feature/foo  ブランチ名
ghh() {
  local ref="$1" base tip
  [ -n "$ref" ] || { echo "usage: ghh <pr-number|branch>" >&2; return 1; }

  if [[ "$ref" == <-> ]]; then
    git fetch --quiet origin "pull/$ref/head" || return 1
    base="origin/$(gh pr view "$ref" --json baseRefName --jq .baseRefName 2>/dev/null || echo main)"
  else
    git fetch --quiet origin "$ref" || return 1
    base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  fi

  tip=$(git rev-parse FETCH_HEAD) || return 1
  hunk diff "$base...$tip"
}

alias ghrv='gh pr review'                    # エディタでレビュー本文を書く
alias ghrva='gh pr review --approve'
alias ghrvc='gh pr review --comment'
alias ghrvr='gh pr review --request-changes'

# Open（PR作成）
alias gho='gh pr create --web'    # ブラウザでPR作成画面を開く
alias ghoc='gh pr create --fill'  # コミットログから自動入力してターミナル完結

# Merge
alias ghm='gh pr merge --merge --delete-branch'   # デフォルト
alias ghms='gh pr merge --squash --delete-branch' # squashしたい時だけ

# PR一覧
alias ghlr='gh pr list --search "review-requested:@me"' # 自分がレビュアー
alias ghlo='gh pr list --author @me'                     # 自分がowner

alias ghprn='gh pr view --json number --jq .number'

# CodeRabbit
# sync-to-remote が本文に埋め込む `@coderabbitai ignore` は自動レビューだけを止めるため、
# コメントで明示的にレビューを頼めばそのつど実行される。セルフレビュー後にカレントブランチの PR で叩く。
alias ghcr='gh pr comment --body "@coderabbitai review"'
