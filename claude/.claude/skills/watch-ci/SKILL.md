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
- CI成功 + 未対応コメントあり → `/resolve-comments` を提案する
- CI失敗 → 失敗ジョブのログを取得し、対応方針を人間と相談する

## 用語（前提）
用語は `claude/CLAUDE.md`「用語集」に従う。**フェーズ = 大タスク = ブランチ = 1 PR**。複数フェーズは stacked PR。stacked のときは **feature の全 PR を対象に CI を監視して集約**する。

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合、Step 4-2をスキップしてdraftのまま完了とする。
orchestratorから呼ばれるときは必ず `auto` を付ける（Ready for reviewへの切り替えはorchestrator停止点で人間が判断する）。
stacked（複数 PR）の場合は全 PR の CI が green になるまで監視し、いずれかが赤なら失敗処理（Step 5）へ入る。

引数なしの単体起動では従来どおり人間に確認してから切り替える。

## 引数
- `$ARGUMENTS` のうち数字部分: PR番号（省略時は現在のブランチに紐づくPRを使う）
- `auto`: 自走モードフラグ（省略可）

## 進め方

### Step 1: 対象PRを特定する（単一 / stacked）

`$ARGUMENTS` に PR 番号が指定されていればそれを使用する（単一 PR）。
未指定なら現在のブランチから判定する：

- 現在のブランチが `<feature>-pN`（末尾 `-p` + 数字）→ **stacked の可能性**。feature 名を求めてフェーズブランチの PR を番号順に列挙する：
  ```
  for b in $(git branch --list "<feature>-p*" | sed 's/^[ *]*//' | sort -t p -k2 -n); do
    gh pr list --head "$b" --json number,url,isDraft,headRefName,state --jq '.[]'
  done
  ```
  2 件以上ヒットしたら **stacked モード**（以降 Step 2〜3 を各 PR について回し、結果を集約する）。
- それ以外は単一 PR：
  ```
  gh pr view --json number,url,isDraft,headRefName,state
  ```

PRが見つからない場合は人間に確認する（`auto` かつ未作成なら `/create-pr auto` を提案）。

### Step 2: CIを監視する

`--watch` で完了までブロッキング監視する：

```
gh pr checks <PR番号> --watch --interval 30
```

監視で表示が止まる区間に入るので、開始時に「出力規律」の 1 行（`⏳ watch-ci: PR #<n> の CI 完了を待機中…`）を出す（1 PR につき 1 回）。

### Step 3: 結果を判定する

監視完了後、最終ステータスを取得する：

```
gh pr checks <PR番号> --json name,state,conclusion,link
```

- すべての `conclusion` が `SUCCESS` / `NEUTRAL` / `SKIPPED` → 成功（Step 4へ）
- いずれかが `FAILURE` / `CANCELLED` / `TIMED_OUT` / `ACTION_REQUIRED` → 失敗（Step 5へ）

**stacked モードの集約**: Step 2〜3 を全 PR について回し、**全 PR が成功なら Step 4、1 つでも失敗があれば Step 5**（どの PR/ブランチが失敗したかを明記する）。stacked では下位フェーズ（base 側）の修正が上位 PR にも影響するため、失敗フェーズを直したら stack を rebase 伝播して再 push し、再度全 PR を監視する。

### Step 4: CI成功時の処理

#### 4-1: 未対応のレビューコメントを確認する

```
gh pr view <PR番号> --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'
```

- 未対応コメントが**あり** → 件数と概要を人間に提示し、`/resolve-comments` の起動を提案する
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

#### 5-4: 再発しそうな失敗ならmemoryに残す

CI失敗の原因が **その PJ で繰り返しハマる構造的なもの**（例: この PJ の CI は import 順 lint で
必ず落ちる、特定の env を入れ忘れると必ず E2E が落ちる、CI 専用の前提手順がある）だと判断したら、
memory に1件保存する。

- 保存先は通常のmemory（`~/.claude/projects/<cwd>/memory/`、1メモリ=1ファイル、`MEMORY.md` に
  インデックス1行追記）。type は `project`
- body には「いつ・どの条件で落ちるか」と「次回どう避けるか」を書く
- **保存しないもの**: その PR 限りの一回限りのバグ・タイポ修正、git log や diff を見れば分かること
  （CLAUDE.md のメモリ規約に従う）。既に同趣旨のメモリがあれば新規作成せず更新する
- 保存したら「<要点> をmemoryに記録しました」と一言報告する

## 完了条件
- CI成功 + 未対応コメントなし + Ready for reviewに切り替え完了（単体起動時）→ 完了
- CI成功 + 未対応コメントなし + `auto` モード → draftのまま完了
- CI成功 + 未対応コメントあり → `/resolve-comments` への引き継ぎを提案したら完了
- CI失敗 → 失敗内容を報告し、（再発しそうなら）memoryに記録し、修正方針について人間に確認したら完了

## エラー処理
- `gh pr view` でPRが見つからない場合: 現在のブランチがpushされているか・PRが作成済みかを確認し、必要なら `/create-pr` を提案する
- `gh pr checks --watch` がタイムアウトした場合: 再実行するか人間に確認する
- `gh pr ready` が権限エラーで失敗した場合: 人間にWeb UIでの操作を案内する

## 出力規律
実行中の逐次ナレーション（「〜します」「〜しました」）は出さない（ツール実行はターミナルに表示されるため二重になる）。ただし `gh pr checks --watch` で表示が止まる区間の開始時だけ、次の 1 行を出す（1 PR につき 1 回。stacked では PR ごとに 1 回）。

⏳ watch-ci: PR #<n> の CI 完了を待機中…

## 完了カード
監視と判定が済んだら、次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。次スキルは自動起動せずユーザーの実行を待つ。一言サマリは 1 行、主要な結果は **最大 3 行**（無ければ行ごと省略）で、失敗ジョブのログ本体は載せず要点 1 行に畳む。

- 🔗 行は対象 PR を **1 本 1 行**で出す（stacked なら監視した全 PR。行数上限は主要な結果にだけ課す）。▶ 行は完了時点で確定した分岐 1 つだけを出す。

✅ CI 監視完了
<対象 PR 数と CI 判定を 1 行>
- <主要な結果 最大 3 行>
🔗 <対象 PR の URL>
▶ OK（green + 未解決コメントあり）：/resolve-comments
▶ OK（green + 未解決コメントなし）：マージ / Ready for review を判断（停止点）
▶ NG（CI 赤）：失敗ジョブのログを確認して修正

完了条件を満たせずに終了するときは、同じ構成でヘッダを `⚠ CI 監視中断` に差し替え、一言サマリに中断理由（PR 未作成・`--watch` タイムアウト・権限エラーなど）、▶ 行に復帰コマンドを書く。

自律モード（起動引数に `auto` を含む）では完了カードを出さず、確定した遷移先を 1 行の簡易ログだけ残す（例: `次: /resolve-comments`）。次スキルの起動は呼び出し元（orchestrator）が行う。
