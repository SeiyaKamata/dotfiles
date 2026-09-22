---
name: test
description: 実装完了後にテスト・lint・フォーマットチェックなどの検証を実行し結果を報告する。impl完了後に使う。
allowed-tools: Read, Write, Edit, Bash
argument-hint: "<feature>"
---

# テストスキル

## 役割
実装後にテスト・lint・フォーマットチェックなどの検証を実行し、PASS / FAIL を判定して `.specs/<feature>/test-report.md` に記録する。
出力は毎回ファイルにリダイレクトし、exit code と失敗行だけを `tail` / `grep` で読む。
大量のログをメインコンテキストに載せないため。

## 判断が割れる点の扱い
途中でユーザーに質問も承認も求めない。
テストコマンドを判断できないときは推測で実行せず、Step 6 の中断カードで `CLAUDE.local.md` への記載を促す。
誤ったコマンドの PASS は最も危険な嘘になる。

## test-report.md のフォーマット
frontmatter は review・qa のレポートと共通の形式にする。

```markdown
---
feature: [feature]
branch: [Step 2 で確定したブランチ。detached なら none]
head: [Step 2 で確定した HEAD。40 文字、短縮しない]
ran_at: [書き出し時点の時刻。date +"%Y-%m-%dT%H:%M:%S%z" で取得]
fixed: false [常に false。/fix が修正を適用したときだけ true に書き換える]
count: [FAIL の連続回数。今回が FAIL かつ既存レポートも FAIL なら既存値 +1、それ以外は 1]
---

## テスト結果: [PASS / FAIL]

- 実行数: [N]
- 成功: [N]
- 失敗: [N]

### 失敗したテスト
[FAIL のときだけ。PASS なら節ごと省略]
- [テスト名]: [エラー内容]
```

## 進め方

### Step 1: 引数の確認
- `$ARGUMENTS[0]` が無ければ「使い方: /test <feature>」を表示して終了

### Step 2: 対象確定

カレントブランチが `<feature>` でなければ `git switch <feature>` を試みる。
- switch できた → そのまま続行
- `<feature>` が存在しない → 現在のブランチをそのまま採用する
  - PR を作らない運用で直接コミットしているとみなす
- 未コミットの変更があって switch できない → Step 6 の中断カードで報告する
  - stash などの作業ツリー操作はしない
- detached HEAD のまま `<feature>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を確定する。

### Step 3: テストコマンドの検出

次の順で採用し、決まった時点で以降は見ない。

1. `CLAUDE.local.md` の `## テスト` 節に記載があれば採用する
   - docker 等の実行ラッパ・複数コマンドの連結も可
2. 記載が無ければ、ビルド設定ファイルからテストフレームワークの標準コマンドを検出する
   - 複数該当すれば変更されたファイルに対応するものを選ぶ
   - 決まったら次回のために `CLAUDE.local.md` に `## テスト` 節として書き戻す
3. それでも決まらなければ Step 6 の中断カードへ進む

### Step 4: 実行・判定

```bash
<検出したコマンド> > .specs/<feature>/.test-output.log 2>&1; echo "exit:$?"
tail -n 50 .specs/<feature>/.test-output.log
```

必要なら `grep -E "FAIL|PASS|passed|failed"` も併用し、PASS / FAIL を判定する。

### Step 5: 記録

既存の `test-report.md` があれば判定と `count` を読み、「test-report.md のフォーマット」で `.specs/<feature>/test-report.md` に上書きする。

### Step 6: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### テスト実行中断` にし、1 行目に中断理由を書き、生成物の行を省き、次の一手は復帰に必要な操作だけにする。
テストコマンドを判断できずに中断したときは、要確認に探した場所を挙げ、次の一手を「`CLAUDE.local.md` の `## テスト` 節に実行コマンドを記載する」と「記載後に `/test <feature>` を再実行する」の 2 行にする。

```markdown
### テスト実行完了 — <PASS / FAIL>
<実行数と判定を 1 行>

生成物: `.specs/<feature>/test-report.md`

### 要確認
- <候補が複数あったテストコマンドの選択、スキップした対象など、判定に影響しうる判断>
<無ければこのブロックを省略>

### 次の一手
- レビューに進む: `/review <feature>`
  <FAIL なら `- 失敗を直す: /fix <feature>` に差し替える>
```
