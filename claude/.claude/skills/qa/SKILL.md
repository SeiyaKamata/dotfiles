---
name: qa
description: コードレビュー後にブラウザで動作確認する最終受け入れゲート。/review の後に使う。
allowed-tools: Read, Write, Edit, Bash(git *), Bash(chworktree *), Bash(date *), Bash(mkdir *), Bash(cp *), Bash(python3 ~/.claude/skills/_report/render.py *), Agent
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
シナリオに書かれておらず判断で補った点は、完了カードの要確認に出す。

## 環境の扱い
環境は落ちている前提で始め、開始時点の状態に関係なく検証が終わったら常に `chworktree stop` で片付ける。
「自分が起動した分だけ停止する」判定は追跡を一度誤ると環境が残るので採らず、`chworktree stop` は未起動でも安全なので無条件に呼ぶ。

## qa-report.jsonc のフォーマット

`/fix` が読む失敗の内訳と、人が読む HTML の元データを兼ねる。
毎回 `.specs/qa-report.jsonc` に上書きし、同じ内容から `.specs/qa-report.html` を生成する。
`count` は非 PASS の連続回数で、今回も前回も非 PASS なら前回値 +1、それ以外は 1 にする。
`fixed` は常に `false` を書き、`true` にするのは `/fix` だけ。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

`scenarios` は全シナリオを 1 件ずつ並べる。
スクリーンショットは `.specs/img/qa-Q<n>.png` に固定名で置き、`screenshot` には `.specs/` からの相対パスで書く。
サマリの件数は HTML 生成が `scenarios` から数えるので書かない。

```jsonc
{
  "branch": "[カレントブランチ。取得不能時は none]",
  "head": "[git rev-parse HEAD。取得不能時は none]",
  "ran_at": "[書き出し時点の時刻。date +\"%Y-%m-%dT%H:%M:%S%z\" で取得]",
  "fixed": false,
  "count": 1, // 今回が初回の非 PASS なら 1。前回も非 PASS なら前回値 +1
  "verdict": "[PASS / FAIL / BLOCKED。BLOCKED は環境を起動できないか到達できず検証未実施]",
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

`requirements` は `qa.jsonc` のシナリオが持つ要件番号で、`fail` のシナリオだけ書く。
`screenshot` は全シナリオに書く。
`BLOCKED` のときとローカルシナリオが 0 件のときは、`scenarios` を空配列にする。

## 進め方

### Step 1: 対象の確定

- `.specs/qa.jsonc` が無ければ Step 8 の中断カードで報告して終了

カレントブランチが実装ブランチ `<branch>` でなければ `git switch <branch>` を試みる。
実装ブランチ名 `<branch>` は `.specs/feature.jsonc` の `branch_name` にする。
- switch できた → そのまま続行
- `<branch>` が存在しない → 現在のブランチをそのまま採用する
- 未コミットの変更があって switch できない → Step 8 の中断カードで報告する。stash などの作業ツリー操作はしない
- detached HEAD のまま `<branch>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を確定する。
`qa.jsonc` の `local` が空なら、ブラウザで検証するものが無いので環境を起動せず、Step 2〜5 と Step 7 を飛ばして Step 6 でシナリオ数 0 の PASS を書き出す。

### Step 2: 起動プロファイルと稼働状態の確認

起動プロファイルは `CLAUDE.local.md` の `## 環境起動` 節から採用する。
記載が無ければ推測せず、Step 8 の中断カードで記載を促して終了する。

```
chworktree status
```

到達性を起動済みの証拠にしない。
compose プロジェクトは 1 リポジトリに 1 つしかなく、別 worktree の環境が起動していてもベース URL には到達できてしまうので、到達できることを根拠に進むと別ブランチのコードを PASS にする。

### Step 3: 状態に応じて起動する

`git rev-parse --show-toplevel` で得た自分の worktree と `chworktree status` を照合して分岐する。

| 稼働状態 | 動作 |
|---|---|
| 何も起動していない | `chworktree <profile>` で起動する |
| 自分の worktree が起動中 | そのまま使う |
| 別 worktree が起動中 | `chworktree -loop <profile>` で空くのを待って切り替える |
| 複数 worktree が同居 | `chworktree stop` で全停止してから `chworktree <profile>` で起動し直す |

`-loop` は長時間ブロッキングしうるので `run_in_background` で実行する。

### Step 4: 起動失敗の扱い

起動できない・`-loop` が空かないときは BLOCKED とし、Step 7 で停止してから Step 8 の中断カードで報告する。
ベース URL への到達性は Bash で確認せず、Step 5 の委譲先が最初に確かめる。

### Step 5: シナリオ実行の委譲

`local` の全シナリオを 1 回の委譲で `browser-tester` に渡す。
ブラウザセッションを共有し、自分のコンテキスト消費を抑えるため。
`deploy` と `excluded` は渡さない。

渡すのはベース URL、`local` の配列そのまま、git 管理外のスクリーンショット保存先ディレクトリの 3 つ。
受け取るのは `Q<n>: pass|fail` と原因 1 行とスクショパスの配列と、全シナリオ通しの録画パス `video:` だけ。
ベース URL に到達できないと返ってきたときはシナリオ未実施なので BLOCKED とし、Step 7 で停止してから Step 8 の中断カードで報告する。再委譲はしない。

### Step 6: 書き出し

- 結果で `.specs/qa.jsonc` の `local` の `done` を更新する。pass のシナリオは `true`、fail のシナリオは `false` にする。
  - Edit で、`"id": "Q<n>"` の行から `"done"` の行までを old_str にして、1 シナリオずつ置換する。`deploy` の `done` には触れない
  - 続けて `python3 ~/.claude/skills/_report/render.py .specs/qa.jsonc` で `.specs/qa.html` を作り直す
- 既存の `qa-report.jsonc` があれば上書き前に前回の判定と `count` を読む
- `mkdir -p .specs/img` のあと、委譲先が返したスクリーンショットを `cp <返ってきたパス> .specs/img/qa-Q<n>.png` で全シナリオ分コピーする
  - 委譲先は Playwright の書き込み制限を受けない保存先に書くので、`.specs/` へはこちらがコピーする
- 録画パスが `none` でなければ `cp <video パス> .specs/img/qa.webm` でコピーする
- 「qa-report.jsonc のフォーマット」で `.specs/qa-report.jsonc` を書き出す
- `python3 ~/.claude/skills/_report/render.py .specs/qa-report.jsonc` で `.specs/qa-report.html` を生成する
  - 生成に失敗したら `.jsonc` は残し、生成物から `.html` を省いて要確認に失敗の内容を載せる

### Step 7: 環境停止

```
chworktree stop
```

停止に失敗しても判定は確定しているので中断せず、要確認に載せる。
FAIL の原因調査で環境が要るなら `/fix` 側で起動し直す。

### Step 8: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
見出し末尾の判定は PASS か FAIL で、ローカルシナリオ 0 件の PASS は 1 行目に「ブラウザ検証対象なし」と書く。
中断時は BLOCKED を含めて見出しを `### QA 中断` にし、1 行目に中断理由を書き、生成物の行は未生成なら省き、次の一手は `/qa` にする。プロファイル未検出なら `CLAUDE.local.md` に `## 環境起動` 節を 1 行で書く旨を先に置く。

```markdown
### QA 完了 — <PASS / FAIL>
<シナリオ数と判定を 1 行>

生成物:
- `.specs/qa.jsonc`
- `.specs/qa-report.jsonc`
- `.specs/qa-report.html`
- `.specs/img/qa.webm`

### 要確認
- <シナリオに書かれておらず判断で補った点> 該当: Q<n>
- <chworktree stop に失敗した旨>

### 次の一手
- コミットする: `/commit`
- 失敗を直す: `/fix`
```

要確認は該当する行だけを出し、無ければブロックごと省略する。
