---
name: hotfix
description: 調査済みのバグ報告を受け、本番tagからreleaseブランチとworkブランチを切って修正し、release宛・main宛の2つのPRを作成する。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Skill
argument-hint: "<feature> [tag]"
---

# hotfix スキル

## 役割
`/bughunt` が原因を絞り込んだバグを、本番環境で動いている tag に当てる。
tag から hotfix の release ブランチ・work ブランチを切り、修正を実装して 2 つの PR を作成する。

- `release/<base>_p<n>` ← `work/<base>_p<n>`。本番へ当てる
- `main` ← `work/<base>_p<n>`。同じ修正を main にも取り込む

`<base>` と `<n>` の決め方は下記「ブランチ命名規則」に従う。

原因調査は行わない。`/bughunt` に委ねる。
`bug-report.md` が無ければ調査工程へ差し戻して中断する。判定は Step 2 で行う。
本番へ当てる修正で原因の記録を残すため。

`/bughunt` から見た修正の当て先の分岐にあたる。
通常ルートは `/bughunt` → `/fix`。テストを green にする最小修正。
本番 tag へ当てるならこちら。
`/fix` は本番緊急対応には重いため呼ばない。

## 入出力
- 入力:
  - `.specs/<feature>/bug-report.md`。`/bughunt` の調査結果で必須
  - 対象 tag。引数、または人に確認
- 出力: 2 本の draft PR。ファイル成果物は持たない

## 対話方針
本番への修正なので人が起動する。
起動後は途中で承認を取らずフロー通り進める。
止まる条件は「エラー処理」に従う。

## ブランチ命名規則
`release/<base>_p<n>` と `work/<base>_p<n>`。
`<base>` と `<n>` は対象 tag から決める：

| tag | base | n | 結果 |
|---|---|---|---|
| `v1.2.3` | `v1.2.3` | 1 | `release/v1.2.3_p1` / `work/v1.2.3_p1` |
| `v1.2.3_p1` | `v1.2.3` | 2 | `release/v1.2.3_p2` / `work/v1.2.3_p2` |
| `v1.2.3_p5` | `v1.2.3` | 6 | `release/v1.2.3_p6` / `work/v1.2.3_p6` |

正規表現 `^(.+)_p([0-9]+)$` にマッチすれば base = キャプチャ 1・n = キャプチャ 2 + 1、マッチしなければ base = tag そのまま・n = 1。
tag 側の `_p<数字>` は取り除いてから新しい番号を付ける。`_p1_p2` にしない。

## PR タイトル命名規則
件名の作り方は `/sync`「呼ばれ方」2-1 と同じ方式。
hotfix は `.specs/<feature>/` を経由せず本番 tag から直接ブランチを切るので、常にコミットメッセージから主題を作る。work ブランチのコミット列が揃っている。
固定 prefix `【鎌田QA】` を付けるところまでは共通で、hotfix はさらに先頭へ当て先を示す `[release]` / `[main]` を付ける：

- release 宛: `[release]【鎌田QA】<subject>`
- main 宛: `[main]【鎌田QA】<subject>`

`<subject>` は release 宛・main 宛で同じ修正なので共通のものを使う。

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]`、feature が未指定なら「使い方: /hotfix <feature> [tag]」を表示して終了
- `$ARGUMENTS[1]` があれば対象 tag の候補として使う

### Step 2: バグ報告確認

`.specs/<feature>/bug-report.md` を読む。
存在しない場合は中断する。Step 13 の中断カードで `/bughunt` を案内する。
存在しても「再現可否: 再現できず」なら同じく中断する。原因が絞り込めていない状態で本番へ当てる修正を始めない。

読み取る項目は、症状・再現手順・疑わしい箇所 `<path>:<line>`・想定する修正範囲・回帰テストの観点。
これが Step 6 の照合と Step 7 の実装、Step 11 の PR 本文の材料になる。

**完了ゲート:** 再現済みの `bug-report.md` を読み込んだか。

### Step 3: 作業ツリー確認

```
git status
```

未コミット・未 stash の変更があれば中断する：
> 未コミットの変更があります。
> 先にコミットまたは stash してからやり直してください。

**完了ゲート:** 作業ツリーがクリーンであることを確認したか。

### Step 4: 対象tag確認

引数があればそれを使う。
無ければ人に確認する。直近の tag を提示してよい：

```
git tag --sort=-creatordate | head -n 10
```

確定したら、その tag がリモートに存在することを確認する：

```
git fetch --tags
git rev-parse --verify "refs/tags/<tag>"
```

失敗したら tag が存在しない旨を伝えて Step 4 に戻る。

**完了ゲート:** 対象 tag が実在することを確認したか。

### Step 5: ブランチ準備

「ブランチ命名規則」で `release_branch` / `work_branch` を決める。
tag から直接 release ブランチを切って push し、そこから work ブランチを切る：

```
git checkout -b <release_branch> refs/tags/<tag>
git push -u origin <release_branch>
git checkout -b <work_branch>
```

既に同名のローカル／リモートブランチが存在する場合は中断し、既存ブランチを使うのか別名にするのかを確認する。

**完了ゲート:** 2 本のブランチを作成し、work ブランチに立っているか。

### Step 6: tagとの照合

`/bughunt` の調査は別のブランチ、通常 `main` で行われているため、その所見が起点 tag のコードにも当てはまるとは限らない。
work ブランチ、つまり tag のコードに立った状態で、`bug-report.md` の「疑わしい箇所」を 1 件ずつ読んで確認する：

| 照合結果 | 進み先 |
|---|---|
| 該当箇所が同じ内容で存在する | 4-2 へ |
| 存在するが差分がある | 差分を人に提示し、想定する修正範囲が通用するかを確認してから 4-2 へ |
| パス・関数ごと存在しない | 調査ベースがずれている。`bug-report.md` を根拠にせず、**この work ブランチ上で `/bughunt <feature>` を回し直す**ことを勧めて中断する |

**完了ゲート:** tag のコードで疑わしい箇所を照合したか。

### Step 7: 実装

`bug-report.md` の「想定する修正範囲」をもとに修正方針を組み立て、そのまま実装に入る。

修正は症状を止める最小限にとどめる。
リファクタ・周辺の改善は混ぜず、気づいたことは `CLAUDE.md`「訂正・摩擦の扱い」に従って切り出す。

**完了ゲート:** 修正を実装したか。

### Step 8: コミット

`/commit` を起動する。直接 `git commit` は実行しない。
グローバル規約に従う。
hotfix では Conventional Commits の `fix` を基本タイプとして使う旨を `/commit` に伝える。

**完了ゲート:** 修正がコミットされたか。

### Step 9: push

```
git push -u origin <work_branch>
```

### Step 10: タイトルの組み立て

「PR タイトル命名規則」に従い、work ブランチのコミット列から `<subject>` を作る。

### Step 11: 本文の組み立て

`bug-report.md` の内容を材料にする。背景は症状と疑わしい箇所から、動作確認は回帰テストの観点から作る：

```
## Summary
（修正内容の概要を1〜3行）

## 背景
（症状と、なぜhotfixが必要だったか）

## 変更内容
（変更ファイル・変更点を箇条書き）

## 起点tag
<tag>

## 動作確認
- [ ] ...
```

### Step 12: PR作成

`gh label list` で利用可能なラベルを確認し、`hotfix` などの該当ラベルがあれば付与する。
どちらも draft で作る。ready 化は人が判断する。

release 宛：
```
gh pr create --base <release_branch> --head <work_branch> \
  --title "[release]【鎌田QA】<subject>" --body "<本文>" \
  --assignee @me --label "<該当ラベル>" --draft
```

main 宛。同じ work ブランチを head にして base だけ変える：
```
gh pr create --base main --head <work_branch> \
  --title "[main]【鎌田QA】<subject>" --body "<本文>" \
  --assignee @me --label "<該当ラベル>" --draft
```

main 宛の本文には冒頭に次を加える：

```
> release宛PRと同じ修正をmainにも取り込むためのPRです。
> 対応release PR: #<release宛PRの番号>
```

**完了ゲート:** 2 本の draft PR が作成されたか。

### Step 13: 出力

次の完了カードを、コードフェンス自体は出さずに中身だけそのまま出力して終了する。
カードの前後に作業サマリ・所感・補足を足さない。

```markdown
### hotfix PR 作成完了
<何を修正した hotfix かを 1 行>
- <起点 tag / ブランチ名など 最大 3 行>

生成物:
- <release 宛 PR の URL>
- <main 宛 PR の URL>

### 要確認
- <本番影響で確認しきれていない点・動作確認チェックリストの未消化項目>

### 次の一手
- CI を監視する: `/watch-ci`（2 本とも）
```

カードはやったこと・要確認・次の一手の 3 ブロックに分ける。
混ぜない。

- やったこと: 一言サマリは 1 行。
  主要な結果は `- ` の箇条書きで最大 3 行。起点 tag・release / work ブランチ名。
  PR 本文・diff の詳細は転記しない。
  `bug-report.md` は入力なので生成物の行は出さない。
  生成物は 1 PR 1 行で 2 行出す。行数上限は主要な結果にだけ課す。
- 要確認: 本番に当てる修正なので、確認しきれていない点を必ず挙げる。ローカルで再現できなかった条件・影響範囲の見立てなど。
  Step 6 の照合で tag と `bug-report.md` に差分があった場合は必ずここに書く。
  無ければブロックごと省略する。
- 次の一手: 2 本とも監視が要るので 1 行にまとめる。

中断時: ヘッダを `### hotfix 中断` に差し替え、一言サマリに中断理由、次の一手に復帰コマンドを書く。作成できた PR があれば生成物の行は残す。
中断理由と次の一手の対応は「エラー処理」に従う。

原因が定まらないまま実装へ進む道は出さない。

## エラー処理
- **`.specs/<feature>/bug-report.md` が無い・再現できず** → 中断し `/bughunt` へ差し戻す。Step 2。
  次の一手: `- まず原因を調べる: /bughunt <feature>`
- **`git rev-parse --verify "refs/tags/<tag>"` が失敗** → tag が存在しない旨を伝え、Step 4 に戻る。
  次の一手: 復帰 `- 復帰: /hotfix <feature> [tag]`
- **ブランチ名が既存と衝突** → 中断し、既存ブランチを使うのか別名にするのかを確認する。
  次の一手: 解消手順と `- 復帰: /hotfix <feature> [tag]`
- **tag のコードに疑わしい箇所が存在しない** → 中断し、work ブランチ上での `/bughunt` 再実行を勧める。Step 6。
  次の一手: `- tag のコードで調べ直す: /bughunt <feature>`。work ブランチに立ったまま実行する旨を添える
- **未コミットの変更がある** → 中断し解消を促す。
  次の一手: 解消手順と `- 復帰: /hotfix <feature> [tag]`
- **`gh pr create` が失敗**。push 未完了など → `git push -u origin HEAD` で再 push 後にリトライ
- **main 宛 PR で差分が大きすぎる・コンフリクト多発** → 次の選択肢を提示して人に委ねる
  - main から別の work ブランチを切って cherry-pick する
  - release を main にマージする運用に切り替える

## 完了条件
release 宛・main 宛の 2 つの draft PR を作成し、両方の URL を報告したら完了。
ready 化とマージは人が判断する。
