# cdなしでディレクトリ移動
setopt auto_cd

# コマンドのスペルチェック
setopt correct

# キーバインドをEmacs風に
bindkey -e

# 補完機能関連
zstyle ':completion:*' menu select
if [ -e /usr/local/share/zsh-completions ]; then
  fpath=(/usr/local/share/zsh-completions $fpath)
fi

mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit
compinit -u
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

