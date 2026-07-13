---
name: impl
description: タスクリストを受け取り実装を行う。.specs/<feature>/tasks.mdが出来上がったら使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, WebSearch, WebFetch
argument-hint: "<feature> [pN|task-numbers] [auto]"
---

# 実装スキル（コーディネーター）

## 役割
`.specs/<feature>/tasks.md` の**単一フェーズ（大タスク）**を実装する。
実装そのものは **`implementer` サブエージェントに委譲**し、このスキル（メイン）は**コーディネーターに徹する**：
git（ブランチ）・進捗（tasks.md のチェックボックス）・最終テストはメインが握り、
実装は implementer に丸ごと渡して結果を集約する。これによりメインの context を実装のトークンで汚さず、
仕様（requirements/design/tasks）だけで実装が通るか＝**仕様の自己完結性**も検証できる。

## 用語（前提）
用語の定義は `claude/CLAUDE.md`「用語集」に従う。特にこのスキルでは：
- **フェーズ = 大タスク = ブランチ = 1 PR**。tasks.md は大タスク（1., 2., ...）を 1 フェーズに 1:1 で対応させて出力する。複数フェーズ = stacked PR。
- 1 回の `/impl` 呼び出しが扱うのは**単一フェーズ（＝単一の大タスク）**のみ。マルチフェーズは orchestrator が `/impl <feature> p1`, `/impl <feature> p2`, ... と別々に呼ぶ。
- タスクの分割・粒度は **tasks の責務**。impl は tasks.md に**書かれたとおりに実装する**。大タスクが大きすぎても impl 側で分割しない（それは tasks がおかしいということなので、`/change` でタスク工程に差し戻す）。

## 入力
- `.specs/<feature>/requirements.md`
- `.specs/<feature>/design.md`
- `.specs/<feature>/tasks.md`

## 引数
- `$ARGUMENTS[0]`: feature 名（必須）
- `$ARGUMENTS[1]`: フェーズ指定または手動モード
  - 省略: 単一フェーズ構成の feature でそのフェーズを実行
  - `p1`, `p2`, ... : 指定フェーズ（大タスク）を実行
  - タスク番号（例: `1.1`, `1,2`）: 手動モードで指定サブタスクのみ実行

## 委譲の基本ルール（重要）
- **実装は必ず `implementer` サブエージェントに配布する**。メインでコードを直接書かない。
- **1 フェーズ = 1 implementer**。対象フェーズのサブタスクを丸ごと 1 つの implementer に渡し、tasks.md に書かれた順（`_Depends:_` 順）に実装させる。impl 側でサブタスクを分割・並列化しない。
- **メイン（このスキル）が握るもの**: git 操作（ブランチ作成・checkout）、tasks.md のチェックボックス更新、リポジトリ全体の最終テスト、詰まったときの判断。
- **サブエージェントに任せるもの**: 対象フェーズのコード実装と、タスク単位の確認のみ。implementer は git・tasks.md に触れない（`implementer` 側の制約に定義済み）。

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]` が未指定なら「使い方: /impl <feature> [pN|task-numbers] [auto]」を表示して終了
- feature 名、フェーズ、手動タスク番号を確定する
- 引数のいずれかに `auto` を含む場合は自律モード（ブロック抑制）とする。Step 6 の次ステップ提示で定型ブロックを出さず簡易ログのみ残す。

### Step 2: ブランチ準備（メインが実施）
tasks.md のブランチ名ルールに従い、ブランチを作成して切り替える：

**単一フェーズ（フェーズ指定なし）:**
- ブランチ名: `<feature>`
- デフォルトブランチから作成する

**フェーズ p1:**
- ブランチ名: `<feature>-p1`
- デフォルトブランチから作成する

**フェーズ pN（N > 1）:**
- ブランチ名: `<feature>-pN`
- 現在のブランチが `<feature>-p(N-1)` であることを確認する
- 一致しない場合はエラーを表示して終了する：
  > `<feature>-pN` を作成するには `<feature>-p(N-1)` ブランチにいる必要があります。
  > 現在のブランチ: `<現在のブランチ名>`

確認後、以下の手順でブランチを作成する：

**単一フェーズ・フェーズ p1（デフォルトブランチから作成）:**
```
DEFAULT=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
git fetch origin "$DEFAULT"
git checkout -b <ブランチ名> "origin/$DEFAULT"
```

**フェーズ pN（N > 1）（前フェーズのブランチから作成＝stacked）:**
```
git checkout -b <ブランチ名>
```

### Step 3: コンテキスト確認（メインが軽量に実施）
実装のためではなく**配布とレビューのため**に、以下を最小限確認する：
- `.specs/<feature>/tasks.md`: 対象フェーズ（＝対象の大タスク）のサブタスク一覧・完了条件・`_Requirements:_`・`_Depends:_` を把握する
- **他 PJ への handoff 依存を確認する**：対象フェーズのタスクが `_Depends:_` に `H<n>`（`## 他 PJ への handoff` の項目）を含む場合、それは**別 PJ の変更前提**でこの PJ では実装できない。該当 `H<n>` が未チェック（`[ ]`）なら `/handoff` で依頼を投げる必要があるため、implementer に配布せず、未依頼の handoff があることを報告して止める（自律モードは orchestrator の分岐に委ねる）。`H<n>` はコーディングタスクではないので implementer には渡さない
- テスト・ビルドコマンドをリポジトリの設定ファイルから確認する
  （`package.json`, `Makefile`, `go.mod`, `pyproject.toml` など）
- `git status --porcelain` でベースラインを確認する
- **prototype コードの有無**を確認する：`git rev-parse --verify <feature>-proto` が通れば、prototype 工程が動く参考実装を残している。あれば Step 4 で「参照して昇格」を implementer に指示する

requirements.md / design.md の詳細はメインで読み込まない — `implementer` が自分で読む。

### Step 4: 実装を implementer に配布
対象フェーズを **1 つの `implementer`（Agent）に丸ごと配布**する。指示（プロンプト）に以下を渡す：
- feature 名（specs のパスを含む）
- 対象フェーズ（大タスク）の番号と、tasks.md から転記したサブタスクの説明・完了条件・`_Requirements:_`・`_Depends:_`
- リポジトリのテスト／ビルドコマンド
- 既存コードの関連パターンの手がかり（あれば）
- **prototype コードがある場合の「参照して昇格」指示**（下記）
- 「tasks.md に書かれた順に実装し、git・tasks.md には触れず、実装結果を報告フォーマットで返す」旨（`implementer` 側にも定義済みだが明示する）

**参照して昇格（`<feature>-proto` が存在する場合のみ）:**
prototype 工程が `<feature>-proto` ブランチに動く参考実装を残している。implementer に次を指示する：
- 白紙から書き起こさず、prototype コードを**読んで流用**する。参照は**読み取り専用の git** で行う（ブランチ切り替え・作業ツリー変更をする git 操作は implementer に禁止されているため使わない）：
  - ファイル一覧: `git diff --stat $(git merge-base HEAD <feature>-proto) <feature>-proto`
  - 中身の参照: `git show <feature>-proto:<path>`
  - 流用は「参照して自分で書く」＝ `git show` で読んだ内容を Write/Edit で現ブランチに書き起こす（`git checkout -- <path>` 等での取り込みはしない）
- prototype コードは**品質を問わない捨て実装**なので、そのまま写さない。**本番品質に整形して昇格**する（命名・責務分割・エラーハンドリング・型・テスト・本リポジトリのコード規約に合わせる）
- **正典は `design.md`**。prototype コードと design.md が食い違う場合は design.md を優先する（prototype は速く実装するための参考実装にすぎない）
- 対象フェーズのサブタスクに対応する範囲だけを流用・整形する（フェーズ外は取り込まない。stacked 運用ではフェーズごとに必要な部分だけ昇格する）

手動モード（タスク番号指定）の場合は、指定サブタスクだけを 1 つの implementer に配布する。

### Step 5: 報告の取り込み（メインが実施）
`implementer` の報告が返ったら：
1. `変更ファイル`・`タスクごとの確認` を確認する
2. **完了と報告されたサブタスクの `[ ]` を `[x]` に更新**する（`.specs/<feature>/tasks.md`）
3. `blockers` があるサブタスクはチェックせず、下記「例外処理」に従って処理する

### Step 6: フェーズ完了後（メインが実施）
- リポジトリ全体のテスト・ビルドを実行して確認する（最終確認はメインが 1 回まとめて行う）
- 対象フェーズの各サブタスクが完了条件・関連要件（`_Requirements:_`）を満たしているか確認する
- 全て満たしたら、末尾の「次ステップ提示」の定型ブロックで次の手順（`/test`）を提示する

## 例外処理
- `implementer` が `blockers`（仕様の曖昧さ・設計の穴・大タスクが大きすぎる等）を報告 → メインで判断する。
  - 手動／単体起動時: ユーザーに確認する
  - 自律モード（`auto`）時: 軽微なら追加指示を添えて `implementer` を再配布。仕様・設計・タスク分割の問題なら `/change` 相当の差し戻しが要るため、報告して止める（orchestrator の分岐に委ねる）
- 最終テストが失敗し続ける場合 → 根本原因を調査し、対象フェーズを `implementer` に再配布して最小限の修正を試みる

## 完了条件
対象フェーズの全サブタスクが `[x]` になり、テスト・ビルドがパスしたら完了。

## 次ステップ提示
単体起動で完了したら、次の定型ブロックを**コードフェンスで囲まず**プレーンテキストで出力し、次スキルは自動起動せずユーザーの実行を待って終了する。

```
────────────────────────────────
✅ フェーズ実装完了
📄 .specs/<feature>/tasks.md（チェックボックス更新）
▶ 次のステップ
   /test <feature>
   理由: 実装が終わったのでテストで検証する
────────────────────────────────
```

自律モード（起動引数に `auto` を含む）では上記ブロックを出さず、遷移先を 1 行の簡易ログだけ残す（例: `次: /test <feature>`）。次スキルの起動は呼び出し元（orchestrator）が行う。
