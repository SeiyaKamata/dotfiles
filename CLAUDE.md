# dotfiles

個人の開発環境設定を管理するリポジトリ。

## ディレクトリ構成

| ディレクトリ | 内容 |
|---|---|
| `alacritty/` | Alacritty（ターミナルエミュレータ）設定 |
| `claude/` | Claude Code 設定（`.claude/settings.json` など） |
| `git/` | Git 設定 |
| `homebrew/` | Homebrew パッケージ管理 |
| `sheldon/` | sheldon（zsh プラグインマネージャ）設定 |
| `starship/` | Starship プロンプト設定 |
| `tmux/` | tmux 設定 |
| `vim/` | Neovim 設定 |
| `zsh/` | zsh 設定 |
| `flake.nix` | Nix/Home Manager 設定 |

## ブランチ運用

ブランチを切らず、`main` に直接コミットしてよい。


## ファイル編集の制限

Edit/Write/MultiEdit はプロジェクトディレクトリ外ではフックによりブロックされる。
**例外**: 他リポジトリへの PJ 間連携が必要な場合は、対象リポジトリの `.specs/` 配下にのみ書き込んでよい。要件・設計などの連携ドキュメントをそこにまとめること。
