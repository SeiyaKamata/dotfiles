# Environment variables
set -gx LOCAL_BIN $HOME/.bin
fish_add_path $LOCAL_BIN
set -gx CONFIG_DIR $HOME/config
set -gx XDG_CONFIG_HOME $CONFIG_DIR

set -gx LANG ja_JP.UTF-8
