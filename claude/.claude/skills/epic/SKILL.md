---
name: epic
description: 複数の PR に分けて取り込む大きな仕事を、順序付きの feature 一覧として epic.md に計画する。1 つの PR に収まらない要望を受けたとき、または epic の feature が merge されて次に進むときに使う。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(gh pr *), Bash(git *)
argument-hint: "<epic>"
---

# epic 計画スキル

## 役割
1 つの目的のために複数の PR を順に取り込む仕事を、feature の順序付き一覧として `.specs/epics/<epic>.md` に書く。
epic は PR も実装ブランチも持たず、feature ごとに 1 本の PR を作る。
epic を知る工程はこのスキルと `/spec` だけで、`/plan` 以降は feature の `requirements.md` だけを見る。

## 判断が割れる点の扱い
このスキルは人と会話しながら進める。
どの順で取り込むか、どこで feature を切るかは取り込み方の判断なので、迷ったら地の文で問いを出して応答を待ち、決めたことだけを epic.md に書く。
`【要確認】` の付記は使わない。

## feature の切り方

- 1 feature は単独で merge しても壊れない単位にする
  - 後続 feature が無くても本番に入れられる状態で切る
- 種別は `準備` `本体` `後片付け` の 3 値
  - `準備`: 本体を安全に入れるための先行変更。既存コードの整理、互換レイヤの追加、別リポジトリ側の受け口
  - `本体`: 目的を実現する変更
  - `後片付け`: 本体が入った後に不要になるものの削除、互換レイヤの撤去
- 順序の制約は `Depends` に先行する feature の番号で表す
  - 並び順だけに依存を委ねない
- 後続の feature は粗く書く
  - 先行 feature が merge されるまで確定しないことは「後続で決めること」に出し、feature の目的欄に書き込まない

## 状態の扱い
epic.md に進行状態を保存しない。
状態は実行時に `.specs/<feature>/` の成果物と PR から計算して表示する。
epic.md が変わるのは計画そのものが変わったときだけにし、他の worktree との同期の問題を作らない。

| 状態 | 判定 |
|---|---|
| 完了 | feature 名のブランチの PR が merged |
| PR | feature 名のブランチの PR が open。draft なら `PR(draft)` |
| 実装中 | `.specs/<feature>/plan.md` がある |
| 計画中 | `.specs/<feature>/requirements.md` がある |
| 未着手 | `.specs/<feature>/` が無い |

PR は現在のリポジトリで `gh pr list --head <feature> --state all --json number,state,isDraft,url` で調べる。
別リポジトリの feature は現在のリポジトリからは見つからないので、成果物だけで判定し、状態に `PR 未確認` を添える。

## epic.md のフォーマット

```markdown
# Epic: [epic 名]

## 目的
[なぜやるか、終わったとき何が変わるかを 2〜3 文で]

## 完了条件
- [epic 全体として満たすべきこと。1 行 1 項目。EARS は使わない]

## feature 一覧
| # | feature | 種別 | 目的 | Depends |
|---|---|---|---|---|
| 1 | [kebab-case の feature 名] | 準備 | [この feature で何を達成するか 1 行] | |
| 2 | [...] | 本体 | [...] | 1 |
| 3 | [...] | 後片付け | [...] | 2 |

## 順序の根拠
[なぜこの順で取り込めば安全か。互換の維持、フラグ、データ移行の方針]

## 後続で決めること
- [先行 feature が merge されるまで確定しない事項と、どの feature の結果で決まるか]
```

## 進め方

### Step 1: 引数の確認とモード判定

- `$ARGUMENTS[0]` が無ければ「使い方: /epic <epic>」を表示して終了
- epic 名は kebab-case・3〜5 語程度に正規化する

`.specs/epics/<epic>.md` の有無で分岐する:
- **無い**: 新規作成。会話文脈の要望を材料に Step 2 へ
- **有る**: 進行確認。Step 4 へ

### Step 2: 計画の会話

要望を読み、次を人と詰める。
決まるまで書き出さない。

1. 目的と完了条件
2. 1 つの PR で入れられない理由。ここで 1 つの PR に収まると分かれば、epic を作らず `/spec <feature>` を案内して終了する
3. feature の切り方と順序。「feature の切り方」に従う
4. 各 feature の名前。`Glob(".specs/*")` で既存の feature 名と重ならないことを確認する

### Step 3: 書き出し

Step 2 の内容を「epic.md のフォーマット」で `.specs/epics/<epic>.md` に書き、Step 5 へ進む。

### Step 4: 進行確認と見直し

- `epic.md` の feature 一覧を読み、「状態の扱い」で各 feature の状態を計算する
- `Depends` の先行 feature がすべて完了している未着手の feature を、次に着手できる feature とする
- 直前に完了した feature があれば、その結果を踏まえて「後続で決めること」に残っている事項を人と詰め、決まった分を feature の目的欄に移す
  - 切り方や順序が変わるなら feature 一覧を直す。着手済みの feature の名前は変えない
- 変更があれば `epic.md` を上書きする

### Step 5: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
新規作成では状態の表を省き、次の一手は feature 1 の `/spec` だけにする。
全 feature が完了していれば 1 行目に epic が完了した旨を書き、次の一手を省く。

```markdown
### epic 計画完了
<epic 名と、何 feature に分けたか、または今どこまで進んだかを 1 行>

生成物: `.specs/epics/<epic>.md`

| # | feature | 種別 | 状態 |
|---|---|---|---|
| 1 | [...] | 準備 | 完了 #123 |
| 2 | [...] | 本体 | PR(draft) #130 |
| 3 | [...] | 本体 | 未着手 |

### 次の一手
- 次の feature の要件を書く: `/spec <feature>`
- 計画を見直す: `/epic <epic>`
```
