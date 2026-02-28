# コマンドのスペルチェック
setopt correct
unsetopt correct_all

# キーバインドをemacs風に
bindkey -v
bindkey -M viins 'jj' vi-cmd-mode

##### completion #####
mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit
compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump"

##### 補完 #####
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
