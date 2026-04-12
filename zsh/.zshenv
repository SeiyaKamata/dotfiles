export EDITOR=nvim

export LANG=en_US.UTF-8

# zsh
export SHELL_SESSIONS_DISABLE=1


# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# My Scripts
path=("$HOME/.local/bin" $path)

# workspace root
export WORKSPACE="$HOME/Develop/workspace"

mkdir -p "$WORKSPACE"

# Go
export GOPATH="$WORKSPACE/go"
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


source $HOME/.zshenv.local
