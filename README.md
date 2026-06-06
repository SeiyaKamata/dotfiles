# dotfiles

My dotfiles managed with Nix + stow.

- **Nix** — パッケージ管理（mac/Linux 共通）
- **Homebrew** — macOS 向けパッケージ・GUI アプリ
- **stow** — dotfiles のシンボリックリンク管理

## Prerequisites

### 1. Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. Install Homebrew (macOS only)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Setup

```bash
git clone <YOUR_REPO_URL> ~/dotfiles
cd ~/dotfiles
make setup
```

`make setup` は以下を実行します：
1. `brew bundle install` — Homebrew パッケージのインストール（macOS のみ）
2. `nix profile install .#` — Nix パッケージのインストール
3. `stow` — dotfiles のシンボリックリンクを `~` に展開

## Usage

### Nix パッケージを更新する

```bash
# flake.lock を更新してパッケージを最新化
make nix-update
```

### dotfiles のリンクを張り直す

```bash
make stow-install
```

### Homebrew パッケージを更新する

```bash
# Brewfile からインストール
make brew-install

# 現在の状態を Brewfile に書き出す
make brew-dump
```

### 設定ファイルをリロードする

```bash
make reload-zsh
make reload-tmux
make reload-sheldon
```

## Structure

```
dotfiles/
├── flake.nix             # Nix パッケージ定義
├── flake.lock
├── homebrew/
│   └── .Brewfile         # Homebrew パッケージ
├── zsh/                  # zsh 設定
├── git/                  # git 設定 (.gitconfig)
├── vim/                  # Neovim 設定
├── tmux/                 # tmux 設定
├── alacritty/            # Alacritty 設定（macOS）
├── sheldon/              # sheldon プラグイン設定
├── starship/             # starship プロンプト設定
└── claude/               # Claude Code 設定
```
