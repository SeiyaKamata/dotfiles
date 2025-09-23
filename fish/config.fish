# Fish configuration file
# This file is the main configuration entry point for fish shell

# Source all configuration files in order
source $HOME/config/fish/conf.d/00-pre.fish
source $HOME/config/fish/conf.d/10-env.fish
source $HOME/config/fish/conf.d/20-options.fish
source $HOME/config/fish/conf.d/21-aliases.fish
source $HOME/config/fish/conf.d/22-history.fish
source $HOME/config/fish/conf.d/40-functions.fish
source $HOME/config/fish/conf.d/50-plugins.fish
source $HOME/config/fish/conf.d/99-post.fish

# Homebrew environment
eval (/opt/homebrew/bin/brew shellenv)
