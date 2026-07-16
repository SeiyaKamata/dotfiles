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

## worktree を使った開発と Docker

各アプリリポジトリでは git worktree を使って複数ブランチを同時に作業できる。
Docker でアプリを動かすとき、コンテナへのコードのマウント先が **今いる worktree のパス** になっているかを必ず確認すること。

マウント先がずれている場合は `swws` コマンドで切り替える。

### swws コマンドについて

`~/.local/bin/swws` は、**現在いる git worktree を Docker のマウント先として docker compose を起動し直す**コマンド。
実行すると環境変数 `APP_DIR` に現在の worktree パスが自動でセットされ、`compose.yaml` がそこをマウント先として使う。

```
swws          # web コンテナを起動（デフォルト）
swws web      # 同上
swws worker   # worker コンテナを起動
swws worker-stop  # worker コンテナを停止
swws stop     # プロジェクトを全停止（＝そのプロジェクトを解放する）
swws status   # 今どの worktree がそのプロジェクトを使用中か表示（切り替えない）
```

対応リポジトリ: `Seculio` / `user-dashboard` / `elearning-service` / `training-email-next` / `automated-training-service` / `cross-company-management`

### 並列開発と使用中チェック（重要）

compose プロジェクトは 1 リポジトリ 1 つしかないため、ある worktree で `swws` を up すると **他の worktree で稼働中の同プロジェクトを黙って奪ってしまう**。別セッションが別 worktree で作業中だと事故になる。

- **状態は Docker の稼働中コンテナが唯一の真実**。`swws status` は稼働中コンテナの `com.docker.compose.project.working_dir` ラベルから「今どの worktree がマウントされているか」を判定する。**起動＝占有 / 停止＝解放**（停止済みは解放とみなす）。
- swws の up 系コマンドには **別 worktree が使用中なら中断するガード**が入っている。強制的に奪うときだけ `SWWS_FORCE=1 swws <profile>`。
- **Claude が切り替えるときは必ず `/swws` skill を使う**（直接 `swws web` を叩かない）。skill が先に使用中を調べ、別 worktree が使用中なら勝手に切り替えず確認する。


## ファイル編集の制限

Edit/Write/MultiEdit はプロジェクトディレクトリ外ではフックによりブロックされる。
**例外**（フック `restrict-edits.sh` が許可）:
- 他リポジトリへの PJ 間連携: 対象リポジトリの `.specs/` 配下にのみ書き込んでよい。要件・設計などの連携ドキュメントをそこにまとめること。
- `CLAUDE.md` / memory ディレクトリ配下 / セッション用スクラッチパッド（claude の一時ディレクトリ配下）への書き込み。
