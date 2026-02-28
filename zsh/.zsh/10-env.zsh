# workspace root
export WORKSPACE="$HOME/Develop/workspace"

# workspace 生成
[ ! -d "$WORKSPACE" ] && mkdir -p "$WORKSPACE"

# Go workspace (GOPATH)
export GOPATH="$WORKSPACE/go"

# Go tools PATH追加
export PATH="$GOPATH/bin:$PATH"

# nvm
export NVM_DIR="$WORKSPACE/nvm"

_nvm_load() {
  unset -f node npm npx nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}

# 初回実行時にだけロード
nvm()  { _nvm_load; nvm  "$@"; }
node() { _nvm_load; node "$@"; }
npm()  { _nvm_load; npm  "$@"; }
npx()  { _nvm_load; npx  "$@"; }
