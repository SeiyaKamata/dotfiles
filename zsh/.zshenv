export EDITOR=nvim

export LANG=en_US.UTF-8

# zsh
export SHELL_SESSIONS_DISABLE=1

# Playwright MCP をヘッドレス起動（管理版は --headless 未指定のため env で上書き）
export PLAYWRIGHT_MCP_HEADLESS=true

# zoxide doctor の誤検知を抑止（設定を分割ロードしており末尾判定が効かないため）。
# Claude Code は Bash 呼び出しごとにシェルを立て直すので、非対話でも読まれる .zshenv に置く。
export _ZO_DOCTOR=0


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
