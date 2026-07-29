---
name: hotfix
description: 本番tagからreleaseブランチとworkブランチを切り、修正後にrelease宛・main宛の2つのPRを作成する。
argument-hint: "[tag]"
---

# hotfix スキル

## 役割
本番環境で動いている tag から hotfix の release ブランチ・work ブランチを切り、ユーザーと対話しながら修正を実装し、**2 つの PR** を作成する。

- `release/<tag>_p○` ← `work/<tag>_p○`（本番へ当てる）
- `main` ← `work/<tag>_p○`（同じ修正を main にも取り込む）

`/bugfix`（通常のバグ報告起点）や `/fix`（テスト失敗の修復）とは**起点が違う**。こちらは本番 tag 起点の緊急対応。

## 入出力
- **入力**: 対象 tag（引数、または人に確認）と、人から受け取る修正内容
- **出力**: 2 本の draft PR（ファイル成果物は持たない）

## モード
`auto` は持たない。**本番への修正なので自走させない。**

次の 2 箇所で必ず確認を取る。どちらも成果物の内容確認ではなく、**本番に影響する操作**の確認：

1. **ブランチ作成前**（Step 2）— 本番 tag から release ブランチを切って push する
2. **実装着手前**（Step 3-1）— 明示的な指示があるまでコードを触らない

## ブランチ命名規則
`release/<base>_p<n>` と `work/<base>_p<n>`。`<base>` と `<n>` は対象 tag から決める：

| tag | base | n | 結果 |
|---|---|---|---|
| `v1.2.3` | `v1.2.3` | 1 | `release/v1.2.3_p1` / `work/v1.2.3_p1` |
| `v1.2.3_p1` | `v1.2.3` | 2 | `release/v1.2.3_p2` / `work/v1.2.3_p2` |
| `v1.2.3_p5` | `v1.2.3` | 6 | `release/v1.2.3_p6` / `work/v1.2.3_p6` |

正規表現 `^(.+)_p([0-9]+)$` にマッチすれば base = キャプチャ 1・n = キャプチャ 2 + 1、マッチしなければ base = tag そのまま・n = 1。**tag 側の `_p<数字>` は取り除いてから新しい番号を付ける**（`_p1_p2` にしない）。

## 進め方

### Step 1: 前提確認

**1-1 作業ツリー**

```
git status
```

未コミット・未 stash の変更があれば**中断する**：
> 未コミットの変更があります。先にコミットまたは stash してからやり直してください。

**1-2 対象 tag**

引数があればそれを使う。無ければ人に確認する（直近の tag を提示してよい）：

```
git tag --sort=-creatordate | head -n 10
```

確定したら、その tag がリモートに存在することを確認する：

```
git fetch --tags
git rev-parse --verify "refs/tags/<tag>"
```

失敗したら tag が存在しない旨を伝えて 1-2 に戻る。

**完了ゲート:** 作業ツリーがクリーンで、対象 tag が実在することを確認したか。

### Step 2: ブランチ準備

「ブランチ命名規則」で `release_branch` / `work_branch` を決め、**作成前に提示して承認を得る**：

> 以下のブランチを作成します。よろしいですか？
> - release: `<release_branch>`
> - work: `<work_branch>`
> - 起点tag: `<tag>`

承認後、tag から直接 release ブランチを切って push し、そこから work ブランチを切る：

```
git checkout -b <release_branch> refs/tags/<tag>
git push -u origin <release_branch>
git checkout -b <work_branch>
```

**既に同名のローカル／リモートブランチが存在する場合は中断**し、既存ブランチを使うのか別名にするのかを確認する。

**完了ゲート:** 2 本のブランチを作成し、work ブランチに立っているか。

### Step 3: 修正

**3-1 ヒアリング**

> **明示的な実装指示があるまで、コード変更は一切行わない。**

修正内容・対象ファイル・確認したい点を人に尋ねる。**ヒアリング中はファイルの読み取りや調査までは行ってよいが、編集・書き込みは禁止。** 「実装して」「修正お願い」など明示的な指示があったら 3-2 へ進む。

**3-2 実装**

指示に沿って修正する。複数ステップに分かれる場合は適宜進捗を共有する。

**3-3 コミット**

**`/commit` を起動する**（直接 `git commit` を実行しない。グローバル規約に従う）。hotfix では Conventional Commits の `fix` を基本タイプとして使う旨を `/commit` に伝える。

**完了ゲート:** 修正がコミットされたか。

### Step 4: PR 作成

**4-1 push**

```
git push -u origin <work_branch>
```

**4-2 本文の組み立て**

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

**4-3 2 本作成**

`gh label list` で利用可能なラベルを確認し、`hotfix` などの該当ラベルがあれば付与する。**どちらも draft で作る**（ready 化は人が判断する）。

release 宛：
```
gh pr create --base <release_branch> --head <work_branch> \
  --title "hotfix: <subject>" --body "<本文>" \
  --assignee @me --label "<該当ラベル>" --draft
```

main 宛（同じ work ブランチを head にして base だけ変える）：
```
gh pr create --base main --head <work_branch> \
  --title "hotfix: <subject> (to main)" --body "<本文>" \
  --assignee @me --label "<該当ラベル>" --draft
```

main 宛の本文には冒頭に次を加える：

```
> release宛PRと同じ修正をmainにも取り込むためのPRです。
> 対応release PR: #<release宛PRの番号>
```

**完了ゲート:** 2 本の draft PR が作成されたか。

### Step 5: 出力

次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。

✅ hotfix PR 作成完了
<何を修正した hotfix かを 1 行>
- <起点 tag / ブランチ名など 最大 3 行>
🔗 <release 宛 PR の URL>
🔗 <main 宛 PR の URL>

要確認:
- <本番影響で確認しきれていない点・動作確認チェックリストの未消化項目>

次の一手:
▶ CI を監視する：/watch-ci（2 本とも）

カードは**やったこと**（`✅` 〜 `🔗`）・**要確認**・**次の一手**の 3 ブロックに分ける。混ぜない。

- やったこと: 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（起点 tag・release / work ブランチ名）。PR 本文・diff の詳細は転記しない。🔗 行は **1 PR 1 行**で 2 行出す（行数上限は主要な結果にだけ課す）。
- 要確認: **本番に当てる修正**なので、確認しきれていない点を必ず挙げる（ローカルで再現できなかった条件・影響範囲の見立てなど）。無ければブロックごと省略する。
- 次の一手: 2 本とも監視が要るので 1 行にまとめる。

**中断時**: ヘッダを `⚠ hotfix 中断` に差し替え、一言サマリに中断理由（未コミットの変更がある・tag が存在しない・ブランチ名衝突など）、次の一手に復帰コマンドを書く（作成できた PR があれば 🔗 行は残す）。

## エラー処理
- **`git rev-parse --verify "refs/tags/<tag>"` が失敗** → tag が存在しない旨を伝え、Step 1-2 に戻る
- **ブランチ名が既存と衝突** → 中断し、既存ブランチを使うのか別名にするのかを確認する
- **`gh pr create` が失敗**（push 未完了など）→ `git push -u origin HEAD` で再 push 後にリトライ
- **main 宛 PR で差分が大きすぎる・コンフリクト多発** → 次の選択肢を提示して人に委ねる
  - main から別の work ブランチを切って cherry-pick する
  - release を main にマージする運用に切り替える

## 完了条件
release 宛・main 宛の 2 つの draft PR を作成し、両方の URL を報告したら完了。ready 化とマージは人が判断する。
