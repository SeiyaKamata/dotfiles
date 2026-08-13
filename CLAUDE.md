# dotfiles

個人の開発環境設定を管理するリポジトリ。

`~/.claude/` の `CLAUDE.md` / `settings.json` / `skills` / `agents` / `.mcp.json` は `claude/.claude/` への
symlink。**この repo を編集すると全プロジェクトの Claude Code 設定が即座に変わる**（インストール操作は不要）。

## ブランチ運用

ブランチを切らず、`main` に直接コミット・直接 push してよい。本人 1 人しか触らない repo で PR の
レビュー価値がないため意図的にこの運用にしている。**PR 運用を勧めないこと。**

GitHub 側に「Changes must be made through a pull request」保護ルールが残っているが過去の名残で、
bypass 権限で push は通る。このメッセージが出ても設定の食い違いとして警告しない（想定内）。

## Slack 通知

dotfiles の修正は Slack 投稿しなくていい。「工程完了の Slack 通知」ルール（lrm-corp/CLAUDE.md）は
skill pipeline の完了カード向けで、dotfiles リポジトリ自体の直接編集には適用しない。


## skill / エージェント定義の書き方

**いまの構造だけを書く。** 以前の仕様を前提にした表現（「他工程で廃した〜」「以前は〜だったが」）を
使わない — 読み手に変更前を知っている前提を要求し、規範として誤読される。**その設計を選んだ理由**は
