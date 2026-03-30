---
name: create-pr
description: 変更内容をもとにdraftでPRを作成する。commit完了後に使う。
argument-hint: "[notion-page-url]"
allowed-tools: Bash(git *), Bash(gh *)
---

# PRエージェント

## 役割
コミット後にdraftのPRを作成する。

## 引数
- `$ARGUMENTS`: NotionページのURL（省略可）

## 進め方

### Step 1: ベースブランチを確認する

ユーザーに以下を聞く：

> マージ先のブランチはどこにしますか？（デフォルト: `develop`）

回答がなければ `develop` を使用する。

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

## 完了条件
draftのPR作成後にURLをユーザーに報告したら完了。
