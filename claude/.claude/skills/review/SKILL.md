---
name: review
description: 実装を受け取りコードレビューを行う。test PASS 後に使う。
allowed-tools: Read, Write, Glob, Grep, Bash(git *), Bash(date *), Agent
argument-hint: "<feature>"
---

# レビュースキル

## 役割
デフォルトブランチとの git 差分を、仕様・設計との整合性とコード品質の観点でレビューし、OK / NG を判定して `.specs/<feature>/review.md` に記録する。
NG の戻し先は決めず、呼び出し元に委ねる。

## 判断が割れる点の扱い
途中でユーザーに質問も承認も求めない。
成立とも不成立とも確認できない指摘は「未検証」のまま記録して人に渡し、NG の根拠にも OK の根拠にもしない。

## 判定基準

| 条件 | 判定 |
|---|---|
| 裏取りで成立を確認できた仕様・設計との不整合がある | NG |
| 裏取りで成立を確認できたバグ・セキュリティ・クラッシュなど重大な問題がある | NG |
| 指摘がスタイル・軽微な改善のみ | OK。指摘は記録する |
| 重大と報告されたが裏取りで不成立だった | NG にしない。理由つきで記録する |
| 実装は仕様どおりだが、`requirements.md` / `design.md` の記述が実コードと食い違っている | OK。食い違いを推奨対応に上流 doc の修正として列挙し、要確認にも出す |

## review.md のフォーマット
frontmatter は test・qa のレポートと共通の形式にする。

```markdown
---
feature: [feature]
branch: [Step 2 で確定したブランチ。detached なら none]
head: [Step 2 で確定した HEAD。40 文字、短縮しない]
ran_at: [書き出し時点の時刻。date +"%Y-%m-%dT%H:%M:%S%z" で取得]
fixed: false [常に false。/fix が修正を適用したときだけ true に書き換える]
count: [NG の連続回数。今回が NG かつ既存レポートも NG なら既存値 +1、それ以外は 1]
---

### 判定
[OK / NG]

### 仕様整合性
- [指摘内容と該当箇所]

### AI コードレビューの指摘
- [指摘内容と該当箇所] — [重大度] + 検証結果: [成立 / 不成立。理由 / 未検証]

### 推奨対応
- [対応方針]
```

## 進め方

### Step 1: 引数の確認
- `$ARGUMENTS[0]` が無ければ「使い方: /review <feature>」を表示して終了

### Step 2: 対象確定

カレントブランチが `<feature>` でなければ `git switch <feature>` を試みる。
- switch できた → そのまま続行
- `<feature>` が存在しない → 現在のブランチをそのまま採用する
  - PR を作らない運用で直接コミットしているとみなす
- 未コミットの変更があって switch できない → Step 7 の中断カードで報告する
  - stash などの作業ツリー操作はしない
- detached HEAD のまま `<feature>` も無い → `branch: none` として続行する

`git rev-parse HEAD` で head を、`git default-branch` でデフォルトブランチを確定する。

### Step 3: 並列レビュー

`Agent` ツールで次の 2 つを並列に起動し、両方の完了を待つ。
いずれも fresh な general-purpose agent とし、レビュー対象は自分で読ませる。

- 仕様整合性 reviewer
  - `.specs/<feature>/requirements.md` と、存在すれば `design.md` / `tasks.md` を読ませる
  - `git diff origin/<デフォルトブランチ>` を読ませ、仕様・設計と整合しているかの指摘一覧を返させる
- コード品質 reviewer
  - `coderabbit:code-review` skill が導入済みならそれを、未導入なら `code-review` skill を `Skill` ツールで起動させる
  - 効果レベルは指定せず、`--comment` / `--fix` は使わせない

`design.md` / `tasks.md` が無い feature は `requirements.md` との整合だけを見る。
無いことを中断理由にしない。

### Step 4: 指摘の裏取り

どちらの reviewer の指摘も誤検知を含むので、重大と報告された指摘は該当箇所を実コードで開いて裏を取る。
- 指摘されたファイル・行を読み、呼び出し元・型・既存のガード節・テストの有無まで辿って、その条件が実際に成立しうるかを確認する
- 別の層で既に担保されている、または到達しないコードなら不成立とする
- 検証結果は「成立」「不成立。理由」「未検証」で書き分ける

### Step 5: 判定

「判定基準」に従って OK / NG を決める。

### Step 6: 書き出し

既存の `review.md` があれば判定と `count` を読み、「review.md のフォーマット」で `.specs/<feature>/review.md` に上書きする。
指摘の一覧はここに寄せ、ターミナルには列挙しない。

### Step 7: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### レビュー中断` にし、1 行目に中断理由を書き、生成物の行を省き、次の一手は復帰に必要な操作だけにする。

```markdown
### レビュー完了 — <OK / NG>
<判定と対象範囲を 1 行>

生成物: `.specs/<feature>/review.md`

### 要確認
- <未検証の指摘> — 該当: <ファイル:行>
- <仕様どおりだが上流 doc が実コードと食い違っている点>
<無ければこのブロックを省略>

### 次の一手
- 動作確認する: `/qa <feature>`
  <NG なら `- 設計を直す: /design <feature>` と `- 実装を直す: /fix <feature>` に差し替える>
```
