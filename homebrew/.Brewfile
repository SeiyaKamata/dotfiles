# Homebrew Brewfile
# macOS のパッケージ管理はすべて Homebrew に一元化する。

# ─── Taps ──────────────────────────────────────────────────────────────────

# Infisical公式tap（homebrew-coreに存在しないため）
tap "infisical/get-cli"

# im-select公式tap（homebrew-coreに存在しないため）
tap "daipeihust/tap"

# HashiCorp公式tap（terraformはライセンス変更でhomebrew-coreから削除されたため）
tap "hashicorp/tap"

# ─── Brews ─────────────────────────────────────────────────────────────────

# CLI
brew "tree-sitter"
brew "bat"
brew "bottom"
brew "eza"
brew "fd"
brew "fzf"
brew "jq"
brew "procs"
brew "stow"
brew "make"
brew "unzip"
brew "duf"

# Docker（Docker Desktopではなくcolimaをruntimeとして使うためCLIのみ）
brew "docker"
brew "docker-compose"
brew "docker-buildx"

# AWS
brew "awscli"
# awslogs はHomebrew未提供（pip製）。`pipx install awslogs` で導入する。

# ファイル処理
brew "imagemagick"
brew "nkf"
brew "fswatch"
# flock はHomebrewでの提供有無を要確認（macOS標準にはflock(1)が無い）。

# 言語ランタイム
# node は nvm 管理（NVM_DIR / 読み込みは zsh/.zshenv、LTS の導入は各自 `nvm install --lts`）
brew "nvm"
brew "uv"
brew "go"
brew "gcc"

# インフラ
brew "hashicorp/tap/terraform"

# データベース
brew "mycli"

# Go ツール
brew "golangci-lint"

# TUI
brew "yazi"
brew "glow"
brew "hunk"

# 検索・差分
brew "ripgrep"
brew "git-delta"

# Git
brew "git"
brew "gh"

# shell
brew "sheldon"
brew "starship"
brew "zoxide"

# Editor
brew "neovim"

# colima: Mac・Linux両環境でのDocker runtime安定性のため
brew "colima"

# pyenv: プロジェクトごとのPythonバージョン管理のため
brew "pyenv"

# rbenv-gemset: プロジェクトごとのgemセット管理のため
brew "rbenv-gemset"

# aws-sam-cli: 最新のAWS機能に追随するため
brew "aws-sam-cli"

# infisical: 公式tapから取得
brew "infisical/get-cli/infisical"

# im-select: macOS専用のIME切り替えツール（Neovim連携用）
brew "daipeihust/tap/im-select"

# ─── Casks ─────────────────────────────────────────────────────────────────

# Ghostty: ターミナルエミュレータ
cask "ghostty"
