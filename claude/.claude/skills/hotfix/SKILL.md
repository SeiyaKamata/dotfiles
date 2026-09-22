---
name: hotfix
description: 調査済みのバグ報告を受け、本番tagからreleaseブランチとworkブランチを切って修正し、release宛・main宛の2つのPRを作成する。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(gh *), Bash(mkworktree *), Bash(mkdir *), Bash(ln *), Bash(date *), Skill
argument-hint: "<feature> [tag]"
---

# hotfix スキル

## 役割
調査済みのバグを本番環境で動いている tag に当てる。
tag から release ブランチと work ブランチを切り、症状を止める最小限の修正を実装して、本番へ当てる release 宛と同じ修正を取り込む main 宛の 2 つの draft PR を作る。
原因調査は行わず、`.specs/<feature>/bug-report.md` に原因が絞り込まれていることを前提にする。

## 判断が割れる点の扱い
本番への修正なので人が起動し、起動後は途中で承認を取らずに進める。
ユーザーに聞くのは対象 tag が引数に無いとき、ブランチ名が既存と衝突したとき、tag のコードが `bug-report.md` の所見と食い違うときだけ。
原因が定まらないまま実装へ進まず、Step 10 の中断カードで調査へ差し戻す。

## ブランチ命名規則
`release/<base>_p<n>` と `work/<base>_p<n>`。
tag が `^(.+)_p([0-9]+)$` にマッチすれば base はキャプチャ 1、n はキャプチャ 2 + 1 で、マッチしなければ base は tag そのまま、n は 1。

| tag | release / work |
|---|---|
| `v1.2.3` | `release/v1.2.3_p1` / `work/v1.2.3_p1` |
| `v1.2.3_p1` | `release/v1.2.3_p2` / `work/v1.2.3_p2` |
| `v1.2.3_p5` | `release/v1.2.3_p6` / `work/v1.2.3_p6` |

## PR のタイトルと本文
`<subject>` は work ブランチのコミット列から作り、release 宛・main 宛で共通にする。
先頭に当て先を示す `[release]` / `[main]` を付け、固定 prefix `【鎌田QA】` を続ける。

- release 宛: `[release]【鎌田QA】<subject>`
- main 宛: `[main]【鎌田QA】<subject>`

```markdown
[main 宛だけ冒頭に]
> release宛PRと同じ修正をmainにも取り込むためのPRです。
> 対応release PR: #[release 宛 PR の番号]

## Summary
[修正内容の概要を 1〜3 行]

## 背景
[bug-report.md の症状と疑わしい箇所から、なぜ hotfix が必要だったか]

## 変更内容
[変更ファイル・変更点を箇条書き]

## 起点tag
[tag]

## 動作確認
- [ ] [bug-report.md の回帰テストの観点から]
```

## 進め方

### Step 1: 引数の確認
- `$ARGUMENTS[0]` が無ければ「使い方: /hotfix <feature> [tag]」を表示して終了
- `$ARGUMENTS[1]` があれば対象 tag の候補にする

### Step 2: バグ報告確認

`.specs/<feature>/bug-report.md` を読み、症状・再現手順・疑わしい箇所・想定する修正範囲・回帰テストの観点を控える。
存在しない、または「再現可否: 再現できず」なら Step 10 の中断カードで `/bughunt <feature>` を案内する。

### Step 3: hotfix 専用 worktree の確認と作成

main repo は bare repo で、すべての worktree は何らかの作業中という前提になる。
Bash の作業ディレクトリは呼び出しごとにプロジェクトルートへ戻り、`/commit` も Read / Edit もこのセッションの worktree で動くので、別の worktree を対象に作業は続けられない。
worktree を作ったらこのセッションでは進めず、その worktree で開いたセッションに引き継ぐ。

`git rev-parse --show-toplevel` のパス末尾が `-hotfix-<feature>` なら専用 worktree に立っているので Step 4 へ。
それ以外なら専用 worktree を作り、`.specs/<feature>` を symlink で共有してから、`$dest` で `claude` を起動して `/hotfix <feature> <tag>` を再実行するよう Step 10 の中断カードで案内する。

```
bare_repo=$(git rev-parse --git-common-dir)
dest=$(mkworktree "$bare_repo" "$(basename "$bare_repo")-$(date +%Y%m%d)-hotfix-<feature>")
mkdir -p "$dest/.specs"
ln -s "$(git rev-parse --show-toplevel)/.specs/<feature>" "$dest/.specs/<feature>"
```

`.specs/` は gitignore 配下で worktree 間で共有されないため、symlink で `bug-report.md` の実体を 1 箇所に保つ。

### Step 4: 対象 tag の確認

引数に無ければ `git tag --sort=-creatordate | head -n 10` を提示して人に確認する。
`git fetch --tags` のうえ `git rev-parse --verify "refs/tags/<tag>"` が失敗したら、tag が存在しない旨を伝えて聞き直す。

### Step 5: ブランチ準備

「ブランチ命名規則」で release / work ブランチ名を決め、tag から release ブランチを切って push し、そこから work ブランチを切る。

```
git checkout -b <release_branch> refs/tags/<tag>
git push -u origin <release_branch>
git checkout -b <work_branch>
```

同名のローカル / リモートブランチが既にあれば、既存ブランチを使うか別名にするかを人に確認する。

### Step 6: tag との照合

調査は通常 `main` で行われているので、その所見が tag のコードにも当てはまるとは限らない。
work ブランチに立った状態で `bug-report.md` の疑わしい箇所を 1 件ずつ読んで確認する。

| 照合結果 | 進み先 |
|---|---|
| 該当箇所が同じ内容で存在する | Step 7 へ |
| 存在するが差分がある | 差分を人に提示し、想定する修正範囲が通用するかを確認してから Step 7 へ |
| パス・関数ごと存在しない | 調査ベースがずれているので、work ブランチに立ったまま `/bughunt <feature>` を回し直すよう Step 10 の中断カードで案内する |

### Step 7: 実装

`bug-report.md` の想定する修正範囲をもとに、症状を止める最小限の修正を実装する。
リファクタ・周辺の改善は混ぜず、気づいたことは `/spinoff` に切り出す。

### Step 8: コミットと push

`/commit` を起動し、直接 `git commit` は実行しない。
完了したら `git push -u origin <work_branch>` する。

### Step 9: PR 作成

`gh label list` で `hotfix` などの該当ラベルを確認し、「PR のタイトルと本文」で release 宛、main 宛の順に draft で作る。
ready 化は人が判断する。

```
gh pr create --draft --base <release_branch> --head <work_branch> --title "[release]【鎌田QA】<subject>" --body "<本文>" --assignee @me --label "<該当ラベル>"
gh pr create --draft --base main --head <work_branch> --title "[main]【鎌田QA】<subject>" --body "<本文>" --assignee @me --label "<該当ラベル>"
```

`gh pr create` が push 未完了で失敗したら `git push -u origin HEAD` のうえ再試行する。
main 宛の差分が大きすぎる、またはコンフリクトが多発するなら、main から別の work ブランチを切って cherry-pick するか、release を main にマージする運用に切り替えるかを人に委ねる。

### Step 10: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### hotfix 中断` にし、1 行目に中断理由を書き、作成できた PR があれば生成物の行を残し、次の一手は復帰に必要な操作だけにする。

```markdown
### hotfix PR 作成完了
<何を修正した hotfix かと、起点 tag・release / work ブランチ名を 1 行>

生成物:
- <release 宛 PR の URL>
- <main 宛 PR の URL>

### 要確認
- <ローカルで再現できなかった条件・影響範囲の見立てなど、本番影響で確認しきれていない点>
- <Step 6 で tag と bug-report.md に差分があればその内容>
<無ければこのブロックを省略>

### 次の一手
- CI を監視する: `/watch-ci`。2 本とも
```
