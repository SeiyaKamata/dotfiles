---
name: land
description: コミット済みの変更を新しいdraft PRとして立ち上げる。commit完了後に使う。デフォルトブランチへ直接取り込む運用の repo では使わない。
argument-hint: "[<feature>]"
allowed-tools: Bash(git *), Bash(gh *), Read
---

# 新規PR着地スキル

## 役割
コミット後の変更を初めて draft PR としてリモートへ着地させる。

1 feature を 1 PR にし、PR の分割はしない。
既存 PR への追加コミットの push は扱わず、「まだ PR を持たないブランチの初回」だけを担う。
既に PR があるブランチ・マージ済みのブランチはスキップするので、何度呼んでも同じ結果になる。

## 判断が割れる点の扱い
ベースブランチはデフォルトブランチを自動採用し、聞かない。
push の拒否は自動解決せず、中断カードで人に委ねる。

## PR のタイトルと本文
タイトルは固定 prefix `【鎌田QA】` で始め、`<pr_title>` は `.specs/<feature>/requirements.md` の frontmatter から取る。
無ければコミットメッセージから主題を作る。

- `【鎌田QA】<pr_title>`

```markdown
@coderabbitai ignore

## Summary
[変更の概要を 1〜3 行]

## 変更内容
[git diff をもとに、変更ファイルと変更内容を箇条書き]
```

本文の書き方。
- IT・ビジネスの専門用語を避け、読んだ人が知識に関わらず理解できる言葉で書く
  - リファクタリング・マイグレーション・エンドポイント・スキーマ・デプロイ・バリデーションは、コードの整理・テーブル構造の変更・API の受け口・データの形式・本番環境への反映・入力値の確認と言い換える
- 今日チームに入ったばかりの人が 1 度読み通すだけで、何が変わったか・なぜ必要か・なぜ安全かを掴めるかを自問し、Summary の 1 文を専門用語ゼロで言い切れないなら書き直す
- PR の git diff に出るファイルだけに言及し、`.gitignore` 配下のファイルには触れない
- 別 PR / 別チケットへのリンクは付けてよいが、リンク先を読まないと理解が成立しない書き方は避ける
- 箇条書きは太字の見出しを項目にし、空行 + 2 スペースインデントで詳細を段落として落とす
- フローに変更があれば Mermaid 図を Before / After 並置か `★新規` / `★変更` / `★削除` の差分ラベルで書き、図だけ見て何が変わったかが 1 文で言えなければ作り直す
- `gh pr create --body` の HEREDOC は `<<'EOF'` の literal mode にし、バッククォートを escape しない
  - escape すると backslash がそのまま渡って表示が崩れる

## 進め方

### Step 1: 未コミットの変更確認

`git status --porcelain` で確認し、未コミットの変更があれば Step 5 の中断カードで `/commit` を案内して終了する。
PR に載せる実物はコミット列なので、作業ツリーに差分が残った状態では進めない。

### Step 2: 対象ブランチの解決

```
DEFAULT=$(git default-branch)
CURRENT=$(git branch --show-current)
```

feature 名は引数があればそれ、無ければ `CURRENT` にする。
`CURRENT` が `<feature>` と一致しなければ `git switch <feature>` し、存在しなければ実装ブランチが無い旨を Step 5 の中断カードで報告する。

`CURRENT` がデフォルトブランチと同じなら、コミット内容から命名したブランチを `git checkout -b` で作ってから進む。
push を実行するのはこのスキルなので、デフォルトブランチのまま push しないための最終防波堤になる。

### Step 3: 既存 PR の確認

`gh pr list --head "<対象ブランチ>" --state all --json number,url --jq '.[]'` が空でなければ既に PR があり、`git branch --merged "$DEFAULT"` に含まれていればマージ済みなので、どちらも作らず既存 PR の URL を Step 5 で報告して終了する。

### Step 4: draft PR を作る

```
git fetch origin "+refs/heads/${DEFAULT}:refs/heads/${DEFAULT}"
git log "$DEFAULT"..HEAD --oneline
git diff "$DEFAULT"...HEAD --stat
```

`gh label list` でラベルを取得し、未 push なら `git push -u origin <対象ブランチ>` してから、「PR のタイトルと本文」で作成する。

```
gh pr create --draft --base "$DEFAULT" --head <対象ブランチ> --title "<タイトル>" --body "<本文>" --assignee @me --label "<ラベル>"
```

`gh pr create` が「head branch is the same as base branch」で失敗したら、base と head が同じになっていないかを確認する。

### Step 5: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### draft PR 作成中断` にし、1 行目に中断理由を書き、生成物の行を省き、次の一手は復帰に必要な操作だけにする。

```markdown
### draft PR 作成完了
<作成した PR の主題を 1 行>

生成物: <作成した PR の URL。既存でスキップしたなら URL の後に（既存）を添える>

### 次の一手
- CI を監視する: `/watch-ci`
```
