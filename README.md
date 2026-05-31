# dotfiles

My dotfiles managed with Nix Home Manager.

## Prerequisites

### 1. Install Nix

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### 2. Install Homebrew

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
1. `brew bundle install` — Homebrew パッケージのインストール
2. `home-manager switch` — Nix Home Manager による環境構築

## Usage

### Nix 設定を反映する

```bash
make nix-switch
```

### Homebrew パッケージを更新する

```bash
# Brewfile から一括インストール
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
├── nix/
│   ├── hosts/
│   │   ├── mac/home.nix      # macOS プロファイル
│   │   └── linux/home.nix    # Linux プロファイル
│   └── modules/
│       ├── packages.nix      # home.packages
│       ├── shell.nix         # zsh, sheldon, starship, zoxide
│       ├── git.nix           # git, gh, delta
│       ├── editor.nix        # neovim
│       └── terminal.nix      # alacritty, tmux
├── homebrew/
│   └── .Brewfile             # Homebrew で管理するパッケージ
└── flake.nix
```
