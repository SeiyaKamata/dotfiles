---
name: create-pr
description: 変更内容をもとにdraftでPRを作成する。commit完了後に使う。
argument-hint: "[notion-page-url] [auto]"
allowed-tools: Bash(git *), Bash(gh *)
---

# PRエージェント

## 役割
コミット後にdraftのPRを作成する。

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合：
- Step 0: 未コミットの変更があれば `/commit auto` を呼んで完了後に続行する
- Step 1: ベースブランチはデフォルトブランチを自動採用する（聞かない）

引数なしの単体起動では Step 0 で `/commit` を呼び、Step 1 でユーザーに確認する。

## 引数
- `$ARGUMENTS` のうち URL 部分: NotionページのURL（省略可）
- `auto`: 自走モードフラグ（省略可）

## 進め方

### Step 0: 未コミットの変更を確認する

`git status` で未コミットの変更があるか確認する。

未コミットの変更がある場合：
- **`auto` モード** → `/commit auto` を起動し、完了後に Step 1 へ進む
- **単体起動** → `/commit` を起動し、完了後に Step 1 へ進む

変更がない場合はそのまま Step 1 へ進む。

### Step 1: ベースブランチを確認する

リポジトリのデフォルトブランチを取得する：
```
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'
```

**`auto` モード**の場合は上記で取得したブランチをそのまま使用する。

**単体起動**の場合はユーザーに確認する：

> マージ先のブランチはどこにしますか？（デフォルト: 上記で取得したブランチ）

回答がなければ上記で取得したブランチを使用する。

### Step 1.5: 作業ブランチを確認・作成する

現在のブランチを確認する：
```
git branch --show-current
```

現在のブランチがベースブランチと同じ場合、**必ず新しいブランチを作成してからPRを作る**。
ブランチ名はコミット内容から自動で命名する（例: `feat/add-login`, `fix/typo-in-readme`）。

```
git checkout -b <ブランチ名>
```

既に別のブランチにいる場合はそのまま進む。

### Step 2: 変更内容を確認する
```
git log origin/<ベースブランチ>..HEAD --oneline
git diff origin/<ベースブランチ>..HEAD --stat
```

### Step 3: PR本文を作成する

以下のテンプレートで本文を組み立てる：

```
## Summary
（コミット内容をもとに変更の概要を1〜3行で記述）

## 変更内容
（git diffの結果をもとに変更ファイルと変更内容を箇条書き）

## 関連リンク
（$ARGUMENTSが渡された場合のみ）
- Notion: $ARGUMENTS
```

**言葉づかい（タイトル・本文共通）:**

IT・ビジネスの専門用語を避け、読んだ人が知識に関わらず理解できる言葉で書く。
- 避ける例: リファクタリング、マイグレーション、エンドポイント、スキーマ、デプロイ、バリデーション
- 言い換え例: 「コードの整理」「テーブル構造の変更」「APIの受け口」「データの形式」「本番環境への反映」「入力値の確認」

### Step 4: draftのPRを作成する

まずリポジトリの利用可能なラベルを取得する：
```
gh label list
```

取得したラベル一覧からコミット内容に最も合うものを1つ選ぶ。

```
gh pr create --draft --base <ベースブランチ> --title "<タイトル>" --body "<本文>" --assignee @me --label "<ラベル>"
```

タイトルは最初のコミットメッセージをベースに作成する。

### Step 5: URLをユーザーに報告する

## エラー処理
- `gh pr create` が「ブランチがpushされていない」エラーになった場合: `git push -u origin HEAD` を実行してから再試行する
- `gh pr create` が「head branch is the same as base branch」エラーになった場合: Step 1.5 に戻り、新しいブランチを作成してから再試行する

## 完了条件
draftのPR作成後にURLをユーザーに報告したら完了。
