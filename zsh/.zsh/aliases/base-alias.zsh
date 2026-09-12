# クリップボードコマンドはmacOS/Linuxで名前が違うため、入っている方を使う
if command -v pbpaste >/dev/null 2>&1; then
  alias exe="pbpaste | ./a.out"
  alias clip="pbcopy"
elif command -v xclip >/dev/null 2>&1; then
  alias exe="xclip -selection clipboard -o | ./a.out"
  alias clip="xclip -selection clipboard"
elif command -v wl-paste >/dev/null 2>&1; then
  alias exe="wl-paste | ./a.out"
  alias clip="wl-copy"
fi
alias vi="nvim"
alias vim="nvim"
alias q="exit"
alias cl="clear"

# Rust command
alias ps='procs'
alias cat='bat'
alias du='dust'
alias find='fd'
alias df='duf'
alias top='btm'
alias grep='rg'



alias ls='eza'
alias lsl='eza -al'
alias lss="eza .specs"
