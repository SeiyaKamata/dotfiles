---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
argument-hint: "[<stage>] <feature>"
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキル（工程）を順番に起動する。
**人間承認ゲートを持たず**、要件策定から draft PR + CI green + 未返信の未解決コメント解消まで自走する。成果物の妥当性は `/spec`・`/design`・`/tasks` の完了後に orchestrator が `stage-reviewer` で検証し、NG ならその工程を再起動して直させる。途中の失敗は自己修正ループで潰し、人を呼ぶのは安全停止点・回復不能な詰まりだけにする。

## 用語（前提）
用語は `claude/CLAUDE.md`「用語集」に従う。特に「工程 (stage)」と「フェーズ (phase)」を混同しないこと。フェーズは実装後に `/sync-to-remote` が確定する PR 単位で、実装前には存在しない。
- impl / test / review / qa / commit は feature 単位で動く。フェーズを持たず、実装ブランチ 1 本の上で 1 回ずつ回す。
- watch-ci / resolve-comments だけが PR 単位。PR が確定した後の工程なので、PR の本数ぶん回す。

## 全体フロー

> **フロー正本**: パイプライン全体の流れ（各工程の順序・次工程・戻し先・承認ゲート・scope）は、下のフロー図とこの SKILL.md の「工程一覧」「例外処理」を正本とする。各工程の詳しい手順・注意点・完了後の分岐は「## 工程一覧」の各見出しにまとめてある。停止点の条件は「## 完了条件」を正本とする。

```
/spec →(R)→ /design →(R)→ /tasks →(R)   ※(R) = stage-reviewer
  → 実装（実装ブランチ <feature> 1 本・フェーズを持たない直線）:
        /impl → /test → /review → /qa → /commit
                  ↓FAIL   ↓NG      ↓FAIL
                 /fix    /fix（設計起因なら /design）  /fix（設計起因なら /design・/impl）
                  →/test  →/test→/review              → /test→/review → /qa に再合流
  → PR ループ（/sync-to-remote が分割を判定。1 周 = 1 PR を green まで閉じる）:
        /sync-to-remote(draft, 1 本だけ。初回に分割を判定)
        → /watch-ci(この PR) → /resolve-comments(この PR の全 author)
          ↓CI赤
         ログ取得→自己修正→再push→/watch-ci
        → 未作成の後続フェーズがあれば <feature>-pN へ switch して先頭に戻る
  → 全 PR の最終確認(CI green) → 停止(人に報告)
```

> **人間レビューの依頼タイミングについて**: 人間レビューは `Ready for review` に切り替わってから行う運用のため、自走中（draft のまま）は依頼できない。現状は全 PR が閉じた停止点で人がまとめて Ready にする。PR ごとに Ready にする運用に変える場合は、「工程一覧」の `/sync-to-remote` の PR ループ 10-4 に切替を差し込む。

開始工程を `/orchestrator <stage> <feature>` で任意の位置から指定できる（指定工程より前は実行しない。詳細は「## 開始工程からの起動（ディスパッチ）」）。

## 開始工程からの起動（ディスパッチ）

`/orchestrator [<stage>] <feature>` の `<stage>` にはスラッシュなしの工程名を渡す（例: `design`）。これでパイプラインの任意の工程から開始できる。省略時は従来どおり spec 開始。対象フェーズ（`<feature>-pN`）は引数では受け取らず、常に Step 1-2 で自動推定する。

`<stage>` に工程レジストリの工程名と完全一致する文字列を渡すと開始工程として解釈される。**feature 名がこの 11 語（`spec` `design` `tasks` `impl` `test` `review` `commit` `sync-to-remote` `watch-ci` `resolve-comments` `qa`）のいずれかと完全一致する場合は工程指定と区別できない**ため、その名前は feature 名として使わないこと。

### 工程レジストリ（早見表）

指定可能な開始工程は次の 11 個（`/fix` は自己修正ループの内部工程のため対象外）。「前提成果物」の「+」は 1 つ上の行までの前提をすべて含む。各工程の詳しい手順・注意点は「## 工程一覧」の同名見出しを参照。

**前提成果物は事前チェックしない。** 開始工程をそのまま起動し、不足していれば起動した skill 自身がそれを検知して案内する（各 skill は単体起動でも同じ案内を出す設計になっている）。orchestrator はその案内に従うだけでよい（Step 1-4 参照）。

| 開始工程 | 前提成果物 | 開始 Step | 対象フェーズ | 起動コマンド |
|---|---|---|---|---|
| `spec` | なし | Step 2 | 不要 | `/spec <feature>` |
| `design` | `requirements.md` | Step 3 | 不要 | `/design <feature>` |
| `tasks` | + `design.md` | Step 4 | 不要 | `/tasks <feature>` |
| `impl` | + `tasks.md` | Step 5 | 不要 | `/impl <feature>` |
| `test` | + `tasks.md` | Step 6 | 不要 | `/test <feature>` |
| `review` | + `tasks.md` | Step 7 | 不要 | `/review <feature>` |
| `qa` | + `tasks.md` | Step 8 | 不要 | `/qa <feature>` |
| `commit` | + `tasks.md` | Step 9 | 不要 | `/commit`（feature を渡さない） |
| `sync-to-remote` | + コミット済みの実装 | Step 10-1 | 不要（初回）／必要（再呼び出し） | `/sync-to-remote`（feature を渡さない） |
| `watch-ci` | + 対象 PR | Step 10-2 | 必要 | `/watch-ci <PR番号>`（feature ではなく解決した PR 番号を渡す） |
| `resolve-comments` | + 対象 PR | Step 10-3 | 必要 | `/resolve-comments batch`（引数なし＝カレントブランチの PR） |

フェーズを必要とするのは `watch-ci` / `resolve-comments` / `sync-to-remote` の再呼び出しだけ（PR が確定した後の工程）。それ以外は実装ブランチ 1 本の上で動くのでフェーズを取らない。

### Step 1: 引数解釈・対象フェーズ決定・ブランチ整合・ディスパッチ

1. **Step 1-1: 引数パーサ** — `$ARGUMENTS` を `開始工程 / feature` に分解する。判定順:
   1. 引数が 0 個 → `使い方: /orchestrator [<stage>] <feature>` を表示して終了
   2. 第 1 引数が工程レジストリの工程名（11 語）のいずれかと完全一致する場合
      - 第 2 引数（feature）が無い → `使い方: /orchestrator [<stage>] <feature>` を表示して終了
      - それ以外 → 開始工程 = 第 1 引数、feature = 第 2 引数
   3. それ以外（工程名と一致しない）→ 開始工程 = `spec`、feature = 第 1 引数。従来どおりの後方互換。feature 名が工程レジストリの 11 語と完全一致すると開始工程指定と区別できないため、その名前は feature に使わない
2. **Step 1-2: 対象フェーズの決定** — 工程レジストリで「対象フェーズ: 不要」の工程（`spec`〜`commit` と `sync-to-remote` の初回）はこの Step をスキップする
   1. 下記「状態収集コマンド」で実在するフェーズブランチと PR を得る（材料の理由は「対象フェーズの推定」参照）
   2. 下記「対象フェーズの推定」のルールで対象フェーズを推定する。推定結果と根拠（例:「`myfeature-p1` は PR green + 未返信の未解決コメントなし、`myfeature-p2` は PR 未作成」）を提示して `y/n` を取る。`n` → 該当フェーズの状態（CI・未解決コメント）を確認のうえ再実行するよう促して終了
   3. 対象フェーズの PR が 1 件も存在しない場合はそのまま Step 1-4 へ進む。対象 PR が無いことは `watch-ci` / `resolve-comments` 自身が検知し、`/sync-to-remote` への復帰を案内する（Step 1-4 のリカバリ規則に従う）
   4. 開始工程が `sync-to-remote` の再呼び出しのとき
      - 条件: 対象フェーズ（実在する最大の `pN`）の PR が「CI green かつ未返信の未解決コメントなし」を満たしていない
      - 動作: そのフェーズはまだ閉じきっていないので `sync-to-remote` を呼ばず、`対象フェーズ <pN> の PR がまだ CI green + 未返信の未解決コメントなしを満たしていません。/orchestrator watch-ci <feature> または /orchestrator resolve-comments <feature> から再開してください` を示して終了する
   5. `watch-ci` を開始工程とする場合は、対象フェーズのブランチに対応する PR 番号を解決して起動引数に使う
3. **Step 1-3: ブランチ整合**
   - `impl`〜`commit`（フェーズ不要）から開始する場合 → 実装ブランチ `<feature>` が存在すればそこへ `git switch` する。存在しなければ切り替えない
   - `sync-to-remote` の初回 → 実装ブランチ `<feature>` へ `git switch` する
   - `watch-ci` / `resolve-comments` / `sync-to-remote` の再呼び出し → 対象フェーズのブランチ `<feature>-pN` へ `git switch` する
   - 未コミットの変更があって切り替えられない場合は報告して停止する（stash などの作業ツリー操作はしない）
4. **Step 1-4: ディスパッチ** — 工程レジストリの「開始 Step」へジャンプし、開始工程をそのまま起動する。ジャンプ後の挙動は「工程一覧」の記述そのままとし、以下を追加ルールとする:
   1. 開始 Step より前の Step は実行しない。したがって開始工程が design 以降のときは Step 2（`/spec`）を実行せず、既存の requirements.md を確定済みの成果物として扱う
   2. **前提不足のリカバリ**: 起動した skill が前提成果物の不足（対象 PR が無い場合を含む）を理由に中断したら、その skill 自身の案内に従って不足を生む工程を実行し、完了したら元の開始工程を再実行する。案内された工程を実行してもなお中断する場合は報告して停止する。**事前チェックはしない** — 起動してから skill 自身の判断に従う
   3. **開始工程の指定によって人間承認ゲートを新設しない**。成果物の妥当性は orchestrator が工程の完了後に回す `stage-reviewer` が担保する既存の枠組みのままにする
   4. 開始 Step が Step 10-x のとき、Step 10 の PR ループはその小 Step から始める。対象 PR を閉じたら 10-4 に合流し、未作成の後続フェーズがあれば 10-1 から通常どおり回す
   5. 開始 Step が Step 8（`qa`）のとき、実装済みとみなして実装ブランチで `/qa` を起動する
   6. 停止点（Step 12）と「## 例外処理」の停止条件は、開始工程がどれであっても既存どおり適用される

### 対象フェーズの推定

**フェーズは PR が存在してはじめて決まる**ので、推定材料は実在する PR とフェーズブランチだけ。tasks.md はフェーズ構成を持たないため読まない。

| 対象工程 | 推定ルール |
|---|---|
| `/watch-ci` `/resolve-comments` | PR が存在し「CI green かつ未返信の未解決コメントなし」を満たさない最小フェーズ。該当なしなら PR が存在する最大フェーズ |
| `/sync-to-remote`（再呼び出し） | 実在するフェーズブランチのうち最大の `pN` を対象とする。<br>- 満たす（CI green かつ未返信の未解決コメントなし）→ `<feature>-pN` へ switch して呼ぶ。次フェーズ `p(N+1)` の作成は `/sync-to-remote` 自身が Step 2-6 で行うため、orchestrator は先回りして作らない。<br>- 満たさない → そのフェーズはまだ完了していないので対象外とし、Step 1-2 の追加ルールに従って中断する |

推定は必ず人の確認（`y/n`）を通す。推定精度より根拠を提示できることを優先する。

### 状態収集コマンド

対象フェーズ決定のための調査は inline の Bash で行う（工程自体は確定済みで、必要なのはフェーズ判定だけのため、サブエージェントには委譲しない）。

> **「今どの工程か」の推定はこのスキルが正本。** 中断したセッションの再開もここから入る。`/orchestrator <stage> <feature>` を実行すると、Step 1-2 でフェーズ推定に `y/n` を取ってから走る。**判定表をこの外に複製しないこと** — 別表に分かれると運用への追随が漏れて実態とずれる。

```bash
# 既存ブランチ（実装ブランチとフェーズブランチ）
git branch --list "<feature>-p*" --list "<feature>"

# PR とその状態
gh pr list --search "head:<feature>" --state all \
  --json number,headRefName,isDraft,statusCheckRollup
```

## 工程一覧

パイプラインの実行順に、各工程の起動方法・前提・判断ロジック・完了後の分岐をまとめる。各工程は人が単体で叩くのと同じ形で起動し、同じ完了カードを返す（工程側に呼び出し元による分岐は無い）。**見出しの Step 番号がそのまま実行順序**（Step 1 は「開始工程からの起動」参照）。各工程の「完了後」の分岐が次にどの Step へ進むかを示す。

**完了カードは読み捨てない。** 「要確認」に載る「判断で埋めた点」は、成果物本文には注記が残らないのでカードにしか現れない。これを spec / design / tasks の妥当性検証で `stage-reviewer` へのプロンプトに含める。orchestrator は各工程のカードを受け取ったら、遷移先を 1 行で記録しつつ「要確認」の内容は次のレビューまで保持する。

### 共通: 妥当性検証ループ（spec / design / tasks）

`/spec` `/design` `/tasks` は完了後、orchestrator が `stage-reviewer` を起動して成果物を検証し、NG ならその工程を再起動して直させる（最大 2 巡）。`stage-reviewer` に渡すもの（上流成果物・レビュー対象・検証条件リスト・参照ドキュメント）は各工程の見出しに書く。受け取り側の仕様は `agents/stage-reviewer.md`。

ループ（最大 2 巡）:
```
review_round = 0
loop:
    review_round += 1
    stage-reviewer を起動 → 判定と指摘を受け取る
    if 判定 == OK:
        確定 → 次工程へ
    if review_round == 2:
        人に報告して停止（成果物は未確定。次工程へ進めない）
    対象工程を再起動し、指摘を変更要望として渡す → loop
```
- 再起動は編集モードになる（成果物が既にあるため）。指摘は起動時の変更要望として渡し、対象工程は白紙に戻さず**指摘箇所だけを直す**
- 2 巡目のレビューには前巡の指摘も渡す。反映されたかを見させるためで、`review_round` も渡す
- **「判断できなかった点」は OK 扱いしない。** 1 巡目なら渡した材料から補える範囲を補って再レビューし、2 巡目でも残るなら停止する
- レビューは 1 体で観点 A（上流突合）と観点 B（検証条件リスト）の両方を見る。**観点を分けて複数体を並列起動しない**

### Step 2: `/spec`

- 起動: `/spec <feature>`
- 前提成果物: なし
- 対象フェーズ: 不要

**妥当性検証**: 「共通: 妥当性検証ループ」に従う。`stage-reviewer` に渡すもの:
- 上流成果物: 起動時の要望テキスト + `seed.md`（あれば）
- レビュー対象: `requirements.md`
- 検証条件リスト: `spec/SKILL.md`「書き出し」Step の「書き出しの時点で次を満たす」をそのまま全項目
- 参照ドキュメント: なし

**完了後**:
- OK → `.specs/<feature>/requirements.md` を確定成果物として `/design` へ、承認を待たず次へ
- 2 巡しても収束しない、または要件を確定できない → 報告して停止

### Step 3: `/design`

- 起動: `/design <feature>`
- 前提成果物: `requirements.md`
- 対象フェーズ: 不要

**妥当性検証**: 「共通: 妥当性検証ループ」に従う。`stage-reviewer` に渡すもの:
- 上流成果物: `requirements.md`
- レビュー対象: `design.md`
- 検証条件リスト: `design/SKILL.md`「書き出し」Step の「書き出しの時点で次を満たす」をそのまま全項目
- 参照ドキュメント: なし

**完了後**:
- OK → `.specs/<feature>/design.md` を確定成果物として `/tasks` へ、承認を待たず次へ
- 2 巡しても収束しない → 報告して停止

### Step 4: `/tasks`

- 起動: `/tasks <feature>`
- 前提成果物: + `design.md`
- 対象フェーズ: 不要

**妥当性検証**: 「共通: 妥当性検証ループ」に従う。`stage-reviewer` に渡すもの:
- 上流成果物: `design.md`
- レビュー対象: `tasks.md` + `qa.md`
- 検証条件リスト: `tasks/SKILL.md`「書き出し」Step の「書き出しの時点で次を満たす」をそのまま全項目
- 参照ドキュメント: `tasks/SKILL.md`「大タスク = 関心のグルーピング（PR 単位ではない）」

**完了後**:
- OK → `.specs/<feature>/tasks.md` と `qa.md` を確定成果物として `/impl` へ、承認を待たず次へ
- 2 巡しても収束しない → 報告して停止

### Step 5: `/impl`

- 起動: `/impl <feature>`。実装ブランチ `<feature>` 1 本で全タスクを実装する
- 前提成果物: + `tasks.md`
- 対象フェーズ: 不要

**実行**: `impl/SKILL.md` に従って実装ブランチ `<feature>` を 1 本切って全タスクを実装する。

**完了後**: → `/test` へ

### 共通: 対象確定（test / review / qa / fix）

`/test` `/review` `/qa` `/fix` は会話履歴に依存せず単体でコールド起動しても同じ対象に到達できるよう、起動時に対象 feature と実行コンテキストを自力で確定する。差分なく次の手順をそのまま実行する。

1. feature の確定 — 第 1 引数。未指定なら使い方を表示して終了する。
2. ブランチの確定 — `git branch --show-current` をそのまま採用する。
   - 実装ブランチ `<feature>` にいる → 想定どおり
   - デフォルトブランチにいる（PR を作らない運用で直接コミットしている）→ そのまま続行する
   - detached HEAD → `branch: none` として続行する（レポートは書けるが、後で `/fix` が行う branch 照合の材料が減る）
3. 実行コンテキストの確定 — `feature` / `branch` / `head`（`git rev-parse HEAD`）を確定し、以降の入力導出とレポート出力をこの確定値に基づいて行う。

実行コンテキスト frontmatter（`test-report` / `review` / `qa-report` 共通）:
```yaml
---
feature: stage-context-free
branch: stage-context-free             # detached・照合不可時は none
head: 4f8c1e9b2a...                    # git rev-parse HEAD（40文字。短縮しない）
ran_at: 2026-07-28T22:45:00+0900       # レポートを書き出した時刻
fixed: false                           # 直前に /fix がこのレポートの対象コードを修正していたか
count: 1                               # この判定が何回連続で非 PASS/OK か（PASS/OK なら 1 にリセット）
---
```
収集コマンド（macOS の BSD `date` は `-Iseconds` 非対応なのでフォーマット指定を使う）:
```bash
git branch --show-current                       # branch
git rev-parse HEAD                              # head
date +"%Y-%m-%dT%H:%M:%S%z"                     # ran_at
```
`phase` キーは持たない。これらの工程はフェーズを持たず実装ブランチ 1 本の上で 1 回ずつ回るためで、対象の同一性は `branch` と `head` で判定できる。

**`fixed` の決め方（`/test` `/qa` `/review` 共通）**: 新しいレポートを書き出すときは既存ファイルの値を読まず、**常に `fixed: false` を書く**。これは「まだ `/fix` が着手していない」というレポートの初期状態を表す。`fixed: true` に変えるのは `/fix` だけで、修正を適用したときにそのレポートの `fixed` フィールドだけを直接書き換える。判定内容は変えない — これが `/fix` の唯一のレポート更新である。これにより:

- `fixed: false` のレポート = まだ `/fix` が着手していない、または前回の修正が効かず `/test`/`/qa`/`/review` の再実行で差し戻された状態
- `fixed: true` のレポート = `/fix` が着手済みで、まだ下流の再検証を経ていない状態

`/fix` は自分の Step で `fixed` を読み、`true`（＝二重着手になる）なら中断する（詳細は `/fix` 自身の Step 参照）。

**`count` の決め方（`/test` `/qa` `/review` 共通）**: 保存先を上書きする直前に、既存ファイルの**判定**（PASS/FAIL・OK/NG・PASS/FAIL/BLOCKED）と `count` を読む。今回の判定が非 PASS/OK で、かつ既存ファイルの判定も非 PASS/OK だったなら `count` を **+1** して書く。今回が PASS/OK、または既存ファイルが無い／既存ファイルの判定が PASS/OK だったなら `count: 1` にリセットする。これにより「何連続で失敗しているか」がレポート単体から読み取れ、`/orchestrator` は自分でターンをまたいで数えなくても、書き出された `count` を見るだけで「test FAIL 3 回連続」「review NG 3 回連続」のような停止条件を判定できる（`/orchestrator` がコールドで再開しても数え直しにならない）。


### Step 6: `/test`

- 起動: `/test <feature>`
- 前提成果物: + `tasks.md`
- 対象フェーズ: 不要

保存先: `.specs/<feature>/test-report.md`（feature 単位の固定パス）。

**完了後**:
- PASS → `/review` へ
- FAIL → `/fix <feature>` → `/test <feature>` を再実行。**`test-report.md` の `count` が 3 以上（FAIL 3 回連続）→ 報告して停止**

### Step 7: `/review`

- 起動: `/review <feature>`
- 前提成果物: + `tasks.md`
- 対象フェーズ: 不要

保存先: `.specs/<feature>/review.md`（feature 単位の固定パス）。

**完了後**:
- NG かつ「設計の根本的な問題」が含まれる → `/design` に戻す
- NG かつそれ以外（コード品質・実装ミス）→ `/fix <feature>` → `/test <feature>` → `/review <feature>` を再実行。**`review.md` の `count` が 3 以上（NG 3 回連続）→ 報告して停止**
- OK → `/qa` へ。ただし `review.md` の推奨対応に**上流 doc の記述修正**が挙がっていれば、`/spec`・`/design` を編集モードで再入して記述だけ直す。実装は正しいため `/tasks` と実装はやり直さない

### Step 8: `/qa`

- 起動: `/qa <feature>`
- 前提成果物: + `tasks.md`
- 対象フェーズ: 不要

保存先: `.specs/<feature>/qa-report.md`（feature 単位の固定パス）。

**qa は commit より前にある。** 実装が 1 ブランチで完結するので、PR を作る前に feature 全体の受け入れを確認できる。これにより qa FAIL 時の rebase 伝播が発生しない（まだ PR が無く、実装ブランチ 1 本の上で直せる）。

**完了後**:
- 全 pass → `/commit` へ
- fail → `/fix <feature>`（設計起因なら `/design`・`/impl <feature>`）→ `/test <feature>`→`/review <feature>` を通して `/qa` に再合流。**`qa-report.md` の `count` が 2 以上（非 PASS 2 回連続）→ 報告して停止**

### `/fix` — 自己修正ループの内部工程。開始工程には指定できない

- 起動されるタイミング: `/test` FAIL・`/qa` fail・`/review` NG（設計起因以外）・`/bughunt` 完了のとき、呼び出し元から `/fix <feature>` で起動される
- 対象フェーズ: 不要

**対象確認**: `fix/SKILL.md` の Step 2〜4 に従う。

**完了後**:
- 「設計の問題」と判断 → `/design` に戻す
- design↔impl のループが 2 周しても収束しない → 報告して停止

### Step 9: `/commit`

- 起動: `/commit`（feature を渡さない）
- 前提成果物: + `tasks.md`（実装完了）
- 対象フェーズ: 不要

**実行**: 実装ブランチにコミットする（分割はまだ行わない）。

**完了後**: → `/sync-to-remote`（PR ループ開始）

### Step 10: PR ループ

10-1〜10-4 を PR 1 本ずつ回す。**1 周 = 1 PR を CI green + 未返信の未解決コメントなしまで閉じきる**。未作成の後続フェーズがあれば 10-1 に戻り、無ければ Step 11 へ進む。

### Step 10-1: `/sync-to-remote`

- 起動: `/sync-to-remote`（feature を渡さない）
- 前提成果物: + コミット済みの実装
- 対象フェーズ: 不要（初回）／必要（再呼び出し）

**なぜ PR を 1 本ずつ出すのか（設計意図）**:
- 一斉作成すると、CI と CodeRabbit の指摘が `p1` に返ってくるのが `pN` まで作り終えた後になり、**`p1` の修正が全スタックへの rebase 伝播を要求する**。rebase 伝播は自走で安全に行えないため、PR 数に比例して停止リスクが上がる
- だから `/sync-to-remote` は **1 本作ったら止まる**。その PR が CI green + 未返信の未解決コメントなしになってから、次のフェーズブランチで再度呼ぶ。修正は常に先端で完結し、待ち時間（CI + CodeRabbit）はこの停止リスクより安い
- 前提: **`/sync-to-remote` が着地テストを通した分割点でフェーズを切っている**こと（`/sync-to-remote` Step 2-4）。着地しないフェーズだと単体レビューが成立せず、CodeRabbit が後続フェーズで解消される指摘を大量に出す

**対象フェーズの推定**（再呼び出しのとき）: 「対象フェーズの推定」表の `/sync-to-remote`（再呼び出し）行に従う。

状態収集コマンドは「開始工程からの起動」の「状態収集コマンド」と同じものを使う。

**実行**: `sync-to-remote/SKILL.md` に従う。draft でも CodeRabbit が自動でレビューを開始する。

**完了後**: PR 作成 → `/watch-ci` へ

### Step 10-2: `/watch-ci`

- 起動: `/watch-ci <PR番号>`（feature ではなく解決した PR 番号を渡す。対象フェーズは Step 1-2/1-3 で解決済み）
- 前提成果物: + 対象 PR
- 対象フェーズ: 必要

**実行**: `watch-ci/SKILL.md` に従い、この周で作った PR の CI green を待つ。

**完了後**:
- green → `/resolve-comments` へ
- 赤 → ログを取得して自己修正 → push → 再監視。**2 回直しても green にならなければ報告して停止**

### Step 10-3: `/resolve-comments`

- 起動: `/resolve-comments batch`（引数なし＝カレントブランチの PR。対象フェーズは Step 1-2/1-3 で解決済み）
- 前提成果物: + 対象 PR
- 対象フェーズ: 必要

`/resolve-comments` は処理方式に選択肢がある（1 件ずつ確認 / 全件を自己確定）。自走では止まれないので `batch` を付けて起動する。

**未解決コメント対応ループ**（この PR について最大 2 巡）:
- `/resolve-comments` の Step 2 のコマンドで PR のレビュー／コメントを取得し、**現在の HEAD コミットより後**の `coderabbitai[bot]` のレビューが届くまでポーリングする。1 巡目は最初のレビュー、2 巡目以降は push 後の再レビューを待つ。一定時間来なければ報告して停止する
- CodeRabbit は対応済みと判断したスレッドを自分で resolve するため CodeRabbit 分の未解決コメントは自動で消える。人間分は `/resolve-comments` の返信済み判定で消える。未返信の未解決コメントの有無が終了シグナルになる
- 未返信の未解決コメントが**あり** → `/resolve-comments batch` を起動（人間 + CodeRabbit の全 author を対応）→ `/commit` → push → `/watch-ci` に戻る（push で CI も再レビューも自動で再実行される）
- 未返信の未解決コメントが**なし** → 完了後の分岐へ
- 2 巡しても未返信の未解決コメントが残る → 報告して停止

**完了後**:
- 未返信の未解決コメントなし かつ 未作成の後続フェーズがある → 今閉じたフェーズのブランチ `<feature>-pN` へ `git switch` して `/sync-to-remote` に戻る。次のフェーズ `<feature>-p(N+1)` はまだ存在せず、`/sync-to-remote` が再呼び出しと判定した際に自分で作るため、orchestrator 側で先回りして作ったり switch したりしない
- 未返信の未解決コメントなし かつ 未作成の後続フェーズがない → Step 10-4 へ

### Step 10-4: 人間レビューの依頼（保留中の差し込み位置）

現状は何もせず Step 11 へ進む。PR ごとに人間レビューを回す運用にする場合、この位置で `gh pr ready <PR番号>` に切り替える（会社ルール上、人間レビューは Ready 以降のため）。現状は自走では切り替えない。

### Step 11: 全 PR の最終確認

全 PR が CI green であることを確認する。各周では閉じているが、後続 PR の push で状態が動いている可能性があるため、ここで一度まとめて見る。

**完了後**:
- 全 PR green → Step 12 へ
- CI が崩れていれば該当 PR について Step 10-2 を回し直す

### Step 12: 停止点

「## 完了条件」を満たしたら、PR の URL と結果を人に報告して止まる。

### 共通: 実装中の変更（前進カスケード）

実装中（`/impl`〜`/fix` を含む工程一覧の各工程）に仕様・設計・タスクの変更が必要になった場合は、変更が生じた工程から編集モードで再入し、OK の前進チェーンを辿り直す。どの工程から再入するか（＝影響範囲の判断）は次に従う：

- 要件が変わる → `/spec <feature>`（編集）→ `/design`（編集）→ `/tasks`（編集）→ 実装へ
- 設計だけ変わる → `/design <feature>`（編集）→ `/tasks`（編集）→ 実装へ
- タスクだけ変わる → `/tasks <feature>`（編集）→ 実装へ

各スキルは編集モードの再入時に上流 doc との整合を自分で再チェックし、ズレがあれば差分だけを patch する。この判断は `/orchestrator` 駆動かどうかに関わらず適用される（`/impl`・`/fix` など、どのスキルが変更の必要性に気づいた場合でも同じ基準で再入先を決める）。

## 例外処理（人を呼ぶ＝停止する条件）
回復可能なものは自己修正ループで潰し、以下のときだけ停止して人に報告する。各工程固有の停止条件（test FAIL 3 連続・review NG 3 連続・qa↔fix 2 周・CI 失敗 2 回・未解決コメント 2 巡など）は「## 工程一覧」の該当工程「完了後」に書いてあるので、ここでは工程をまたぐ／ディスパッチ由来の条件だけを挙げる：

- **CodeRabbit のレビューが一定時間来ない** → 報告して停止
- 各スキルが判断できない（要件の曖昧さ等）→ 報告して指示を仰ぐ
- **引数が不正**（引数なし・工程指定に feature が無い）→ Step 1-1 のエラーメッセージを表示して終了
- **前提成果物が不足しており、案内された工程を実行してもなお起動した skill が中断する** → 中断理由と復帰コマンドを示して終了（Step 1-4）
- **推定した対象フェーズが人に否認された（`n`）** → 該当フェーズの状態（CI・未解決コメント）を確認のうえ再実行するよう促して終了（Step 1-2）
- **対象フェーズのブランチへ切り替えられない**（未コミットの変更がある）→ 報告して停止し、stash などの作業ツリー操作は行わない（Step 1-3）
- **`/test` `/review` `/qa` `/fix` が対象確定の前提破れ（入力欠損・レポートの stale）で中断した** → orchestrator はこれを停止条件として扱い、工程が出した中断理由をそのまま人に報告して停止する（orchestrator 側で回避や再試行は行わない）
- **`/watch-ci` `/resolve-comments` がフェーズの前提破れ（形式不正・ブランチ不存在・推定不能・ブランチ不一致）で中断した** → 同様に停止する（フェーズとブランチは Step 1-2・1-3 で合わせて渡しているため、本来この中断は起きない前提だが、起きた場合は前提が崩れているとみなす）

## 完了条件
draft PR（分割したなら stacked PR 群）が作られ、CI が green、未返信の未解決コメントが無い状態を、PR の URL とともに人に報告したら完了。
Ready for review への切替・merge は人が判断する。

## 完了カード
停止点に到達したら、Step 12 の報告を次の完了カードに畳む。コードフェンス自体は出さずに中身だけそのまま出力して終了する。
カードの前後に作業サマリ・所感・補足を足さない。

- 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（PR の本数と分割理由・CI / CodeRabbit の状態など）。工程ごとの経過は各工程の成果物に寄せ、カードには列挙しない。開始工程を指定して起動した場合は、主要な結果に開始工程（例: `開始工程: /design`）を含める。分割した場合は、既定の単一 PR から外れた判断なので `/sync-to-remote` が報告した分割理由を 1 行含める。
- 生成物の行は**全 PR を 1 本 1 行**で本数ぶん出す。行数上限は主要な結果にだけ課すので、PR が n 本なら生成物も n 行になる。
- 各工程の `⏳` は各スキルが自分で出すので、orchestrator が工程開始の実況を代わりに出さない。

```markdown
### パイプライン完走（停止点）
<feature 名と PR 本数・到達状態を 1 行>
- <主要な結果 最大 3 行>

生成物:
- <PR 1 の URL>
- <PR N の URL>

### 次の一手
- OK: Ready for review / merge を判断（人）
```

「例外処理」の停止条件に当たって完走できずに終了するときは、同じ構成でヘッダを `### パイプライン中断` に差し替え、一言サマリに停止理由（test FAIL 3 連続・未解決コメント対応が2巡しても収束しないなど）、次の一手に復帰の判断先を書く（作成済みの PR があれば生成物の行は残す）。
