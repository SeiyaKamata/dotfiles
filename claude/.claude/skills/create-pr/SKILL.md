---
name: create-pr
description: 変更内容をもとにdraftでPRを作成する。commit完了後に使う。
argument-hint: "[auto]"
allowed-tools: Bash(git *), Bash(gh *), Read
---

# PRエージェント

## 役割
コミット後にdraftのPRを作成する。**単一フェーズなら 1 PR、複数フェーズ（stacked）なら各フェーズのブランチごとに PR を一斉作成**する。

## 用語（前提）
用語は `claude/CLAUDE.md`「用語集」に従う。**フェーズ = 大タスク = ブランチ = 1 PR**。複数フェーズは stacked PR（`pN` の base は `p(N-1)`、`p1` の base はデフォルトブランチ）。

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合：
- Step 0: 未コミットの変更があれば `/commit auto` を呼んで完了後に続行する
- Step 1: ベースブランチはデフォルトブランチを自動採用する（聞かない）
- stacked と判定したら全フェーズ PR を確認なしで一斉作成する

引数なしの単体起動では Step 0 で `/commit` を呼び、Step 1 でユーザーに確認する。

## 引数
- `auto`: 自走モードフラグ（省略可）

## 進め方

### Step 0: 未コミットの変更を確認する

`git status` で未コミットの変更があるか確認する。

未コミットの変更がある場合：
- **`auto` モード** → `/commit auto` を起動し、完了後に Step 1 へ進む
- **単体起動** → `/commit` を起動し、完了後に Step 1 へ進む

変更がない場合はそのまま Step 1 へ進む。

### Step 1: ベースブランチと PR 構成（単一 / stacked）を判定する

リポジトリのデフォルトブランチを取得する：
```
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

**`auto` モード**の場合は上記で取得したブランチをそのまま使用する。
**単体起動**の場合はユーザーに確認する（回答がなければ上記を使用）：
> マージ先のブランチはどこにしますか？（デフォルト: 上記で取得したブランチ）

次に **単一 PR か stacked PR か**を現在のブランチ名から判定する：
```
git branch --show-current
```
- 現在のブランチが `<feature>-pN`（末尾が `-p` + 数字）の形 → **stacked の可能性**。feature 名を `-p<数字>` を除いて求め、フェーズブランチを列挙する：
  ```
  git branch --list "<feature>-p*"
  ```
  2 本以上あれば **stacked モード**（`p1`, `p2`, ... を番号順に並べる）。1 本だけなら単一 PR として扱う。
- 末尾が `-pN` でない（`<feature>` などの単一ブランチ） → **単一 PR モード**

判定後、feature 名（ブランチ名から `-pN` を除いたもの）で `.specs/<feature>/tasks.md`（各フェーズの PR タイトル）を読む。あれば PR タイトルは tasks.md の対応表を使い、無ければ従来どおりコミットメッセージから生成する。

### Step 1.5: 作業ブランチを確認・作成する（単一 PR モードのみ）

現在のブランチがベースブランチと同じ場合、**必ず新しいブランチを作成してからPRを作る**。
ブランチ名はコミット内容から自動で命名する（例: `feat/add-login`, `fix/typo-in-readme`）。
```
git checkout -b <ブランチ名>
```
既に別のブランチにいる場合はそのまま進む。stacked モードではフェーズブランチが既に存在するので新規作成しない。

### Step 2〜4: PR を作成する

言葉づかい（タイトル・本文共通）:
IT・ビジネスの専門用語を避け、読んだ人が知識に関わらず理解できる言葉で書く。
- 避ける例: リファクタリング、マイグレーション、エンドポイント、スキーマ、デプロイ、バリデーション
- 言い換え例: 「コードの整理」「テーブル構造の変更」「APIの受け口」「データの形式」「本番環境への反映」「入力値の確認」

利用可能なラベルを取得しておく：
```
gh label list
```

#### 単一 PR モード
1. 変更内容を確認する：
   ```
   git log origin/<ベースブランチ>..HEAD --oneline
   git diff origin/<ベースブランチ>..HEAD --stat
   ```
2. 下記テンプレートで本文を組み立てる。
3. draft PR を作成する（未 push なら先に `git push -u origin HEAD`）：
   ```
   gh pr create --draft --base <ベースブランチ> --title "<タイトル>" --body "<本文>" --assignee @me --label "<ラベル>"
   ```

#### stacked モード
`p1` から番号順に、**各フェーズのブランチごとに 1 PR を作成**する。各 PR の base は 1 つ下のフェーズ（`p1` はデフォルトブランチ）：

各フェーズ `pN`（`base` = `pN==p1` ならデフォルトブランチ、そうでなければ `<feature>-p(N-1)`）について：
```
git push -u origin <feature>-pN
git log <base>..<feature>-pN --oneline      # この PR に含まれる差分（前フェーズとの差分）
git diff <base>..<feature>-pN --stat
gh pr create --draft --base <base> --head <feature>-pN \
  --title "<タイトル>" --body "<本文>" --assignee @me --label "<ラベル>"
```
- 各 PR の本文は**そのフェーズの差分だけ**をもとに書く（前フェーズの変更を含めない）。
- PR 本文の Summary 冒頭に stacked の位置を明記する（例: `stacked PR 2/3（base: <feature>-p1）`）。
- 作成順は `p1 → p2 → ...`（base 側の PR を先に作る）。

**PR本文テンプレート:**
```
## Summary
（変更の概要を1〜3行で。stacked の場合は位置と base を明記）

## 変更内容
（git diffの結果をもとに変更ファイルと変更内容を箇条書き）
```
タイトルは **tasks.md の対応表で確定した各フェーズの PR タイトル**をそのまま使う（`【鎌田QA】…（PR N/M）` の形）。tasks.md が無い／未記載の場合のみ、そのフェーズ（単一なら全体）の最初のコミットメッセージをベースに作成する。

### Step 5: URL を報告し次ステップを提示する

作成した PR の URL（stacked なら全 PR の URL を番号順）を報告し、末尾の「次ステップ提示」の定型ブロックで次の手順を提示する。

## エラー処理
- `gh pr create` が「ブランチがpushされていない」エラーになった場合: `git push -u origin <対象ブランチ>` を実行してから再試行する
- `gh pr create` が「head branch is the same as base branch」エラーになった場合: base と head が同じになっていないか確認する（単一モードは Step 1.5 で新ブランチを作る）

## 完了条件
draft PR（stacked なら全フェーズ分）を作成して URL を報告し、`/watch-ci` で CI 監視に進めることを提案したら完了。

## 次ステップ提示
単体起動で完了したら、次の定型ブロックを**コードフェンスで囲まず**プレーンテキストで出力し、次スキルは自動起動せずユーザーの実行を待って終了する。

```
✅ draft PR 作成完了 — <作成した PR の URL（stacked なら全 URL）>
OK：/watch-ci
```

自律モード（起動引数に `auto` を含む）では上記ブロックを出さず、遷移先を 1 行の簡易ログだけ残す（例: `次: /watch-ci`）。次スキルの起動は呼び出し元（orchestrator）が行う。
