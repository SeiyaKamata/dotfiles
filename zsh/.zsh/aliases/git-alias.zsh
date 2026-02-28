# Git Aliases
# prefix: g

# Add alias (ga)
alias ga="git add"
alias gaa="git add ."

# Status alias (gb)
alias gb="git-branch-name-show-and-copy"

# Commit aliases (gc)
alias gc="git commit"
alias gcm="git-commit-with-message"
alias gca="git commit --amend --noedit"

# Checkout aliases (gco)
alias gco="git checkout"
alias gcob="git checkout -b"
alias gcod="git checkout develop"

# Cherry-pick alias (gcp)
alias gcp="git cherry-pick"

# Diff aliases (gd)
alias gd="git diff"
alias gds="git diff --staged"

# Log aliases (gl)
alias gl="git log -n 100 --oneline --color=always --decorate | nl -ba | less -R"
alias glg="git log --oneline --graph"

# Push aliases (gP)
alias gP="git push origin HEAD"
alias gPf="git push -f origin HEAD"

# Pull aliases (gp)
alias pg="git pull"
alias gpd="git pull origin develop"

# Rebase aliases (gr)
alias grb="git rebase"
alias grbi="git rebase -i"
alias grba="git rebase --abort"
alias grbc="git rebase --continue"

# Reset alias (grs)
alias grs="git reset HEAD^"
alias grsh="git reset --hard HEAD^"

# Revert alias (grv)
alias grv="git revert"
alias grvh="git revert HEAD"

# Stash aliases (gst)
alias gst="git stash"
alias gsta="git stash apply"
alias gstp="git stash pop"

# Status aliases (gs)
alias gs="git status -s"
alias gss="git status"
