---
name: bughunt
description: バグ報告を起点に再現・原因の一次特定・bug-report.jsoncへの記録を行う調査工程。コードは直さない。バグ報告を受けたら最初に使う。
allowed-tools: Read, Write, Edit, Bash(python3 ~/.claude/skills/_report/render.py *), Agent
---

# バグ調査スキル

## 役割
ユーザーからのバグ報告を起点に、再現確認と原因の一次特定を行い、`.specs/bug-report.jsonc` に記録する。
コード修正・回帰テスト・レビュー・コミットは行わず、この工程は何も直さない。

## 判断が割れる点の扱い
症状の聞き取りだけは Step 1 で質問する。
入力が人からしか得られないためで、調査結果や記録内容の確認はしない。
再現できなければ原因の判定を出せていないので、修正工程へ進まず Step 4 の中断カードで追加情報を求める。

## bug-report.jsonc のフォーマット
`/fix` と `/hotfix` と bug-investigator が読む調査結果と、人が読む HTML の元データを兼ねる。
`.specs/bug-report.jsonc` に上書きし、同じ内容から `.specs/bug-report.html` を生成する。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

`branch` / `head` / `count` は持たない。
`/bughunt` は自己修正ループの外にあり、渡すのは疑わしい箇所であってコミットに紐づく判定ではないので、対象同一性の照合も連続失敗のカウントも要らない。

```jsonc
{
  "feature": "[機能名]",
  "fixed": false, // 常に false。/fix が修正を適用したときだけ true に書き換える
  "symptom": "[一文]",
  "reproducible": "[再現OK / 再現できず。Step 1 の書き出し時点は 未調査]",
  "expected": "[期待する挙動]",
  "actual": "[実際の挙動]",
  "steps": ["[再現手順を 1 手順ずつ]"],
  "suspects": [
    { "location": "[path]:[line]", "reason": "[なぜ疑わしいか。一次特定であり確定診断ではない]" }
  ],
  "fix_scope": ["[触るファイル・関数の見当]"],
  "regression_checks": ["[この症状が再発しないことを確認する観点。実行はしない]"]
}
```

## 進め方

### Step 1: バグ報告の受領

`.specs/bug-report.jsonc` があれば前回までの調査結果として読み込み、既に埋まっている項目は聞き直さない。
症状・再現手順・期待する挙動・実際の挙動のうち不足している項目だけを質問して補い、`feature` `symptom` `reproducible` `expected` `actual` `steps` を埋めて一旦書き出す。
`reproducible` はこの時点では `未調査` にする。必須の項目が欠けた `.jsonc` は HTML を生成できない。
これが調査エージェントの起点になる。

### Step 2: bug-investigator へ委譲

`bug-investigator` サブエージェントを起動する。
調査中の大量のコード読み・コマンド出力をメインコンテキストに載せないためと、調査に強いモデルを当てるため。
bug-investigator は `bug-report.jsonc` の症状を起点に再現を確認し、再現できたらコードを調べて「再現可否 / 疑わしい箇所 / 想定修正範囲 / 回帰テストの観点」を、再現できなければ「再現できず + 必要な追加情報」を返す。

### Step 3: 書き出し

bug-investigator の所見を「bug-report.jsonc のフォーマット」で `.specs/bug-report.jsonc` にマージ保存する。
`<path>:<line> — 理由` の形で返された疑わしい箇所は、`suspects` の `location` と `reason` に分けて書く。
続けて `python3 ~/.claude/skills/_report/render.py .specs/bug-report.jsonc` で `.specs/bug-report.html` を生成する。
生成に失敗したら `.jsonc` は残し、生成物から `.html` を省いて要確認に失敗の内容を載せる。
再現できなかった場合は「再現できず」と必要な追加情報を記録し、Step 4 の中断カードで報告する。
追加情報が得られたら Step 2 から再委譲する。

### Step 4: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
HTML を生成できていなければ生成物の `.html` の行を省く。
中断時は見出しを `### バグ調査中断` にし、1 行目に中断理由を書き、`bug-report.jsonc` に記録済みなら生成物の行を残し、次の一手は「追加情報を添えて `/bughunt`」だけにする。

```markdown
### バグ調査完了
<症状と一次特定した原因を 1 行>

生成物:
- `.specs/bug-report.jsonc`
- `.specs/bug-report.html`

### 要確認
- <一次特定にとどまり断定できなかった点・他の可能性> — 該当: <path>:<line>
<無ければこのブロックを省略>

### 次の一手
- 原因を確定して直す: `/fix`
- 本番 tag に当てる: `/hotfix [tag]`
  <本番稼働中の tag に当てる必要が無いと分かっているなら省く>
- 再調査する: `/bughunt`
  <調査が甘いと感じたときだけ>
```
