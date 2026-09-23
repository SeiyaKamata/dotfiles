---
name: watch-ci
description: PRのCIを監視し、完了後に結果に応じて分岐対応する。push後やPR作成後に使う。
argument-hint: "[PR番号 | <feature>]"
allowed-tools: Read, Write, Bash(gh *), Bash(git *), Bash(date *), Agent
---

# CI監視スキル

## 役割
PR の CI が完了するまで監視し、green / 赤を判定して `.specs/<feature>/ci-report.md` に記録する。
赤ならログを取得して要点に畳み、ログ本体はメインコンテキストにもカードにも載せない。
Ready for review への切り替えは行わず、draft のまま完了とする。
Ready for review はレビュアーに通知が飛ぶ外向きの操作で、取り消しても通知は戻らないので人が明示的に実行する。

## 判断が割れる点の扱い
CI の完了を待って結果を完了カードで報告し、途中でユーザーに質問も承認も求めない。
`gh pr checks --watch` がタイムアウトしたときだけ、再実行するかを人に確認する。
修正はここでは行わず、赤の内訳をレポートに書いて `/fix` に渡す。

## ci-report.md のフォーマット
frontmatter は test・review・qa のレポートと共通の形式にする。

```markdown
---
feature: [feature]
branch: [対象 PR の head ブランチ]
head: [gh pr view <PR番号> --json headRefOid --jq .headRefOid で取った 40 文字。短縮しない]
ran_at: [書き出し時点の時刻。date +"%Y-%m-%dT%H:%M:%S%z" で取得]
fixed: false [常に false。/fix が修正を適用したときだけ true に書き換える]
count: [赤の連続回数。今回が赤かつ既存レポートの branch が同じで判定も赤なら既存値 +1、それ以外は 1]
---

# CI結果: [feature]

## サマリ
- PR: #[番号] [URL]
- 判定: [green / 赤]

## 失敗ジョブ
[赤のときだけ。green なら節ごと省略]
- [ジョブ名]: [失敗ステップ]。[主要なエラーメッセージ 1〜2 行] — [ジョブの link]
```

## 進め方

### Step 1: 対象 PR の特定

- `$ARGUMENTS` が数字のみ → その PR 番号 1 本
- `$ARGUMENTS` が数字以外の文字列 → feature 名
- 省略 → カレントブランチ名を feature 名にする

feature 名が求まったら `gh pr list --head "<feature>" --json number,url,isDraft,headRefName,state --jq '.[]'` で PR を 1 本特定する。

feature 名が求まらなければ `gh pr view` でカレントブランチの PR を使い、レポートは書かずに要確認に出す。
PR が見つからなければ、カレントブランチが push されているか・PR が作成済みかを確認し、Step 5 の中断カードで `/land` を案内する。

### Step 2: CI の監視と判定

`gh pr checks <PR番号> --watch --interval 30` で完了までブロッキング監視し、`gh pr checks <PR番号> --json name,state,conclusion,link` で最終ステータスを取る。
- すべての `conclusion` が `SUCCESS` / `NEUTRAL` / `SKIPPED` → green
- いずれかが `FAILURE` / `CANCELLED` / `TIMED_OUT` / `ACTION_REQUIRED` → 赤

### Step 3: 判定ごとの確認

green なら `gh pr view <PR番号> --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'` で未解決のレビューコメントの件数と概要を押さえる。

赤なら失敗ジョブを特定し、ログの取得と要約を `general-purpose` サブエージェントに委譲する。
`gh run view <run-id> --log-failed` はログ全文を吐くので、メインでは実行しない。

```
gh pr checks <PR番号> --json name,state,conclusion,link --jq '[.[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT")]'
gh run list --branch <ブランチ名> --limit 5 --json databaseId,name,conclusion,workflowName
```

サブエージェントには対象の `run-id` と失敗ジョブ名を渡し、「`gh run view <run-id> --log-failed` を実行し、失敗ジョブ名・失敗ステップ・主要なエラーメッセージを最大 10〜15 行に絞って報告し、ログ全文は転記しない」と指示する。

原因がその PJ で繰り返しハマる構造的なものなら、記録ではなく改善提案として `/seed` に切り出す。
その PR 限りのバグやタイポ修正、git log や diff を見れば分かることは切り出さない。

### Step 4: レポートの書き出し

feature 名が求まっているときだけ、既存の `ci-report.md` があれば `branch`・判定・`count` を読み、「ci-report.md のフォーマット」で `.specs/<feature>/ci-report.md` に上書きする。

### Step 5: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### CI 監視中断` にし、1 行目に中断理由を書き、生成物の行を省き、次の一手は復帰に必要な操作だけにする。

```markdown
### CI 監視完了 — <green / 赤>
<対象 PR と CI 判定を 1 行。赤なら失敗ジョブの要点を 1 行に畳む>

生成物:
- <対象 PR の URL>
- `.specs/<feature>/ci-report.md`

### 要確認
- <SKIPPED 扱いにしたジョブ、再実行で結果が変わったジョブなど、判定に影響しうる点>
- <feature 名が求まらずレポートを書けなかったならその旨>
<無ければこのブロックを省略>

### 次の一手
- コメントに対応する: `/triage-comments`
  <green で未解決コメントなしなら `- Ready for review / merge を判断する` に、赤なら `- 失敗を直す: /fix <feature>` に差し替える>
```
