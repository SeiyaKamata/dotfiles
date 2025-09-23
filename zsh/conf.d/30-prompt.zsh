setopt PROMPT_SUBST

function parse_git_branch () {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

# ユーザー@ホスト
local user_host=""

if [[ "$USER@$HOST" != "kmt2000200@SeiyaKamatanoMacBook-Pro.local" ]]; then
  user_host='%F{green}%n@%m%f:'
fi

# カレントディレクトリ
local cwd='%F{cyan}%~%f'

# Git ブランチ（関数 parse_git_branch を使う前提）
local git_branch='%F{red}$(parse_git_branch)%f'

# 実際の PROMPT を組み立て
PROMPT="${user_host}${cwd} ${git_branch}"$'\n'"$ "

