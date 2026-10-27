---
name: spec
description: ユーザーから機能要望を受け取り、要件を詳細化しEARS形式で出力する。要望はあるが.specs/に何も無い最初の一歩、または下書きのfeature.jsoncの詳細化で使う。requirements.jsoncがあるときは、現状の要件と要確認を提示し、要確認を会話で詰めて、ブラウザで付けたコメントとあわせて書き戻す。
allowed-tools: Read, Write, Edit, Bash(git rev-parse *), Bash(python3 ~/.claude/skills/spec/check.py), Bash(open .specs/requirements.html), Bash(python3 ~/.claude/skills/_report/render.py *)
---

# 要件策定スキル

## 役割
ユーザーの要望から EARS 形式の要件ドキュメントを作る。
「何を作るか」だけを扱い、技術的な実装方法を含む「どう作るか」は書かない。
`requirements.jsonc` を新規に書くのは `/spec` だけが行う。
`repo` `notion_url` `pr_title` `branch_name` `title` は `feature.jsonc` が持つ正本で、`requirements.jsonc` には書かない。
`/spec` は `feature.jsonc` が無ければ作り、空のキーを埋める。
要確認の議論と、その結果の書き戻しもこのスキルが行う。

## 判断が割れる点の扱い
Step 2〜4 では、ユーザーに質問もスコープ承認もしない。
判断が割れる点は最も素直な解釈を採って進め、採った解釈と理由は該当する行の `question` に書く。
特定の 1 行に紐づかないものは `open_questions` に書く。

## 受け入れ条件の書き方

### 観点

- **ユーザー行動**: ユーザーが X をしたとき何が起きるべきか。常に埋める
- **エラーケース**: 異常系・境界値の振る舞い。常に埋める
- **非機能要件**: 性能・セキュリティ・可用性の期待値。影響する変更のときだけ埋め、無ければ Requirement を起こさない

ユーザー行動・エラーケースの情報が下書きにも要望にも無ければ「判断が割れる点の扱い」節に従う。

### 型

型は EARS の 5 型で分けるが、**文は日本語語順で書く**。

| 型 | 書き方 | 目印 |
|---|---|---|
| 常時 | `<振る舞い>` | 矢印なし |
| イベント駆動 | `<イベント>とき → <振る舞い>` | 「とき」 |
| 状態駆動 | `<前提>あいだ → <振る舞い>` | 「あいだ」 |
| オプション機能 | `<機能・条件>の場合 → <振る舞い>` | 「場合」 |
| エラー処理 | `【異常】<トリガー> → <振る舞い>` | `【異常】` |

オプション機能型は、権限・プラン・機能フラグのように**恒常的な構成の有無**で分岐する要件に使う。
一時的なトリガーなら「とき」、継続する状態変化なら「あいだ」を使い、オプション機能型と混同しない。

### 主体の書き方

主体ごとに `###` の節を立て、その下に Requirement を `####` で並べる。
各行は主語を落として「条件 → 振る舞い」に揃える。
1 つの Requirement の主体は 1 つにする。
流れの中で主体が入れ替わるときは Requirement を主体ごとに分け、受け手側の条件に相手の動作を書く。
Requirement 番号は主体の節をまたいで連番にする。

### 文の書き方

- 括弧は「あれば」「任意」のような 1〜2 語のラベルだけに使う
  - 理由や値の組のような文の形をした補足は括弧に押し込めず、別行か読点で切る
- 受け入れ条件の行は、トリガーと結果が観測できる振る舞いだけにする
  - 用語や値の定義は、それを使う振る舞いの行に組み込む
  - 変更しない範囲や絞り込まない範囲の宣言は、スコープ外に置く
- 1 行に 1 振る舞いだけ書く
  - 同じ条件で結果だけが違う項目に限り 1 行へ畳んでよい
- 1 Requirement は、判定の軸が 1 つの塊だけにする
  - 軸が複数あるなら Requirement を分ける
- Requirement の見出しは、動機を書かなくても目的が読み取れる粒度まで分ける
- 例示は書かず、条件を言い切る
- 「適切に」「必要に応じて」のような曖昧語は避け、テスト可能・検証可能な表現にする

## requirements.jsonc のフォーマット

検討経緯・却下した代替案は書かず、決まったことだけを書く。
後続の skill が読む要件と、人が読む HTML の元データを兼ねる。
`.specs/requirements.jsonc` に上書きし、同じ内容から `.specs/requirements.html` を生成する。
末尾カンマは書かない。
文字列の中の二重引用符は `\"` に、改行は `\n` にエスケープする。

各行の `text` は「受け入れ条件の書き方」の型の記法をそのまま使う。
`question` は判断で埋めたときだけ採った解釈と理由を書き、無ければ空文字にする。
スコープ外の項目に、EARS は使わない。
表は行数にかかわらず `appendix` に置き、スコープ外と受け入れ条件からは「詳細は付録」と 1 行で参照する。

```jsonc
{
  "overview": "[機能の目的と背景を 2〜3 文で]",
  "open_questions": ["[Requirement 全体に関わるなど、特定の 1 行に紐づかない要確認。無ければ空配列]"],
  "out_of_scope": [
    {
      "item": "[外すもの]",
      "reason": "[なぜ外すか。別 feature での扱いなどの補足もここに畳む]",
      "question": "[判断で埋めたときだけ。採った解釈。無ければ空文字]"
    }
  ],
  "subjects": [
    {
      "name": "[主体]",
      "requirements": [
        {
          "id": 1,
          "title": "[要件名]",
          "lines": [
            { "text": "[振る舞い]", "question": "" },
            { "text": "[イベント]とき → [振る舞い]", "question": "[採った解釈と理由]" },
            { "text": "【異常】[トリガー] → [振る舞い]", "question": "" }
          ]
        }
      ]
    }
  ],
  "appendix": [
    { "title": "[表題]", "columns": ["[列名]"], "rows": [["[セル]"]] }
  ] // 表が無ければ空配列
}
```

## 進め方

### Step 1: 開始 Step の判定

`.specs/requirements.jsonc` と `.specs/feature.jsonc` の有無で分岐する。

- **`requirements.jsonc` が有る**: 読み、Step 2〜4 を飛ばして Step 5 から進める
- **`requirements.jsonc` が無く `feature.jsonc` が有る**: 雑メモの下書き。`title` `background` `goal` `hints` `constraints` を要望の材料として使い、Step 2 から詳細化する
- **どちらも無い**
  - 会話文脈に要望があれば、新規として Step 2 から書き起こす
  - 要望も無ければ、「使い方: /spec <要望>」を表示して終了する

### Step 2: スコープ境界

out-of-scope を列挙する。
in-scope は列挙せず、Step 3 で Requirement に起こす。
要望から in/out を確定できない項目は、「判断が割れる点の扱い」節に従う。

### Step 3: 受け入れ条件化

in-scope の項目**だけ**を Requirement に起こす。
埋める観点・型・書式は「受け入れ条件の書き方」に従う。

### Step 4: 書き出し

Step 2〜3 の内容を「requirements.jsonc のフォーマット」で `.specs/requirements.jsonc` に書く。

続けて `.specs/feature.jsonc` のメタを揃える。
`feature.jsonc` が無ければ、次の 5 キーだけで新規に作る。
有れば、既存のキーは残し、空のキーだけを埋める。
- `repo`: 今いる worktree の `git rev-parse --path-format=absolute --git-common-dir` の basename
- `title`: 日本語の 20 字以内の名詞句
- `branch_name`: 英小文字・数字・ハイフンだけの `<type>/<短い英語の説明>`。`title` と要件の内容から決める
- `pr_title`: 固定 prefix `【鎌田QA】` で始める。指定があればその文字列の前に付け、prefix が既にあれば足さず、無ければ `【鎌田QA】<title>`
- `notion_url`: 材料に無ければ空文字

### Step 5: 点検

`python3 ~/.claude/skills/spec/check.py` を実行する。
指摘が出たら直して再実行し、`OK` が出るまで繰り返す。
続けて `python3 ~/.claude/skills/_report/render.py .specs/requirements.jsonc` で `.specs/requirements.html` を生成する。
`feature.jsonc` を書いたときは `python3 ~/.claude/skills/_report/render.py .specs/feature.jsonc` で `.specs/feature.html` も作り直す。
生成に失敗したら `.jsonc` は残し、Step 6 で HTML を開く代わりに失敗の内容を添える。

### Step 6: 提示

`open .specs/requirements.html` で HTML を開く。
要確認と未対応のコメントの件数を 1 行で添える。
未対応のコメントは、`.specs/comments.jsonc` の `comments` のうち、`file` が `requirements.html` で `status` が `open` のもの。

要確認か未対応のコメントが 1 件以上なら Step 7 へ進む。
0 件なら「要確認なし。次は `/plan`」の 1 行を添えて終了する。

### Step 7: 要確認とコメントの議論

未解決の要確認か未対応のコメントを 1 件選ぶ。
要確認は、該当する行や項目とあわせてユーザーに尋ねる。
コメントは、`quote` が指す行や項目に本文の意図を反映し、判断が割れるときだけユーザーに尋ねる。
決まったら `requirements.jsonc` の該当行の `text` を決定内容に直し、その行の `question` を空文字にする。
採った解釈のままで決まったときは、`question` だけを空文字にする。
経緯は書かない。
コメントを反映したら、そのコメントの `status` を `done` にする。
直したら `python3 ~/.claude/skills/_report/render.py .specs/requirements.jsonc` で HTML を作り直す。

未解決の要確認か未対応のコメントが残っていれば、Step 7 に戻って次の 1 件を尋ねる。
全件が決まったら「要確認なし。次は `/plan`」の 1 行で終了する。
ユーザーが打ち切ったときは残件数を 1 行で伝えて終了する。
