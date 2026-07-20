# GIthub Aliases
# prefix: gh

alias ghs='gh pr status'
alias ghv='gh pr view --web'
alias ghw='gh pr checks --watch --fail-fast'
alias ghr='gh pr ready'
alias gha='gh pr edit --add-assignee @me'

# レビュー
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
