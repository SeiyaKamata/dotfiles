alias c="claude"
alias ca="claude agents"
alias cr="claude --resume"
alias cc="caffeinate -is claude"

cs() {
  if [ ! -f .target_feature ]; then
    echo "cs: .target_feature が未設定です。先に tf で feature を選択してください" >&2
    return 1
  fi
  claude -p "/$1 $(cat .target_feature) $2"
}
