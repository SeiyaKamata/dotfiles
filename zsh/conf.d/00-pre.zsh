# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && \
  builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# The following lines have been added by Homebrew to your PATH.
if command -v brew >/dev/null 2>&1; then
  eval "$($(command -v brew) shellenv)"
fi

# Load Sheldon plugins
eval "$(sheldon source)"