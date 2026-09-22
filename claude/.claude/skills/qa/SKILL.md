---
name: qa
description: コードレビュー後にブラウザで動作確認する最終受け入れゲート。/review の後に使う。
allowed-tools: Read, Write, Edit, Bash(git *), Bash(swws *), Bash(curl *), Agent
disallowed-tools: mcp__playwright__*
argument-hint: "<feature>"
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
環境は落ちている前提で始め、開始時点の状態に関係なく検証が終わったら常に `swws stop` で片付ける。
「自分が起動した分だけ停止する」判定は追跡を一度誤ると環境が残るので採らず、`swws stop` は未起動でも安全なので無条件に呼ぶ。

## qa-report.md のフォーマット

`/fix` が読む失敗の内訳で、毎回 `.specs/<feature>/qa-report.md` に上書きする。
`count` は非 PASS の連続回数で、今回も前回も非 PASS なら前回値 +1、それ以外は 1 にする。
`fixed` は常に `false` を書き、`true` にするのは `/fix` だけ。

```markdown
---
feature: [feature]
branch: [カレントブランチ。取得不能時は none]
head: [git rev-parse HEAD。取得不能時は none]
ran_at: [書き出し時点の ISO 8601]
fixed: false
count: [非 PASS の連続回数]
---

# QA結果: [機能名]

## サマリ
- 判定: [PASS / FAIL / BLOCKED。BLOCKED は環境を起動できず検証未実施]
- シナリオ数 / pass / fail: [N / N / N]

## 失敗シナリオ
[FAIL のときだけ。無ければ節ごと省略]
- Q[n] [タイトル]: [原因]。スクショ: [path]
  - _Requirements: [N]_
```

## 進め方

### Step 1: 対象の確定

- `$ARGUMENTS[0]` が無ければ「使い方: /qa <feature>」を表示して終了
- `.specs/<feature>/qa.md` が無ければ Step 8 の中断カードで報告して終了

カレントブランチが実装ブランチ `<feature>` でなければ `git switch <feature>` を試みる。
- switch できた → そのまま続行
- `<feature>` が存在しない → 現在のブランチをそのまま採用する
- 未コミットの変更があって switch できない → Step 8 の中断カードで報告する。stash などの作業ツリー操作はしない
- detached HEAD のまま `<feature>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を確定する。
`qa.md` の `## ローカルQAシナリオ` が無いか 0 件なら、ブラウザで検証するものが無いので環境を起動せず、Step 2〜5 と Step 7 を飛ばして Step 6 でシナリオ数 0 の PASS を書き出す。

### Step 2: 起動プロファイルと稼働状態の確認

起動プロファイルは `CLAUDE.local.md` の `## 環境起動` 節から採用する。
記載が無ければ推測せず、Step 8 の中断カードで記載を促して終了する。

```
swws status
```

到達性を起動済みの証拠にしない。
compose プロジェクトは 1 リポジトリに 1 つしかなく、別 worktree の環境が起動していてもベース URL には到達できてしまうので、`curl` が通ることを根拠に進むと別ブランチのコードを PASS にする。

### Step 3: 状態に応じて起動する

`git rev-parse --show-toplevel` で得た自分の worktree と `swws status` を照合して分岐する。

| 稼働状態 | 動作 |
|---|---|
| 何も起動していない | `swws <profile>` で起動する |
| 自分の worktree が起動中 | そのまま使う |
| 別 worktree が起動中 | `swws -loop <profile>` で空くのを待って切り替える |
| 複数 worktree が同居 | `swws stop` で全停止してから `swws <profile>` で起動し直す |

`-loop` は長時間ブロッキングしうるので `run_in_background` で実行する。

### Step 4: 到達性の確認

`curl -sSf <baseURL>` でベース URL に到達できるか、数秒間隔で再確認する。
起動できない・到達しない・`-loop` が空かないときは BLOCKED とし、Step 7 で停止してから Step 8 の中断カードで報告する。

### Step 5: シナリオ実行の委譲

`## ローカルQAシナリオ` の全シナリオを 1 回の委譲で `browser-tester` に渡す。
ブラウザセッションを共有し、自分のコンテキスト消費を抑えるため。
`## デプロイ環境QAシナリオ` と `## 自動QA対象外` は渡さない。

渡すのはベース URL、`## ローカルQAシナリオ` のブロックそのまま、git 管理外のスクリーンショット保存先ディレクトリの 3 つ。
受け取るのは `Q<n>: pass|fail` と原因 1 行とスクショパスの配列だけ。

### Step 6: 書き出し

- 結果で `.specs/<feature>/qa.md` の `## ローカルQAシナリオ` のチェックを更新する。pass は `[x]`、fail は `[ ]` のまま
- 既存の `qa-report.md` があれば上書き前に前回の判定と `count` を読む
- 「qa-report.md のフォーマット」で `.specs/<feature>/qa-report.md` を書き出す

### Step 7: 環境停止

```
swws stop
```

停止に失敗しても判定は確定しているので中断せず、要確認に載せる。
FAIL の原因調査で環境が要るなら `/fix` 側で起動し直す。

### Step 8: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
見出し末尾の判定は PASS か FAIL で、ローカルシナリオ 0 件の PASS は 1 行目に「ブラウザ検証対象なし」と書く。
中断時は BLOCKED を含めて見出しを `### QA 中断` にし、1 行目に中断理由を書き、生成物の行は未生成なら省き、次の一手は `/qa <feature>` にする。プロファイル未検出なら `CLAUDE.local.md` に `## 環境起動` 節を 1 行で書く旨を先に置く。

```markdown
### QA 完了 — <PASS / FAIL>
<シナリオ数と判定を 1 行>

生成物:
- `.specs/<feature>/qa.md`
- `.specs/<feature>/qa-report.md`

### 要確認
- <シナリオに書かれておらず判断で補った点> 該当: Q<n>
- <swws stop に失敗した旨>

### 次の一手
- コミットする: `/commit`
- 失敗を直す: `/fix <feature>`
```

要確認は該当する行だけを出し、無ければブロックごと省略する。
