c() {
  CLAUDE_WORK_DIR="$CLAUDE_WORK_ROOT/$(date +%Y%m%d%H%M%S)" claude "$@"
}

cw() {
  local name dir
  if [[ -n "$1" && "$1" != -* ]]; then
    name="$1"
    shift
  elif command -v fzf >/dev/null; then
    name=$(ls -1t "$CLAUDE_WORK_ROOT" | fzf --prompt='work> ') || return
  else
    ls -1t "$CLAUDE_WORK_ROOT"
    return 1
  fi
  [[ "$name" == /* ]] && dir="$name" || dir="$CLAUDE_WORK_ROOT/$name"
  if [[ ! -d "$dir" ]]; then
    echo "cw: $dir がありません" >&2
    return 1
  fi
  CLAUDE_WORK_DIR="$dir" claude "$@"
}

alias ca="claude agents"
alias cr="claude --resume"
alias cc="claude --continue"
