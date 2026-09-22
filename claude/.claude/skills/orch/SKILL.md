---
name: orch
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
allowed-tools: Read, Edit, Bash(git *), Bash(gh *), Skill, Agent
argument-hint: "<feature> [<stage>]"
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各工程を順番に起動する。
人間承認ゲートを持たず、要件策定から draft PR + CI green + 未返信の未解決コメント解消まで自走する。
`/spec`・`/design`・`/tasks` の成果物は工程別レビュアーで検証し、NG ならその工程を再起動して直させる。
途中の失敗は自己修正ループで潰し、人を呼ぶのは停止点と回復不能な詰まりだけにする。

各工程は人が単体で叩くのと同じ形で起動し、同じ完了カードを返す。
全工程を実装ブランチ 1 本の上で回し、PR は feature につき 1 本にする。

## 判断が割れる点の扱い
完了カードは人向けの区切りではなく工程間の引き継ぎ情報なので、各工程がカードを出しても応答を終えず、同じ応答内で次のアクションを続ける。
ユーザーの応答を待って止まるのは、Step 15 の停止点に到達したときと「停止条件」に該当したときだけ。

既定の遷移は各工程の完了カードの「次の一手」に従い、orch はその指示どおりに次を起動する。
各工程の「完了後」には、ループの停止閾値やカードの判定区分をまたぐ判断のように、カードだけでは分からない orch 固有の判断だけを書く。

カードの「要確認」は読み捨てない。
判断で埋めた点は成果物本文に注記が残らずカードにしか現れないので、次のレビューまで保持して工程別レビュアーへのプロンプトに含め、停止点の報告にも含める。

## 工程レジストリ
開始工程を `/orch <feature> [<stage>]` で指定でき、指定工程より前は実行しない。
`/fix` `/sync` は自己修正ループの内部工程、`/quick` は Step 3 の分岐で内部的に呼ばれる軽量ルートなので、開始工程には指定できない。

| 開始工程 | 開始 Step | 起動コマンド |
|---|---|---|
| `spec` | Step 3 | `/spec <feature>` |
| `design` | Step 4 | `/design <feature>` |
| `tasks` | Step 5 | `/tasks <feature>` |
| `scenarios` | Step 5 の `/scenarios` 起動から | `/scenarios <feature>` |
| `impl` | Step 6 | `/impl <feature>` |
| `test` | Step 7 | `/test <feature>` |
| `review` | Step 8 | `/review <feature>` |
| `qa` | Step 9 | `/qa <feature>` |
| `commit` | Step 10 | `/commit` |
| `land` | Step 11 | `/land <feature>` |
| `watch-ci` | Step 12 | `/watch-ci <feature>` |
| `triage-comments` | Step 13 | `/triage-comments <feature>` |

前提成果物は事前チェックせず、開始工程をそのまま起動する。
不足していれば起動した skill 自身が検知して案内するので、案内された工程を実行してから元の開始工程を再実行し、それでも中断すれば報告して停止する。
対象ブランチ・対象 PR の解決も起動先の skill 自身が `<feature>` から行い、orch は先回りして用意しない。

## 妥当性検証ループ
`/spec` `/design` `/tasks` は完了後、orch が対象工程のレビュアーを起動して成果物を検証し、NG ならその工程を再起動して直させる。
レビュアーは PdM の代役で、成果物が上流の意図を満たす正当な中身かだけを見る。
書式への適合は各工程の点検 Step が担うので、レビュアーには渡さない。

| 工程 | レビュアー | 上流成果物 | レビュー対象 | 参照ドキュメント |
|---|---|---|---|---|
| `/spec` | `spec-reviewer` | 起動時の要望テキスト + 既存の `requirements.md`(あれば) | `requirements.md` | なし |
| `/design` | `design-reviewer` | `requirements.md` | `design.md` | なし |
| `/tasks` | `tasks-reviewer` | `design.md` + `requirements.md` | `tasks.md` | `tasks/SKILL.md`「大タスク = 関心のグルーピング」 |

```
review_round = 0
loop:
    review_round += 1
    対象工程のレビュアーを起動 → 判定と指摘を受け取る
    if 判定 == OK:
        確定 → 次工程へ
    if review_round == 2:
        人に報告して停止
    対象工程を再起動し、指摘を変更要望として渡す → loop
```

- 再起動した工程は成果物が既にあるので、白紙に戻さず指摘箇所だけを直す
- 2 巡目のレビューには前巡の指摘と `review_round` も渡し、反映されたかを見させる
- 「判断できなかった点」は OK 扱いしない
  - 1 巡目なら渡した材料から補える範囲を補って再レビューし、2 巡目でも残るなら停止する
- レビュアーの「要確認」は判定を止めず、OK なら次工程へ進んで内容を保持する
- レビューは 1 体で上流との突合と中身の正当性の両方を見る。観点を分けて複数体を並列起動しない

`/scenarios` はレビュアーを持たず、skill 自身の点検で確定する。

## 進め方

### Step 1: 引数の確認
- 引数が 0 個なら「使い方: /orch <feature> [<stage>]」を表示して終了
- 第 1 引数を feature、第 2 引数を開始工程にする。無ければ `spec`
- 第 2 引数が工程レジストリの 12 語と完全一致しなければ同じ使い方を表示して終了

### Step 2: ディスパッチ

工程レジストリの「開始 Step」へジャンプし、開始工程をそのまま起動する。
開始 Step より前の Step は実行せず、既存の成果物を確定済みとして扱う。

### Step 3: `/spec`

「妥当性検証ループ」で確定する。
要件を確定できなければ停止する。

確定したら `requirements.md` の frontmatter `quick_eligible` で分岐し、orch は判定し直さない。
- `true` → `/scenarios <feature>` で `qa.md` を作り、続けて `/quick <feature>` へ。完了後は quick のカードに従い `/test` または `/review` へ
  - `qa.md` は Step 9 の `/qa` が読むので、quick ルートでも実装の前に必ず作る
  - `/quick` が中断カードで `/design` への合流を提示したら、それに従う
- `false` → `/design` へ

### Step 4: `/design`

「妥当性検証ループ」で確定したら `/tasks` へ。

### Step 5: `/tasks`

「妥当性検証ループ」で確定したら `/scenarios <feature>` で `qa.md` を作り、完了したら `/impl` へ。
開始工程が `scenarios` のときは `/tasks` を実行せず、ここの `/scenarios` 起動から始める。

### Step 6: `/impl`

実装ブランチ `<feature>` 1 本の上で全タスクを実装する。

### Step 7: `/test`

完了後: `test-report.md` の `count` が 3 以上なら報告して停止。

### Step 8: `/review`

完了後:
- `review.md` の `count` が 3 以上なら報告して停止
- OK でも推奨対応に上流 doc の記述修正が挙がっていれば、`/spec`・`/design` を再実行して記述だけ直す。実装は正しいので `/tasks` と実装はやり直さない

### Step 9: `/qa`

qa は commit より前に置き、実装が作業ツリーにあるうちに feature 全体の受け入れを確認する。

完了後: `qa-report.md` の `count` が 2 以上なら報告して停止。

### `/fix`

`/test` FAIL・`/qa` FAIL・`/watch-ci` 赤・設計起因以外の `/review` NG・`/bughunt` 完了のとき、呼び出し元のカードに従って `/fix <feature>` を起動する。
対象確認は `fix/SKILL.md` の Step 2 に従う。

完了後:
- 「設計の問題」と判断 → `/design` に戻す
- design と impl のループが 2 周しても収束しない → 報告して停止

### Step 10: `/commit`

実装ブランチにコミットし、カードの次の一手 `/land` へ進む。

### Step 11: `/land`

対象ブランチの解決は `/land` 自身が行う。
PR 本文の `@coderabbitai ignore` で自動レビューは走らないので、PR ができたら orch が `gh pr comment <PR番号> --body "@coderabbitai review"` を打って最初のレビューを発火させ、カードの次の一手 `/watch-ci` へ進む。
以降 CodeRabbit のレビューは orch が打った時だけ走る。

### Step 12: `/watch-ci`

PR の CI green を待つ。
- green → Step 13 へ
- 赤 → `/fix <feature>` → `/commit` → `/sync <feature>` → `/watch-ci` に戻る
  - `/sync` は `comment-report.md` に未チェックの項目が無ければ push だけして戻る

完了後: `ci-report.md` の `count` が 3 以上なら報告して停止。

### Step 13: コメント対応

`/triage-comments <feature>` を実行し、`comment-report.md` の各項目の承認欄を orch 自身が埋める。
- 提示された「提案」をそのまま採用する
- 裏取りが `未検証` のまま、または分類の確信が持てないと明記された件は `保留` にする
  - `/sync` が保留の返信と issues.md 記録を行うので、拾うかは人が issues.md で判断する

承認欄を埋めたら `/fix <feature>` で `対応する` の項目を修正し、`/commit` → `/sync <feature>` で push・返信・issues.md 記録まで行う。
続けて orch が `gh pr comment <PR番号> --body "@coderabbitai review"` を打って再レビューを発火し、`/watch-ci` に戻る。

このループは最大 2 巡。
- `/triage-comments` の Step 2 のコマンドで PR のコメントを取得し、現在の HEAD より後の `coderabbitai[bot]` のレビューが届くまでポーリングする。一定時間来なければ報告して停止する
- CodeRabbit は対応済みと判断したスレッドを自分で resolve し、人間分は `/triage-comments` の選別済み判定で消えるので、未返信の未解決コメントの有無が終了シグナルになる
- 2 巡しても未返信の未解決コメントが残れば報告して停止する

完了後: 未返信の未解決コメントなし → Step 14 へ

### Step 14: 人間レビューの依頼

保留中の差し込み位置で、現状は何もせず Step 15 へ進む。
人間レビューを回す運用にする場合、ここで `gh pr ready <PR番号>` に切り替える。

### Step 15: 停止点

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
Ready for review への切替と merge は人が判断する。
「停止条件」に当たって完走できずに終了するときは見出しを `### パイプライン中断` にし、1 行目に停止理由を書き、作成済みの PR があれば生成物の行を残し、次の一手は復帰の判断先にする。
各工程の `⏳` は各スキルが自分で出すので、orch が工程開始の実況を代わりに出さない。

```markdown
### パイプライン完走
<feature 名と到達状態を 1 行>
- <開始工程を指定して起動したなら `開始工程: /design` の形で>
- <保持していた要確認>

生成物:
- <PR の URL>

### 次の一手
- Ready for review / merge を判断する
```

## 前進カスケード
実装中に仕様・設計・タスクの変更が必要になったら、変更が生じた工程から再入し、OK の前進チェーンを辿り直す。
どのスキルが変更の必要性に気づいた場合でも、`/orch` 駆動かどうかに関わらず同じ基準で再入先を決める。

- 要件が変わる → `/spec <feature>` → `/design` → `/tasks` → `/scenarios` → 実装へ
- 設計だけ変わる → `/design <feature>` → `/tasks` → `/scenarios` → 実装へ
- タスクだけ変わる → `/tasks <feature>` → 実装へ
- QA シナリオだけ変わる → `/scenarios <feature>` → 実装へ

各スキルは再入時に上流 doc との整合を自分で再チェックし、ズレがあれば差分だけを直す。

## 停止条件
各工程固有の停止条件は該当 Step の「完了後」にある。
ここでは工程をまたぐ条件だけを挙げる。

- CodeRabbit のレビューが一定時間来ない
- 各スキルが判断できないと報告した
- 前提成果物が不足しており、案内された工程を実行してもなお起動した skill が中断する
- `/test` `/review` `/qa` `/fix` が対象確定の前提破れで中断した
  - 工程が出した中断理由をそのまま人に報告し、orch 側で回避や再試行はしない
- `/land` `/sync` `/watch-ci` `/triage-comments` `/fix` が対象ブランチ・PR の解決に失敗して中断した
  - 対象解決は各 skill 自身の責任で、orch は代わりに調べ直さない
