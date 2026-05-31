HOSTNAME := $(shell hostname -s)
USERNAME := $(shell whoami)
NIX_TARGET := $(USERNAME)@$(HOSTNAME)

.PHONY: \
	setup \
	nix-switch \
	brew-install \
	brew-dump \
	reload-zsh \
	reload-tmux \
	reload-sheldon \
	clean-ds-store \
	claude

DOTFILES_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CLAUDE_DIR   := $(DOTFILES_DIR)claude/.claude

define log
	@printf "[%s] %s\n" "$@" "$(1)"
endef

# ===== setup =====
setup: brew-install nix-switch
	$(call log,Done)


# ===== nix =====
nix-switch:
	$(call log,Applying Home Manager configuration for $(NIX_TARGET))
	@home-manager switch --flake .#"$(NIX_TARGET)"
	$(call log,Done)


# ===== homebrew =====
brew-install:
	$(call log,Installing Brewfile packages)
	@brew bundle install --file homebrew/.Brewfile
	$(call log,Done)

brew-dump:
	$(call log,Dumping Brewfile)
	@brew bundle dump --file homebrew/.Brewfile --force
	$(call log,Done)


# ===== apply setting file =====
reload-zsh: # このコマンドは検証用。makeで設定ファイルの再読み込みは不可
	$(call log,Reloading config ~/.zshrc)
	@zsh -lc 'source ~/.zshrc'
	$(call log,Done)

TMUX_CONF := $(HOME)/.config/tmux/tmux.conf
reload-tmux:
	$(call log,Reloading config $(TMUX_CONF))
	@tmux source-file $(TMUX_CONF)
	$(call log,Done)

reload-sheldon:
	$(call log,Reloading config)
	@sheldon lock
	$(call log,Done)


# ===== utils =====
clean-ds-store:
	$(call log,Removing .DS_Store files)
	@find . -type f -name '.DS_Store' -delete
	$(call log,Done)


claude:
	$(call log,Setting up)
	@stow --restow --target=$(HOME) claude
	 @find $(CLAUDE_DIR) -maxdepth 1 -mindepth 1 | while read f; do \
  	ln -sfn "$$f" $(HOME)/.claude-p/$$(basename "$$f"); \
  done
	$(call log,$(CLAUDE_DIR))
	$(call log,Done)
