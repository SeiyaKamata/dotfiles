---
name: qa
description: コードレビュー後にブラウザで動作確認する最終受け入れゲート。/review の後に使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent
disallowed-tools: mcp__playwright
argument-hint: "<feature> [auto]"
---

# QAスキル

## 役割
コードレビュー後に、アプリを実起動した状態でブラウザ操作をなぞり、要件どおり動くかを確認する**最終受け入れゲート**。
ブラウザ操作は一切行わず、`qa-browser` サブエージェントに委譲する（Playwright はメインで触らない）。
アプリ到達性を確認し、qa.md のシナリオを `qa-browser` に渡し、結果を集約して合否で分岐する。

## 入力
- `.specs/<feature>/qa.md`（`tasks` が生成した QA シナリオ）

## 自走モード（`auto` 引数）
`$ARGUMENTS[1]` が `auto` の場合、人間の承認を待たずに結果を報告し、Step 5 の分岐まで自動で進める。
引数なしの単体起動では結果を報告し、分岐前にユーザーに確認する。

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]` が未指定なら「使い方: /qa <feature> [auto]」を表示して終了
- feature 名と auto フラグを確定する

### Step 2: アプリ到達性確認
`/qa` はアプリ起動済みを前提に**到達性のみ確認**する（自身ではアプリを起動しない）。
ベース URL に到達できるか確認する（`curl -sSf <baseURL>` など）。

- 到達できる → Step 3 へ進む
- **到達できない（未起動）** → プロジェクト CLAUDE.md の起動手順（docker compose / `swws` / dev server）を案内して停止する。

### Step 3: シナリオ実行の委譲
`.specs/<feature>/qa.md` を読み、`qa-browser` を Agent で起動する。**全シナリオを1回の委譲で**渡す（ブラウザセッション共有・メインのコンテキスト消費最小）。
渡す入力: ベース URL / シナリオ配列（qa.md の該当ブロックそのまま）/ スクリーンショット保存先ディレクトリ（スクラッチパッド等の git 管理外）。

`qa-browser` から `S<n>: pass|fail`＋原因1行＋スクショパスの配列だけを受領する。

### Step 4: 集約・更新・報告
- 結果配列で `.specs/<feature>/qa.md` のチェックボックスを更新する（pass → `[x]` / fail → `[ ]` のまま）
- `## QA結果: PASS / FAIL` ＋ シナリオ別内訳（fail は原因）を出力する
- スクショは PR 添付用に保持する

### Step 5: 分岐
- **全シナリオ pass** → `/commit` を起動する（コミット工程へ）
- **fail がある** → 失敗シナリオと原因を添えて `/fix` に渡す（設計起因なら `/design`・`/impl`）

## 出力フォーマット
```
## QA結果: PASS / FAIL

- シナリオ数: N
- pass: N
- fail: N

### 失敗シナリオ（FAILの場合）
- S<n> [タイトル]: [原因1行] — [スクショパス]
```

## 完了条件
全シナリオが pass（`[x]`）になり、コミット工程に渡せる状態になったら完了。
