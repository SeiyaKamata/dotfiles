---
name: hotfix
description: 本番tagからreleaseブランチとworkブランチを切り、修正後にrelease宛・main宛の2つのPRを作成する。
argument-hint: "[tag]"
---

# hotfix エージェント

## 役割
本番環境で動いているtagからhotfixのreleaseブランチ・workブランチを切り、ユーザーと対話しながら修正を実装し、最終的に以下の2つのPRを作成する。

- `release/<tag>_p○` ← `work/<tag>_p○`
- `main` ← `work/<tag>_p○`

## 引数
- `$ARGUMENTS`: hotfix対象のtag名（省略可）。省略時はユーザーに確認する。

## ブランチ命名規則
- `release/<tag>_p○` と `work/<tag>_p○`
- `○` の決め方:
  - `<tag>` が `_p<数字>` で終わっていない場合 → `1`
  - `<tag>` が `_p<数字>` で終わっている場合 → 末尾の数字 + 1。このとき `<tag>` 側の `_p<数字>` 部分は取り除いてから新しい番号を付ける
- 例:
  - tag `v1.2.3` → `release/v1.2.3_p1`, `work/v1.2.3_p1`
  - tag `v1.2.3_p1` → `release/v1.2.3_p2`, `work/v1.2.3_p2`
  - tag `v1.2.3_p5` → `release/v1.2.3_p6`, `work/v1.2.3_p6`

## 進め方

### Step 0: 作業ディレクトリの状態を確認する

未コミット・未stashの変更がある場合は中断してユーザーに伝える。

```
git status
```

変更がある場合:
> 未コミットの変更があります。先にコミットまたはstashしてからやり直してください。

### Step 1: 対象tagを確定する

引数 `$ARGUMENTS` が渡されていればそれを対象tagとする。

引数が無い場合、ユーザーに確認する:

> hotfix対象のtag名を教えてください。（例: v1.2.3, v1.2.3_p1）

参考までに直近のtagを提示してもよい:
```
git tag --sort=-creatordate | head -n 10
```

確定したtagがリモートに存在することを確認する:
```
git fetch --tags
git rev-parse --verify "refs/tags/<tag>"
```

### Step 2: 次のp番号を計算してブランチ名を決める

`<tag>` を以下のルールで分解する:

- `<tag>` が正規表現 `^(.+)_p([0-9]+)$` にマッチする場合:
  - base = キャプチャ1
  - next = キャプチャ2 + 1
- マッチしない場合:
  - base = `<tag>` そのまま
  - next = 1

`release_branch = release/<base>_p<next>` / `work_branch = work/<base>_p<next>` とする。

念のためユーザーに提示して承認を得る:

> 以下のブランチを作成します。よろしいですか？
> - release: `<release_branch>`
> - work: `<work_branch>`
> - 起点tag: `<tag>`

### Step 3: releaseブランチを作成する

tagから直接releaseブランチを切り、リモートにpushする。

```
git checkout -b <release_branch> refs/tags/<tag>
git push -u origin <release_branch>
```

既に同名のローカル/リモートブランチが存在する場合は中断し、状況をユーザーに伝える。

### Step 4: workブランチを作成する

releaseブランチからworkブランチを切る。

```
git checkout -b <work_branch>
```

このworkブランチで以降の修正作業を行う。

### Step 5: 修正内容のヒアリング

**重要: ユーザーから明示的な実装指示があるまで、コード変更は一切行わない。**

ユーザーに次を尋ねる:

> どのような修正を行いますか？修正内容・対象ファイル・確認したい点があれば教えてください。

ヒアリング中はファイルの読み取りや調査までは行ってよいが、編集・書き込みは禁止。
ユーザーが「実装して」「修正お願い」など明示的に指示したら Step 6 に進む。

### Step 6: 修正を実装する

ユーザーの指示に沿って修正を実装する。複数ステップに分かれる場合は適宜進捗を共有する。

### Step 7: コミットする

`/commit` スキルに準ずる手順でコミットする。
Conventional Commits 形式で `fix` を基本タイプとして使う。

```
git add <files>
git commit -m "$(cat <<'EOF'
fix(<scope>): <subject>

<body>

Co-Authored-By: <ハーネス指定のモデル行>
EOF
)"
```

### Step 8: workブランチをpushする

```
git push -u origin <work_branch>
```

### Step 9: PR本文を作成する

以下のテンプレートで本文を組み立てる:

```
## Summary
（修正内容の概要を1〜3行）

## 背景
（なぜhotfixが必要だったか）

## 変更内容
（変更ファイル・変更点を箇条書き）

## 起点tag
<tag>

## 動作確認
- [ ] ...
```

### Step 10: release宛のPRを作成する

`gh label list` で利用可能なラベルを確認し、`hotfix` などの該当ラベルがあれば付与する。

```
gh pr create \
  --base <release_branch> \
  --head <work_branch> \
  --title "hotfix: <subject>" \
  --body "<本文>" \
  --assignee @me \
  --label "<該当ラベル>" \
  --draft
```

draftで作成する。レビュー準備が整ったらユーザーがready化する。

### Step 11: main宛のPRを作成する

同じ `<work_branch>` を head として、base を `main` にしたPRを作成する。

```
gh pr create \
  --base main \
  --head <work_branch> \
  --title "hotfix: <subject> (to main)" \
  --body "<本文>" \
  --assignee @me \
  --label "<該当ラベル>" \
  --draft
```

main宛PRの本文には冒頭に以下を加える:

```
> release宛PRと同じ修正をmainにも取り込むためのPRです。
> 対応release PR: #<release宛PRの番号>
```

### Step 12: 報告

2つのPR URLをユーザーに報告する:

```
✅ hotfix用のPRを作成しました。
- release宛: <URL>
- main宛: <URL>

起点tag: <tag>
release: <release_branch>
work: <work_branch>
```

## エラー処理

- `git rev-parse --verify "refs/tags/<tag>"` が失敗: tagが存在しない旨をユーザーに伝え、Step 1 に戻る。
- `git checkout -b` でブランチ名が既存と衝突: ユーザーに状況を伝え、既存ブランチを使うのか別名にするのか確認する。
- `gh pr create` が失敗（push未完了など）: `git push -u origin HEAD` で再push後にリトライ。
- main宛PRで差分が大きすぎる・コンフリクト多発の場合: ユーザーに以下の選択肢を提示する:
  - main から別のworkブランチを切ってcherry-pickする
  - release を main にマージする運用に切り替える

## 完了条件
release宛・main宛の2つのPRを作成し、両方のURLをユーザーに報告したら完了。
