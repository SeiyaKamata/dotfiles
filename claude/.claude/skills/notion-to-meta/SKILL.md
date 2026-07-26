---
name: notion-to-meta
description: Notion のタスクページから PR タイトル・ブランチ名などの命名情報を読み取り .specs/<feature>/meta.md に保存する。Notion のチケット URL があるとき tasks の前に使う。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
argument-hint: "<feature> <notion-url> [auto]"
---

# Notion → meta スキル

## 役割
Notion のタスクページの「Auto-generated Naming」から命名情報（Pull Request Title / Branch Name）を取り出し、`.specs/<feature>/meta.md` に保存する。
**Notion に触れるのはこのスキルだけ**に閉じ込め、他工程（tasks / create-pr）は meta.md だけを読む。これにより Notion 連携の有無・可否の分岐をパイプライン全体に広げない。

## 出力先
`.specs/<feature>/meta.md`（形式は `claude/CLAUDE.md`「PR / ブランチ命名」に従う）

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合、Step 3 のユーザー確認をスキップして保存する。

## 進め方

### Step 1: 引数チェック
- `<feature>`（必須）と `<notion-url>`（必須、`http(s)://…notion…`）を確定する
- どちらか欠けたら「使い方: /notion-to-meta <feature> <notion-url> [auto]」を表示して終了

### Step 2: Notion から命名を取得
- Notion 連携ツールが使えるなら、URL のページの「Auto-generated Naming」から次を読む：
  - `Pull Request Title`（例 `[SEC-16005] ATM Auth0移行`）
  - `Branch Name`（例 `feature/SEC-16005/atm-auth0-migration`）
- 連携が使えない／権限が無いなどで読めない場合は、ユーザーに貼ってもらう（AskUserQuestion）：
  - Pull Request Title
  - Branch Name
- `Pull Request Title` 先頭の角括弧内キー（例 `[SEC-16005]` → `SEC-16005`）を `ticket_key` にする。角括弧が無ければ `ticket_key` は空でよい

### Step 3: meta.md を書く
`.specs/<feature>/meta.md` を作成/更新する。既存の値がある場合は、明示的な変更指示が無い限り上書きしない。
`auto` でなければ、保存内容をユーザーに一度提示してから書き込む。

meta.md フォーマット:
```markdown
---
feature: <feature>
notion_url: <URL>
ticket_key: <SEC-16005 / 空>
pr_title: "<[SEC-16005] ATM Auth0移行>"
branch_name: <feature/SEC-16005/atm-auth0-migration>
---

# 命名メタ: <feature>

- Notion: <URL>
- PR タイトル素材: <pr_title>
- Branch Name（記録のみ・未使用）: <branch_name>
```

## 完了条件
`.specs/<feature>/meta.md` を保存できたら完了。`pr_title` は `/tasks` が各フェーズの PR タイトル組み立てに使う。

## 完了カード
meta.md の保存が済んだら、次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。次スキルは自動起動せずユーザーの実行を待つ。

- 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（無ければ行ごと省略）。meta.md の全項目はカードに転記せず、`ticket_key` / `pr_title` など要点だけ載せる。
- ▶ 行は該当する分岐だけを出す。

✅ 命名メタ保存完了
<どのチケットの命名を保存したかを 1 行>
- <主要な結果 最大 3 行>
📄 .specs/<feature>/meta.md
▶ OK：/tasks <feature>（design 完了後）

完了条件を満たせずに終了するときは、同じ構成でヘッダを `⚠ 命名メタ保存中断` に差し替え、一言サマリに中断理由（Notion を読めない・命名情報が取得できないなど）、▶ 行に復帰コマンドを書く（成果物が未生成なら 📄 行は省略する）。

自律モード（起動引数に `auto` を含む）では完了カードを出さず、遷移先を 1 行の簡易ログだけ残す（例: `次: /tasks <feature>`）。次スキルの起動は呼び出し元（orchestrator）が行う。
