c() {
  CLAUDE_WORK_DIR="$CLAUDE_WORK_ROOT/$(date +%Y%m%d%H%M%S)" claude "$@"
}

cw() {
  local name
  name=$(ls -1t "$CLAUDE_WORK_ROOT" | fzf --prompt='work> ') || return
  CLAUDE_WORK_DIR="$CLAUDE_WORK_ROOT/$name" claude "$@"
}

alias ca="claude agents"
alias cr="claude --resume"
alias cc="claude --continue"
