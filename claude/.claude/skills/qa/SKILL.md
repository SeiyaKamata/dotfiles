---
name: qa
description: コードレビュー後にブラウザで動作確認する最終受け入れゲート。/review の後に使う。
allowed-tools: Read, Write, Edit, Bash(git *), Bash(date *), Bash(mkdir *), Bash(cp *), Agent
disallowed-tools: mcp__playwright__*
---

# QAスキル

## 役割
アプリを実起動した状態でブラウザ操作をなぞり、要件どおり動くかを確認する最終受け入れゲート。
ブラウザ操作は `browser-tester` に委譲し、自分は検証環境の起動と停止・シナリオの受け渡し・結果の集約だけを担う。
`disallowed-tools` の名前空間は `browser-tester` の `tools` が指す Playwright MCP の名前空間と対にし、片方を変えたら両方を揃える。

## 判断が割れる点の扱い
途中でユーザーに質問も承認要求もしない。
QA に必要なデータが足りなければ追加して完遂を目指す。QA 環境は専用なので不要なデータが増えてよい。
シナリオに書かれておらず判断で補った点は、`open_questions` に書く。

## 環境の扱い
環境は落ちている前提で始め、検証が終わったら常に停止コマンドで片付ける。
「自分が起動した分だけ停止する」判定は追跡を一度誤ると環境が残るので採らず、停止コマンドは無条件に呼ぶ。

## qa-report.jsonc のフォーマット

`/fix` が読む失敗の内訳と、人が読む HTML の元データを兼ねる。
毎回 `$CLAUDE_WORK_DIR/qa-report.jsonc` に上書きし、同じ内容から `$CLAUDE_WORK_DIR/qa-report.html` を生成する。
`count` は非 PASS の連続回数で、今回も前回も非 PASS なら前回値 +1、それ以外は 1 にする。
`fixed` は常に `false` を書き、`true` にするのは `/fix` だけ。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

`scenarios` は全シナリオを 1 件ずつ並べる。
スクリーンショットは `$CLAUDE_WORK_DIR/img/qa-Q<n>.png` に固定名で置き、`screenshot` には `$CLAUDE_WORK_DIR/` からの相対パスで書く。
サマリの件数は HTML 生成が `scenarios` から数えるので書かない。

```jsonc
{
  "branch": "[カレントブランチ。取得不能時は none]",
  "head": "[git rev-parse HEAD。取得不能時は none]",
  "ran_at": "[書き出し時点の時刻。date +\"%Y-%m-%dT%H:%M:%S%z\" で取得]",
  "fixed": false,
  "count": 1, // 今回が初回の非 PASS なら 1。前回も非 PASS なら前回値 +1
  "verdict": "[PASS / FAIL / BLOCKED。BLOCKED は環境を起動できないか到達できず検証未実施]",
  "open_questions": ["[判断で補った点、停止コマンドの失敗。無ければ空配列]"],
  "scenarios": [
    {
      "id": "Q1",
      "title": "[タイトル]",
      "result": "[pass / fail]",
      "cause": "[fail のときだけ原因 1 行。pass は空文字]",
      "screenshot": "img/qa-Q1.png",
      "requirements": [1]
    }
  ]
}
```

`requirements` は `plan.jsonc` の `scenarios.local` のシナリオが持つ要件番号で、`fail` のシナリオだけ書く。
`screenshot` は全シナリオに書く。
`BLOCKED` のときとローカルシナリオが 0 件のときは、`scenarios` を空配列にする。

## 進め方

### Step 1: 対象の確定

- `$CLAUDE_WORK_DIR/plan.jsonc` が無いか `scenarios` が無ければ、結果に理由を書いて終了する

カレントブランチが実装ブランチ `<branch>` でなければ `git switch <branch>` を試みる。
実装ブランチ名 `<branch>` は `$CLAUDE_WORK_DIR/feature.jsonc` の `branch_name` にする。
- switch できた → そのまま続行
- `<branch>` が存在しない → 現在のブランチをそのまま採用する
- 未コミットの変更があって switch できない → 結果に理由を書いて終了する。stash などの作業ツリー操作はしない
- detached HEAD のまま `<branch>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を確定する。
`plan.jsonc` の `scenarios.local` が空なら、ブラウザで検証するものが無いので環境を起動せず、Step 2〜5 と Step 7 を飛ばして Step 6 でシナリオ数 0 の PASS を書き出す。

### Step 2: 起動コマンドと停止コマンドの確認

起動コマンドと停止コマンドは `CLAUDE.local.md` の `## 環境起動` 節から採用する。
記載が無ければ推測せず、結果に記載を促す旨を書いて終了する。

### Step 3: 起動する

起動コマンドを実行する。
長時間ブロッキングしうるので `run_in_background` で実行する。

### Step 4: 起動失敗の扱い

起動できないときは BLOCKED とし、Step 7 で停止してから結果に理由を書いて終了する。
ベース URL への到達性は Bash で確認せず、Step 5 の委譲先が最初に確かめる。

### Step 5: シナリオ実行の委譲

`local` の全シナリオを 1 回の委譲で `browser-tester` に渡す。
ブラウザセッションを共有し、自分のコンテキスト消費を抑えるため。
`deploy` と `excluded` は渡さない。

渡すのはベース URL、`local` の配列そのまま、git 管理外のスクリーンショット保存先ディレクトリの 3 つ。
受け取るのは `Q<n>: pass|fail` と原因 1 行とスクショパスの配列と、全シナリオ通しの録画パス `video:` だけ。
ベース URL に到達できないと返ってきたときはシナリオ未実施なので BLOCKED とし、Step 7 で停止してから結果に理由を書いて終了する。再委譲はしない。

### Step 6: 書き出し

- 結果で `$CLAUDE_WORK_DIR/plan.jsonc` の `scenarios.local` の `done` を更新する。pass のシナリオは `true`、fail のシナリオは `false` にする。
  - Edit で、`"id": "Q<n>"` の行から `"done"` の行までを old_str にして、1 シナリオずつ置換する。`deploy` の `done` には触れない
- 既存の `qa-report.jsonc` があれば上書き前に前回の判定と `count` を読む
- `mkdir -p $CLAUDE_WORK_DIR/img` のあと、委譲先が返したスクリーンショットを `cp <返ってきたパス> $CLAUDE_WORK_DIR/img/qa-Q<n>.png` で全シナリオ分コピーする
  - 委譲先は Playwright の書き込み制限を受けない保存先に書くので、`$CLAUDE_WORK_DIR/` へはこちらがコピーする
- 録画パスが `none` でなければ `cp <video パス> $CLAUDE_WORK_DIR/img/qa.webm` でコピーする
- 「qa-report.jsonc のフォーマット」で `$CLAUDE_WORK_DIR/qa-report.jsonc` を書き出す

### Step 7: 環境停止

Step 2 の停止コマンドを実行する。
停止に失敗しても判定は確定しているので中断せず、`open_questions` に書く。
FAIL の原因調査で環境が要るなら `/fix` 側で起動し直す。

### Step 8: 出力

次を出して終了する。
- 結果: シナリオ数と `PASS` か `FAIL`
- 詳細: `$CLAUDE_WORK_DIR/qa-report.html`
- 次の一手: PASS なら `/commit`、FAIL なら `/fix`

ローカルシナリオが 0 件の PASS は、結果を「ブラウザ検証対象なし」にする。
