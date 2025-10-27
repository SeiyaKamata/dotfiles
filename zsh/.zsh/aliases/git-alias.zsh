# Git Aliases
# prefix: g

# Add alias (ga)
alias ga="git add"
alias gaa="git add ."

# Status alias (gb)
alias gb="git_branch_name_show_and_copy" # uses function from git-function.zsh

# Commit aliases (gc)
alias gc="git commit"
alias gcm="git_commit_with_message" # uses function from git-function.zsh
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
alias gl="git log --oneline"
alias glg="git log --oneline --graph"

# Push aliases (gph)
alias gp="git push origin HEAD"
alias gpf="git push -f origin HEAD"

# Pull aliases (gpl)
alias gpl="git pull origin develop"

# Rebase aliases (gr)
alias grb="git rebase"
alias grbi="git rebase -i"

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