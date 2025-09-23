## 基本
alias exe="pbpaste | ./a.out"
alias clip="pbcopy"
alias vim="nvim"
alias cdh="cd  ~/"
alias cdb='mkdir -p "$1" && cd "$1"'
# =================================================

gc() {
  git commit -m "$*"
}

## git関連
alias ga="git add ."
alias gca="git commit --amend --noedit"

alias gch="git checkout"
alias gchb="git checkout -b"

alias gp="git push origin HEAD"
alias gpf="git push -f origin HEAD"

alias gr="git rebase"
alias gri="git rebase -i"

alias gl="git log --oneline"
alias glg="git log --oneline --graph"
alias gcp="git cherry-pick"
# =================================================


## docker関連
alias dc="docker-compose"
alias dcu="docker-compose up -d"
# =================================================


## clang関連
alias g++20="g++ -std=c++20"
# =================================================


## python関連
alias mkvenv='python3 -m venv --upgrade-deps --prompt . .venv'
alias activate='source .venv/bin/activate'
alias pipf='pip3 freeze > requirements.txt'
alias pipi='pip3 install -r requirements.txt'
# =================================================


## その他
TEMP_DIR="$HOME/Developer/DailyChallenge/template"
alias cddc="cd $HOME/Developer/DailyChallenge/"
# =================================================