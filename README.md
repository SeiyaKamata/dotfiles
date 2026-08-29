# dotfiles

My dotfiles managed with Homebrew (macOS) / apt (Linux) + stow.

- **Homebrew** — macOS のパッケージ管理・GUI アプリ
- **apt + 各ツール公式インストーラー** — Linux のパッケージ管理
- **stow** — dotfiles のシンボリックリンク管理

## Prerequisites

### 1. Install Homebrew (macOS only)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Linux は追加の前提インストールは不要（`apt` を使用）。

## Setup

```bash
git clone <YOUR_REPO_URL> ~/dotfiles
cd ~/dotfiles
make setup
```

`make setup` は以下を実行します：
1. macOS: `brew bundle install` — Homebrew パッケージのインストール
   Linux: `apt/apt-install.sh` + `apt/install-standalone-tools.sh` — apt パッケージ・公式インストーラー経由のツールのインストール
2. `stow` — dotfiles のシンボリックリンクを `~` に展開

## Usage

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
├── homebrew/
│   └── .Brewfile         # Homebrew パッケージ（macOS）
├── apt/
│   ├── apt-packages.txt             # apt パッケージ一覧（Linux）
│   ├── apt-install.sh               # 3rd-party repo 登録 + apt-packages.txt のインストール（Linux）
│   └── install-standalone-tools.sh  # apt に無いツールの公式インストーラー（Linux）
├── zsh/                  # zsh 設定
├── git/                  # git 設定 (.gitconfig)
├── vim/                  # Neovim 設定
├── tmux/                 # tmux 設定
├── alacritty/            # Alacritty 設定（macOS）
├── sheldon/              # sheldon プラグイン設定
├── starship/             # starship プロンプト設定
└── claude/               # Claude Code 設定
```
