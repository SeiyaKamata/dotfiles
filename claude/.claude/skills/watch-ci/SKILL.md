---
name: watch-ci
description: PRのCIを監視し、完了後に結果に応じて分岐対応する。push後やPR作成後に使う。
argument-hint: "[PR番号] [auto]"
allowed-tools: Bash(gh *), Bash(git *)
---

# CI監視エージェント

## 役割
PRのCIが完了するまで監視し、結果に応じて次のアクションへ分岐させる。

- CI成功 + 未対応コメントなし → draftならReady for reviewに切り替える
- CI成功 + 未対応コメントあり → `/respond-pr-comments` を提案する
- CI失敗 → 失敗ジョブのログを取得し、対応方針を人間と相談する

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合、Step 4-2をスキップしてdraftのまま完了とする。
orchestratorから呼ばれるときは必ず `auto` を付ける（Ready for reviewへの切り替えはorchestrator停止点で人間が判断する）。

引数なしの単体起動では従来どおり人間に確認してから切り替える。

## 引数
- `$ARGUMENTS` のうち数字部分: PR番号（省略時は現在のブランチに紐づくPRを使う）
- `auto`: 自走モードフラグ（省略可）

## 進め方

### Step 1: 対象PRを特定する

`$ARGUMENTS` が指定されていればそれを使用する。
未指定なら現在のブランチからPRを特定する：

```
gh pr view --json number,url,isDraft,headRefName,state
```

PRが見つからない場合は人間に確認する。

### Step 2: CIを監視する

`--watch` で完了までブロッキング監視する：

```
gh pr checks <PR番号> --watch --interval 30
```

監視中であることを人間に一言伝える（「CIを監視しています。完了するまで待ちます。」）。

### Step 3: 結果を判定する

監視完了後、最終ステータスを取得する：

```
gh pr checks <PR番号> --json name,state,conclusion,link
```

- すべての `conclusion` が `SUCCESS` / `NEUTRAL` / `SKIPPED` → 成功（Step 4へ）
- いずれかが `FAILURE` / `CANCELLED` / `TIMED_OUT` / `ACTION_REQUIRED` → 失敗（Step 5へ）

### Step 4: CI成功時の処理

#### 4-1: 未対応のレビューコメントを確認する

```
gh pr view <PR番号> --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'
```

- 未対応コメントが**あり** → 件数と概要を人間に提示し、`/respond-pr-comments` の起動を提案する
- 未対応コメントが**なし** → 4-2 へ

#### 4-2: draftならReady for reviewに切り替える

**`auto` モード時はこのステップをスキップ**し、draftのまま完了条件へ進む。

PRがdraftか確認：

```
gh pr view <PR番号> --json isDraft --jq '.isDraft'
```

- draft (`true`) → 人間に確認したうえでReady for reviewに切り替える
  ```
  gh pr ready <PR番号>
  ```
- 既にOpen (`false`) → 既にレビュー可能な状態である旨を人間に報告して終了

### Step 5: CI失敗時の処理

#### 5-1: 失敗ジョブを特定する

```
gh pr checks <PR番号> --json name,state,conclusion,link | jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")]'
```

#### 5-2: ログを取得する

各失敗ジョブのrun IDを特定し、ログを取得する：

```
gh run list --branch <ブランチ名> --limit 5 --json databaseId,name,conclusion,workflowName
gh run view <run-id> --log-failed
```

ログが長すぎる場合は失敗ステップに絞ってサマリーする。

#### 5-3: 対応方針を人間と相談する

失敗の概要（どのジョブ・どのステップ・主要なエラーメッセージ）を提示し、以下を確認する：

> CIが失敗しました。修正方針を相談しますか？それともログを見て自動で対応案を提示しますか？

ユーザーの指示に応じて修正タスクへ移行する。

## 完了条件
- CI成功 + 未対応コメントなし + Ready for reviewに切り替え完了（単体起動時）→ 完了
- CI成功 + 未対応コメントなし + `auto` モード → draftのまま完了
- CI成功 + 未対応コメントあり → `/respond-pr-comments` への引き継ぎを提案したら完了
- CI失敗 → 失敗内容を報告し、修正方針について人間に確認したら完了

## エラー処理
- `gh pr view` でPRが見つからない場合: 現在のブランチがpushされているか・PRが作成済みかを確認し、必要なら `/create-pr` を提案する
- `gh pr checks --watch` がタイムアウトした場合: 再実行するか人間に確認する
- `gh pr ready` が権限エラーで失敗した場合: 人間にWeb UIでの操作を案内する
