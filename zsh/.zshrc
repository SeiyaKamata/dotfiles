# source "$HOME/config/zsh/git-prompt.sh"
for config_file in $HOME/.config/zsh/conf.d/*.zsh; do
  source $config_file
done