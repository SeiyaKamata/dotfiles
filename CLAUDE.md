# dotfiles

個人の開発環境設定を管理するリポジトリ。

`~/.claude/` の `CLAUDE.md` / `settings.json` / `skills` / `agents` / `.mcp.json` は `claude/.claude/` への
symlink。**この repo を編集すると全プロジェクトの Claude Code 設定が即座に変わる**（インストール操作は不要）。

## ブランチ運用

ブランチを切らず、`main` に直接コミット・直接 push してよい。本人 1 人しか触らない repo で PR の
レビュー価値がないため意図的にこの運用にしている。**PR 運用を勧めないこと。**

GitHub 側に「Changes must be made through a pull request」保護ルールが残っているが過去の名残で、
bypass 権限で push は通る。このメッセージが出ても設定の食い違いとして警告しない（想定内）。

## worktree と Docker

各アプリリポジトリは git worktree で複数ブランチを同時に作業する。Docker のマウント先が
**今いる worktree のパス**になっているかを必ず確認すること（ずれていれば `swws` で切り替える）。

compose プロジェクトは 1 リポジトリ 1 つしかないため、`swws` で up すると
**別の worktree で稼働中の同プロジェクトを黙って奪う**。別セッションの作業を壊す事故になる。

- **Claude が切り替えるときは必ず `/swws` skill を使う**（直接 `swws web` を叩かない）。
  skill が先に使用中を調べ、別 worktree が使用中なら勝手に切り替えず確認する。
- コマンド一覧・対応リポジトリ・`SWWS_FORCE` での強制切替は `/swws` に書いてある。

## ファイル編集の制限

Edit/Write/MultiEdit はプロジェクトディレクトリ外ではフックによりブロックされる。
Bash も同じ判定に通る（`cat > 外部パス` での迂回を防ぐため）。
**例外**（フック `restrict-edits.sh` が許可）:
- 他リポジトリへの PJ 間連携: 対象リポジトリの `.specs/` 配下の **markdown のみ**書き込んでよい。
  要件・設計などの連携ドキュメントをそこにまとめること。エージェントが自動で読み込む名前
  （`CLAUDE.md` / `CLAUDE.local.md` / `AGENTS.md` / `AGENT.md` / `GEMINI.md` / `README.md`）は
  markdown でも不可 — 他 PJ から相手セッションの振る舞いを書き換えられてしまうため。
  判定は symlink 解決後の実パスで行う（`.specs` を symlink にしても抜けられない）。
- memory ディレクトリ配下 / セッション用スクラッチパッド（claude の一時ディレクトリ配下）への書き込み。
