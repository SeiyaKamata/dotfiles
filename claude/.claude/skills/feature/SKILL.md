---
name: feature
description: 要望・指摘・棚上げ案件から、独立 feature の下書き feature.jsonc を作る。詳細化はせず、後で /spec が拾う。思いついた変更を書き留めたいとき、/review 等でスコープ外の指摘が出たとき、投げなくても今のタスクが完了する棚上げ案件があるときに使う。
argument-hint: "[要望や指摘の本文]"
allowed-tools: Write, Glob, Bash(python3 ~/.claude/skills/_report/render.py *)
---

# feature 下書きスキル

## 役割
要望・指摘・棚上げ案件を、その場で要件化せずに独立 feature の下書き `~/Develop/.specs/<feature>/feature.jsonc` として書き留める。
追跡記録は残さず、元 feature に「切り出し済み」のマーキングもしない。
それが無いと今のタスクが完了しないものは計画の穴なので、ここでは扱わず `/plan` に戻して `S<n>` を足す。

## 判断が割れる点の扱い
途中でユーザーに質問も承認要求もしない。
どれを下書きにするか・分割かまとめか・feature 名は、会話の文脈と引数の本文から自分で確定し、完了カードで事後報告する。
材料に無い情報は下書きに「TODO: /spec で詳細化」と書き、質問で埋めない。

## feature.jsonc のフォーマット
feature の雑メモを置く場所で、`/spec` が拾う下書きと、人が読む HTML の元データを兼ねる。
`pr` は `/land` が書くので、ここでは書かない。既に `feature.jsonc` があれば読み直し、`pr` を含む既存のキーは残して、材料から分かったキーだけを足す。
既知の情報だけを書き、EARS 形式の受け入れ条件は書かない。
詳細化は `/spec` が読んだときに行い、`requirements.jsonc` として確定させる。
`~/Develop/.specs/<feature>/feature.jsonc` に書き、同じ内容から同じ場所に `feature.html` を生成する。
`repo` `notion_url` `pr_title` `branch_name` `title` は feature のメタの正本で、以降の工程はこのファイルから読む。
空のキーは `/spec` が埋める。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

```jsonc
{
  "repo": "[実装するリポジトリが分かっていれば bare repo のディレクトリ名。無ければ空文字で /spec が確定する]",
  "notion_url": "[材料に Notion のページがあればその URL。無ければ空文字]",
  "pr_title": "[材料に PR タイトルの指定があればそれ。無ければ空文字]",
  "branch_name": "[材料にブランチ名の指定があればそれ。無ければ空文字]",
  "title": "[何をしたい変更か。日本語の 20 字以内の名詞句。看板の一覧と herdr の workspace ラベルに出る。詳しい説明は background と goal に書く]",
  "background": "[なぜこの変更が要るか。専門用語・内部用語は本文で説明する]",
  "goal": "[何を実現したいか。挙動・体験のレベルで書き、実装方法は指定しない]",
  "hints": ["[実コードで確認した対象ファイルや該当箇所。詳細化の起点にする参考情報で、不足は「TODO: /spec で詳細化」と書く]"],
  "constraints": ["[外せない条件、やってほしくないこと、既存仕様との整合など。無ければ空配列]"]
  // "pr": { "number": 123, "url": "https://..." } は /land が足す
}
```

## 進め方

### Step 1: 材料の特定

- 引数に要望や指摘の本文があれば、それを材料にする
- 引数が無ければ会話の文脈から、直前に棚上げされた指摘や思いついた変更を材料にする
- どちらにも材料が無ければ「使い方: /feature [要望や指摘の本文]」を表示して終了

複数の案件が混ざっているなら、独立した下書きに分けるか 1 つにまとめるかを確定する。
根拠が薄いときは案件ごとに分ける側に倒す。まとめて後戻りしにくくなるより、後で `/spec` 側で統合を判断できる方が安全。

### Step 2: 書き出し

下書きごとに feature 名を材料から kebab-case・3〜5 語程度で決め、「feature.jsonc のフォーマット」で `~/Develop/.specs/<feature>/feature.jsonc` を書き、`python3 ~/.claude/skills/_report/render.py ~/Develop/.specs/<feature>/feature.jsonc` で同じ場所に `feature.html` を生成する。
生成に失敗した下書きは、`.jsonc` を残し、完了カードの要確認に失敗の内容を載せる。
今の worktree の `.specs` は別の feature を指すので、書き先は絶対パスで指定する。
`Glob("~/Develop/.specs/*")` で同名があれば区別がつく別名にし、1 回の実行で複数生成するときは採用済みの名前も既存として扱う。
1 件が失敗しても他は生成し、部分成功を報告する。

### Step 3: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### 下書き作成中断` にし、1 行目に中断理由を書き、生成できた下書きがあれば生成物の行は残す。

```markdown
### 下書き作成完了
<何件をどの feature に書き留めたかを 1 行>

生成物:
- `~/Develop/.specs/<feature1>/feature.jsonc`
- `~/Develop/.specs/<feature1>/feature.html`
- `~/Develop/.specs/<feature2>/feature.jsonc`
- `~/Develop/.specs/<feature2>/feature.html`

### 要確認
- <書き留めるか迷った案件・分割かまとめかの判断>

### 次の一手
- 要件に落とす: `devpick` で <feature> を選んで worktree を作り、`/spec`
```

要確認は無ければブロックごと省略し、次の一手は下書きが複数なら 1 件 1 行で出す。
