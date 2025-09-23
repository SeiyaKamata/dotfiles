# Aliases

# Basic aliases
alias exe "pbpaste | ./a.out"
alias clip "pbcopy"
alias vim "nvim"
alias cdh "cd ~/"

# Git aliases
alias ga "git add ."
alias gca "git commit --amend --noedit"
alias gch "git checkout"
alias gchb "git checkout -b"
alias gp "git push origin HEAD"
alias gpf "git push -f origin HEAD"
alias gr "git rebase"
alias gri "git rebase -i"
alias gl "git log --oneline"
alias glg "git log --oneline --graph"
alias gcp "git cherry-pick"

# Docker aliases
alias dc "docker-compose"
alias dcu "docker-compose up -d"

# Clang aliases
alias g++20 "g++ -std=c++20"

# Python aliases
alias mkvenv "python3 -m venv --upgrade-deps --prompt . .venv"
alias activate "source .venv/bin/activate"
alias pipf "pip3 freeze > requirements.txt"
alias pipi "pip3 install -r requirements.txt"

# Other aliases
set -g TEMP_DIR "$HOME/Developer/DailyChallenge/template"
alias cddc "cd $HOME/Developer/DailyChallenge/"
