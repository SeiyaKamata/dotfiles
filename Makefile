STOW_TARGETS = \
	alacritty \
	codex \
	docker \
	gh \
	git \
	homebrew \
	lazydocker \
	lazygit \
	lazysql \
	sheldon \
	starship \
	tmux \
	vim \
	zsh

.PHONY: \
	setup \
	brew-install \
	brew-dump \
	reload-zsh \
	reload-tmux \
	reload-sheldon \
	clean-ds-store \
	stow-all \
	$(STOW_TARGETS)

define log
	@printf "[%s] %s\n" "$@" "$(1)"
endef

# ===== setup =====
setup: \
	brew-install \
	stow-all \
	reload-zsh \
	reload-tmux \
	reload-sheldon
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
reload-zsh: # このコマンドは、検証用でしかない、makeで設定ファイルの再読み込みは不可
	$(call log,Reloading config ~/.zshrc)
	@zsh -lc 'source ~/.zshrc'
	$(call log,Done)

reload-tmux:
	$(call log,Reloading config ~/.tmux.conf)
	@tmux source-file ~/.tmux.conf
	$(call log,Done)

reload-sheldon:
	$(call log,Reloading config)
	@sheldon lock
	$(call log,Done)


# ===== stow =====
clean-ds-store:
	$(call log,Removing .DS_Store files)
	@find . -type f -name '.DS_Store' -delete
	$(call log,Done)

stow-all: $(STOW_TARGETS)
	$(call log,All packages stowed)

$(STOW_TARGETS):
	$(call log,Setting up)
	@stow --restow $@
	$(call log,Done)
