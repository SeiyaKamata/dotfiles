HOSTNAME := $(shell hostname -s)
USERNAME := $(shell whoami)
UNAME    := $(shell uname -s)

.PHONY: \
	setup \
	nix-install \
	nix-upgrade \
	nix-update \
	stow-install \
	brew-install \
	brew-dump \
	reload-zsh \
	reload-sheldon \
	clean-ds-store \
	claude \
	help

help:
	@grep -E '^[a-zA-Z_-]+:' Makefile | grep -v '^\s' | sed 's/:.*//' | sort | column

DOTFILES_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

STOW_PACKAGES_COMMON := zsh git vim sheldon starship yazi claude herdr
STOW_PACKAGES_MAC    := alacritty
ifeq ($(UNAME), Darwin)
  STOW_PACKAGES := $(STOW_PACKAGES_COMMON) $(STOW_PACKAGES_MAC)
else
  STOW_PACKAGES := $(STOW_PACKAGES_COMMON)
endif

define log
	@printf "[%s] %s\n" "$@" "$(1)"
endef

# ===== setup =====
setup: brew-install nix-install stow-install
	$(call log,Done)


# ===== nix =====
nix-install:
	$(call log,Installing Nix packages)
	@nix profile install .#
	$(call log,Done)

nix-upgrade:
	$(call log,Applying local flake.nix changes)
	@nix profile upgrade dotfiles
	$(call log,Done)

nix-update:
	$(call log,Updating Nix packages)
	@nix flake update
	@nix profile upgrade '.*'
	$(call log,Done)


# ===== stow =====
stow-install:
	$(call log,Linking dotfiles with stow)
	@stow -d $(DOTFILES_DIR) -t $(HOME) --restow $(STOW_PACKAGES)
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

reload-sheldon:
	$(call log,Reloading config)
	@sheldon lock
	$(call log,Done)


# ===== utils =====
clean-ds-store:
	$(call log,Removing .DS_Store files)
	@find . -type f -name '.DS_Store' -delete
	$(call log,Done)

