---
name: watch-ci
description: PRのCIを監視し、完了後に結果に応じて分岐対応する。push後やPR作成後に使う。
argument-hint: "[PR番号 | <feature>]"
allowed-tools: Bash(gh *), Bash(git *), Agent
---

# CI監視スキル

## 役割
PR の CI が完了するまで監視し、結果を判定して次のアクションを提示する。
CI 失敗時はログを取得して要点に畳む。
ログ本体はカードに載せない。

**Ready for review への切り替えは行わない。**
draft のまま完了とし、完了カードで `gh pr ready` を案内する。
Ready for review はレビュアーに通知が飛ぶ外向きの操作で、しかも取り消しても通知は戻らない。
このスキルは監視と報告までを担い、外向きの操作は人が明示的に実行する。

## 入出力
- **入力**: 対象 PR。
  引数の PR 番号、引数の feature 名、またはカレントブランチから導出する
- **出力**: ファイル成果物は持たない。
  判定と PR の URL を報告する

## 用語
用語は `claude/CLAUDE.md`「用語集」に従う。
フェーズは `/sync` が実装後に確定する PR 単位で、ブランチ `<feature>-pN` が対応する。

対象は PR 番号が渡されればその 1 本、渡されなければカレントブランチの PR。
stacked で複数の PR が既に存在する場合は feature の全 PR を対象に CI を監視して集約する。
`/orch` Step 16 の全 PR 最終確認がこれを使う。

## 対話方針
CI の完了を待って結果を完了カードで報告する。
基本は自律で動き、確認するのは「エラー処理」の条件のときだけ。

## 引数
- `$ARGUMENTS` が数字のみ: PR 番号
- `$ARGUMENTS` が数字以外の文字列: feature 名
- 省略時: カレントブランチから導出する

## 進め方

### Step 1: 対象 PR の特定 — 単一 / stacked

PR 番号が指定されていれば、その 1 本を使う。
未指定なら feature 名を求める。
引数に feature 名が渡されていればそれを使い、渡されていなければカレントブランチから求める。
`<feature>-pN` ならフェーズブランチ名から、それ以外ならブランチ名そのものから求める。

feature 名が求まったら、フェーズブランチの PR を番号順に列挙する：
```
for b in $(git branch --list "<feature>-p*" --sort=version:refname --format='%(refname:short)'); do
  gh pr list --head "$b" --json number,url,isDraft,headRefName,state --jq '.[]'
done
```
- 2 件以上ヒット → stacked モードとして、Step 2 を各 PR について回して集約する
- 1 件ヒット → その PR を単一 PR として対象にする
- 0 件ヒット → まだフェーズ分割前とみなし、`<feature>` ブランチの PR を見る：
  ```
  gh pr list --head "<feature>" --json number,url,isDraft,headRefName,state --jq '.[]'
  ```

未指定でカレントブランチが `<feature>` / `<feature>-pN` の形でなく、feature 名も求まらない場合は `gh pr view` でカレントブランチの PR を使う。

PR が見つからない場合は中断する。
未 push・未作成なら `/sync` が復帰先。

### Step 2: CI の監視と判定

`--watch` で完了までブロッキング監視する：

```
gh pr checks <PR番号> --watch --interval 30
```

監視完了後、最終ステータスを取得して判定する：

```
gh pr checks <PR番号> --json name,state,conclusion,link
```

- すべての `conclusion` が `SUCCESS` / `NEUTRAL` / `SKIPPED` → **green**
- いずれかが `FAILURE` / `CANCELLED` / `TIMED_OUT` / `ACTION_REQUIRED` → **赤**

**stacked の集約**: 全 PR について回し、全 PR green なら green、1 つでも失敗があれば赤とする。
どの PR / ブランチが失敗したかを明記する。
stacked では下位フェーズの base 側の修正が上位 PR にも影響するため、失敗フェーズを直したら stack を rebase 伝播して再 push し、再度全 PR を監視する。

### Step 3: greenのとき

未解決のレビューコメントを確認する：

```
gh pr view <PR番号> --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'
```

- **未解決あり** → 件数と概要を押さえ、`/resolve-comments` を次の一手に出す。
  切り替えは行わない
- **未解決なし** → 「役割」の通り draft のまま完了とし、完了カードの次の一手に `- Ready for review にする: gh pr ready <PR番号>` を出す
  ```
  gh pr view <PR番号> --json isDraft --jq '.isDraft'   # draft か確認（案内文に含めるため）
  ```
  既に Open ならその旨をカードに 1 行だけ書き、案内は出さない

### Step 4: 赤のとき

失敗ジョブを特定する：

```
gh pr checks <PR番号> --json name,state,conclusion,link | jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")]'
gh run list --branch <ブランチ名> --limit 5 --json databaseId,name,conclusion,workflowName
```

**ログ本体はメインで読まない。**
`gh run view <run-id> --log-failed` は失敗時にログ全文を吐き、メインでそのまま実行すると
その全文がコンテキストに載ってトークンを浪費する。
ログの取得と要約は `general-purpose` サブエージェントに委譲する。

サブエージェントに渡すもの:
- 対象の `run-id`・失敗ジョブ名
- 「`gh run view <run-id> --log-failed` を実行し、失敗ジョブ名・失敗ステップ・主要なエラーメッセージを
  最大 10〜15 行程度に絞って報告すること。ログ全文は転記しないこと」という指示

受け取るのはこの要約だけで、ログ全文はメインのコンテキストに読み込まない。

**修正方針は聞かない。**
どのジョブ・どのステップ・主要なエラーメッセージを押さえ、カードに畳んで人に渡す。
修正に入るかは人が次の一手から選ぶ。

**再発しそうな失敗は改善提案に切り出す。**
原因がその PJ で繰り返しハマる構造的なものだと判断したら、記録ではなく改善提案として切り出す。
例えばこの PJ の CI は import 順 lint で必ず落ちる、特定の env を入れ忘れると必ず E2E が落ちる、CI 専用の前提手順があるといったケースで、毎回ハマる構造ごと直す提案にする。
恒久ルール `CLAUDE.md` へ勝手に追記しない。

- **切り出さないもの**: その PR 限りの一回限りのバグ・タイポ修正、git log や diff を見れば分かること

### Step 5: 出力

次の完了カードを、コードフェンス自体は出さずに中身だけそのまま出力して終了する。
カードの前後に作業サマリ・所感・補足を足さない。

```markdown
### CI 監視完了
<対象 PR 数と CI 判定を 1 行>
- <主要な結果 最大 3 行>

生成物: `<対象 PR の URL>`

### 要確認
- <判定に影響しうる点> — 例: SKIPPED 扱いにしたジョブ、再実行で結果が変わったジョブ

### 次の一手
- コメントに対応する: `/resolve-comments`
```

- やったこと: 主要な結果は無ければ行ごと省略する。
  失敗ジョブのログ本体は載せず要点 1 行に畳む。
  stacked なら生成物に監視した全 PR を列挙し、行数上限は主要な結果にだけ課す。
- 要確認: 判定を左右しうる曖昧さがあれば挙げる。
  無ければブロックごと省略する。
- 次の一手: **判定は確定しているので該当する道だけ**を出す。
  - green + 未解決コメントあり → `- コメントに対応する: /resolve-comments`
  - green + 未解決コメントなし → `- マージ / Ready for review を判断（停止点）`
  - 赤 → `- 失敗を直す: <失敗ジョブ名> のログを確認して修正`

**中断時**: 同じブロック構成でヘッダを `### CI 監視中断` に差し替える。

- やったこと: 一言サマリに中断理由を書く。
  PR 未作成・`--watch` タイムアウト・権限エラーなどが該当する。
- 次の一手: 復帰コマンドを出す。
  PR 未作成なら `- PR を作る: /sync`。
  判定が出ていないまま次工程へ進む道は出さない。

## エラー処理
- `gh pr view` で PR が見つからない → カレントブランチが push されているか・PR が作成済みかを確認し、`/sync` を復帰先に出して中断する
- `gh pr checks --watch` がタイムアウト → 再実行するか人間に確認する
- `gh pr ready` が権限エラー → Web UI での操作を案内する

## 完了条件
対象 PR の CI 完了を待って green / 赤を判定し、報告したら完了。
**判定がどちらでも完了で、赤は中断ではない。**
単体で green + 未解決コメントなしのときは Ready for review の切り替え可否まで済ませる。
次工程の起動は完了条件に含めない。
