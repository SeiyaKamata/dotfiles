devpick() {
  local sel
  sel=$(command find "$HOME"/Develop/*/repos "$HOME"/Develop/*/worktrees -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort \
    | awk -F/ '{print $NF "\t" $0}' \
    | fzf --prompt="space> " --delimiter='\t' --with-nth=1)
  [ -n "$sel" ] && print -r -- "${sel#*$'\t'}"
}
