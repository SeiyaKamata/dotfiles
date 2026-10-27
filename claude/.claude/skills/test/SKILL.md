---
name: test
description: 実装完了後にテスト・lint・フォーマットチェックなどの検証を実行し結果を報告する。impl完了後に使う。
allowed-tools: Read, Write, Edit, Bash
---

# テストスキル

## 役割
実装後にテスト・lint・フォーマットチェックなどの検証を実行し、PASS / FAIL を判定して `.specs/test-report.jsonc` に記録する。
出力は毎回ファイルにリダイレクトし、exit code と失敗行だけを `tail` / `grep` で読む。
大量のログをメインコンテキストに載せないため。

## 判断が割れる点の扱い
途中でユーザーに質問も承認も求めない。
テストコマンドを判断できないときは推測で実行せず、Step 5 の中断報告で `CLAUDE.local.md` への記載を促す。
誤ったコマンドの PASS は最も危険な嘘になる。

## test-report.jsonc のフォーマット
`/fix` が読む失敗の内訳と、人が読む HTML の元データを兼ねる。
毎回 `.specs/test-report.jsonc` に上書きし、同じ内容から `.specs/test-report.html` を生成する。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

```jsonc
{
  "branch": "[Step 1 で確定したブランチ。detached なら none]",
  "head": "[Step 1 で確定した HEAD。40 文字、短縮しない]",
  "ran_at": "[書き出し時点の時刻。date +\"%Y-%m-%dT%H:%M:%S%z\" で取得]",
  "fixed": false, // 常に false。/fix が修正を適用したときだけ true に書き換える
  "count": 1, // FAIL の連続回数。今回が FAIL かつ既存レポートも FAIL なら既存値 +1、それ以外は 1
  "verdict": "[PASS / FAIL]",
  "total": 0,
  "passed": 0,
  "failed": 0,
  "failures": [
    { "name": "[テスト名]", "error": "[エラー内容]" }
  ] // FAIL のときだけ並べる。PASS は空配列
}
```

## 進め方

### Step 1: 対象確定

カレントブランチが実装ブランチ `<branch>` でなければ `git switch <branch>` を試みる。
実装ブランチ名 `<branch>` は `.specs/feature.jsonc` の `branch_name` にする。
- switch できた → そのまま続行
- `<branch>` が存在しない → 現在のブランチをそのまま採用する
  - PR を作らない運用で直接コミットしているとみなす
- 未コミットの変更があって switch できない → Step 5 の中断報告で報告する
  - stash などの作業ツリー操作はしない
- detached HEAD のまま `<branch>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を確定する。

### Step 2: テストコマンドの検出

次の順で採用し、決まった時点で以降は見ない。

1. `CLAUDE.local.md` の `## テスト` 節に記載があれば採用する
   - docker 等の実行ラッパ・複数コマンドの連結も可
2. 記載が無ければ、ビルド設定ファイルからテストフレームワークの標準コマンドを検出する
   - 複数該当すれば変更されたファイルに対応するものを選ぶ
   - 決まったら次回のために `CLAUDE.local.md` に `## テスト` 節として書き戻す
3. それでも決まらなければ Step 5 の中断報告へ進む

### Step 3: 実行・判定

```bash
<検出したコマンド> > .specs/.test-output.log 2>&1; echo "exit:$?"
tail -n 50 .specs/.test-output.log
```

必要なら `grep -E "FAIL|PASS|passed|failed"` も併用し、PASS / FAIL を判定する。

### Step 4: 記録

既存の `test-report.jsonc` があれば判定と `count` を読み、「test-report.jsonc のフォーマット」で `.specs/test-report.jsonc` に上書きする。

### Step 5: 出力

完了報告と中断報告を、見出しもコードフェンスも付けずに出力して終了する。

完了報告の形は次のとおり。
- 1 行目に、実行数と `PASS` か `FAIL` の判定を書く
- 詳細は `.specs/test-report.html` で確認する旨を書く
- 要確認があれば、候補が複数あったテストコマンドの選択やスキップした対象など、判定に影響しうる判断を `要確認: <内容>` で 1 件 1 行ずつ続ける。無ければ書かない
- 最後の行に次の一手を書く。PASS なら `次は /review`、FAIL なら `失敗を直すなら /fix`

中断報告は、1 行目に中断理由を書き、続けて復帰に必要な操作を書く。
テストコマンドを判断できずに中断したときは、探した場所を `要確認: <探した場所>` で 1 行に挙げ、続けて「`CLAUDE.local.md` の `## テスト` 節に実行コマンドを記載し、記載後に `/test` を再実行する」と書く。
