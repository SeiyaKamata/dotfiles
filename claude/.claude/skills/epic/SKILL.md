---
name: epic
description: 複数の PR に分けて取り込む大きな仕事を、順序付きの feature 一覧として epic.md に計画する。1 つの PR に収まらない要望を受けたとき、または epic の feature が merge されて次に進むときに使う。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(gh pr *), Bash(git *), Bash(mkworktree *)
argument-hint: "<epic>"
---

# epic 計画スキル

## 役割
1 つの目的のために複数の PR を順に取り込む仕事を、feature の順序付き一覧として `.specs/epics/<epic>.md` に書く。
epic は PR も実装ブランチも持たず、feature ごとに 1 本の PR を作る。
epic を知る工程はこのスキルと `/spec` だけで、`/plan` 以降は feature の `requirements.md` だけを見る。
このスキルは org 直下 `Develop/<org>/` で叩く。`.specs` と `repos/` がそこにあり、各リポジトリの bare repo は `repos/<Repo>`。

## 判断が割れる点の扱い
途中でユーザーに質問も承認要求もせず、`epic.md` の書き出しまで走り切る。
feature の切り方と順序で判断が割れる点は最も素直な案を採り、採った案と捨てた案を `## 順序の根拠` に理由付きで書く。
人は書き出された `epic.md` を読んで直しを指示し、進行確認の `/epic` がそれを反映する。

## feature の切り方

- 1 feature は単独で merge しても壊れない単位にする
  - 後続 feature が無くても本番に入れられる状態で切る
- 1 feature は 1 リポジトリに閉じる
  - 複数リポジトリにまたがる仕事はリポジトリごとに feature を切り、受け口を出す側を `準備` として先に置く
- 種別は `準備` `本体` `後片付け` の 3 値
  - `準備`: 本体を安全に入れるための先行変更。既存コードの整理、互換レイヤの追加、別リポジトリ側の受け口
  - `本体`: 目的を実現する変更
  - `後片付け`: 本体が入った後に不要になるものの削除、互換レイヤの撤去
- 順序の制約は `Depends` に先行する feature の番号で表す
  - 並び順だけに依存を委ねない
- 後続の feature は粗く書く
  - 先行 feature が merge されるまで確定しないことは「後続で決めること」に出し、feature の目的欄に書き込まない

## 契約
リポジトリをまたいで合わせる形は `## 契約` に決まった形だけで書く。
API の受け口、リクエストとレスポンスの形、イベント名、共有する型が対象で、理由や比較は書かない。
各 feature の `/spec` が epic.md を読んで受け入れ条件に落とすので、出す側と受ける側の要件が同じ形を指す。
契約を変えるときは epic.md を直し、関わる feature の `/spec` を再実行する。

契約が OpenAPI のようにリポジトリ内のファイルで管理されているなら、形を写さず、そのファイルのパスと変更する feature の番号だけを書く。
単一リポジトリの epic では節ごと省く。

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

PR は feature 一覧の `Repo` 列のリポジトリで `gh pr list --repo <owner>/<repo> --head <feature> --state all --json number,state,isDraft,url` で調べる。
`<owner>/<repo>` は `git -C repos/<Repo> remote get-url origin` から採る。

## epic.md のフォーマット

```markdown
# Epic: [epic 名]

## 目的
[なぜやるか、終わったとき何が変わるかを 2〜3 文で]

## 完了条件
- [epic 全体として満たすべきこと。1 行 1 項目。EARS は使わない]

## feature 一覧
| # | feature | Repo | 種別 | 目的 | Depends |
|---|---|---|---|---|---|
| 1 | [kebab-case の feature 名] | [リポジトリ名] | 準備 | [この feature で何を達成するか 1 行] | |
| 2 | [...] | [...] | 本体 | [...] | 1 |
| 3 | [...] | [...] | 後片付け | [...] | 2 |

## 順序の根拠
[なぜこの順で取り込めば安全か。互換の維持、フラグ、データ移行の方針]

## 契約
[リポジトリをまたいで合わせる形を決まった形だけで。ファイルで管理しているならそのパスと変更する feature の番号]

## 後続で決めること
- [先行 feature が merge されるまで確定しない事項と、どの feature の結果で決まるか]
```

## 進め方

### Step 1: 引数の確認とモード判定

- `$ARGUMENTS[0]` が無ければ「使い方: /epic <epic>」を表示して終了
- epic 名は kebab-case・3〜5 語程度に正規化する

`.specs/epics/<epic>.md` の有無で分岐する:
- **無い**: 新規作成。要望を材料に Step 2 へ
- **有る**: 進行確認。Step 4 へ

### Step 2: 計画

要望を読み、次を決める。

1. 目的と完了条件
2. 1 つの PR で入れられない理由。ここで 1 つの PR に収まると分かれば、epic を作らず `/spec <feature>` を案内して終了する
3. feature の切り方と順序。「feature の切り方」に従う
4. 複数リポジトリにまたがるなら契約。関わるリポジトリのデフォルトブランチを worktree に展開し、現状の受け口と型を読んでから決める
   - `git -C repos/<Repo> fetch origin` で最新化してから `dest=$(mkworktree repos/<Repo> <Repo>-<epic>)` で切る。同名の worktree が既にあればそれを使う
5. 各 feature の名前。`Glob(".specs/*")` で既存の feature 名と重ならないことを確認する

### Step 3: 書き出し

Step 2 の内容を「epic.md のフォーマット」で `.specs/epics/<epic>.md` に書き、Step 5 へ進む。

### Step 4: 進行確認と見直し

- `epic.md` の feature 一覧を読み、「状態の扱い」で各 feature の状態を計算する
- `Depends` の先行 feature がすべて完了している未着手の feature を、次に着手できる feature とする
- 直前に完了した feature があれば、その結果を踏まえて「後続で決めること」に残っている事項のうち決められるものを決め、feature の目的欄に移す
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

| # | feature | Repo | 種別 | 状態 |
|---|---|---|---|---|
| 1 | [...] | [...] | 準備 | 完了 #123 |
| 2 | [...] | [...] | 本体 | PR(draft) #130 |
| 3 | [...] | [...] | 本体 | 未着手 |

### 次の一手
- 次の feature の要件を書く: `/spec <feature>`
- 計画を見直す: `/epic <epic>`
```
