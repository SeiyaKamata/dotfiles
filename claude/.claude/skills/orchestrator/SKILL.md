---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
argument-hint: "<feature>"
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキル（工程）を順番に起動する。
**人間承認ゲートを持たず**、`/spec <feature> auto` から draft PR + CI green + CodeRabbit のコメント解決まで自走する。要件の妥当性は `/spec` 内の spec-review-agents（形式・内容の 2 体）が検証する。途中の失敗は自己修正ループで潰し、人を呼ぶのは安全停止点・回復不能な詰まりだけにする。

## 用語（前提）
用語は `claude/CLAUDE.md`「用語集」に従う。特に：
- **工程 (stage)** = パイプラインの各段階（各スキル）。
- **フェーズ = 大タスク = ブランチ = 1 PR**。tasks.md が大タスクを 1 フェーズに 1:1 で割る。複数フェーズ = **stacked PR**（`pN` を `p(N-1)` にスタック）。
- **test / review / commit / create-pr / watch-ci / resolve-comments はフェーズ単位**（PR 単位で閉じる）。各フェーズは **PR を出して CI green + CodeRabbit 解決まで済ませてから次フェーズを積む**。
- **qa だけは feature 全体の受け入れゲート**なので**全フェーズ実装後に 1 回だけ**回す。

### なぜフェーズごとに PR を出すのか（設計意図）
全フェーズを積んでから PR を一斉作成すると、CI と CodeRabbit の指摘が `p1` に返ってくるのが `pN` まで積み終わった後になり、**`p1` の修正が全スタックへの rebase 伝播を要求する**。rebase 伝播は自走で安全に行えない＝人を呼ぶ停止条件（下記「例外処理」）なので、フェーズ数に比例して停止確率が上がる。フェーズごとに PR を閉じれば、修正は常に先端ブランチで完結し、伝播が必要なのは qa FAIL 時だけになる。待ち時間（CI + CodeRabbit）はこの停止リスクより安い。

この運用は **tasks が縦割り原則でフェーズを割っている**ことが前提（`/tasks` の「フェーズの割り方（縦割り原則）」参照）。横割りのフェーズだと単体レビューが成立せず、CodeRabbit が後続フェーズで解消される指摘を大量に出すため、この前倒しは機能しない。

## パイプライン

> **フロー正本**: パイプライン全体の流れ（各工程の順序・次工程・戻し先・承認ゲート・scope）は、下のフロー図とこの SKILL.md の「進め方」「例外処理」を正本とする。各工程の完了条件（done）は各スキルの「## 完了条件」を正本とする。工程を進める／戻すときはここを参照して判断する。

```
/spec auto →（要件レビュー: spec-review-agents）→ /design →(分岐)→ [/prototype] → /tasks
  → フェーズループ（大タスクごと・依存順・stacked / 1 周 = 1 PR を green まで閉じる）:
        /impl pN → /test → /review → /commit
          ↓FAIL          ↓NG
         /fix→/test     /design or /impl に戻す
        → /create-pr(draft, このフェーズの 1 PR だけ)
        → /watch-ci(この PR) → /resolve-comments(CodeRabbit のみ)
          ↓CI赤
         ログ取得→自己修正→再push→/watch-ci
        → 次フェーズへ（前フェーズの PR は green + コメント解決済み）
  → 全フェーズ完了後（最終スタックブランチ = 全実装）:
        /qa
         ↓FAIL
        原因フェーズを特定し /fix（設計起因なら /design・/impl）
        → 該当フェーズの /test→/review→/commit → stack を rebase 伝播
        → 影響 PR の /watch-ci→/resolve-comments → /qa に再合流
  → 全 PR の最終確認(CI green + CodeRabbit 未解決なし) → 停止(人に報告)
```

要件の妥当性は **`/spec` 内の spec-review-agents（形式・内容の 2 体、最大 2 巡）が担保する**。人間の承認は待たず、レビューが通り次第そのまま自走する。
停止点: **draft PR（複数なら stacked PR 群）+ 全 PR が CI green + CodeRabbit の未解決コメントが無い状態**で人に報告して止まる。merge と Ready for review への切替は人が判断する（自走では行わない）。

> **人間レビューの依頼タイミングについて**: 人間レビューは `Ready for review` に切り替わってから行う運用のため、自走中（draft のまま）は依頼できない。現状は**全フェーズ完了後の停止点で人がまとめて Ready にする**。フェーズごとに Ready にする運用に変える場合は、フェーズループ Step 7-8（下記）に切替を差し込む。

## 自走モードの起動（重要）
人間承認を待つステップを持つスキルは **`auto` 引数**で起動して承認をスキップする。各スキルの `auto` 時の挙動は、それぞれの SKILL.md の「自走モード（`auto` 引数）」節に定義されている：

- **`auto` つきで起動するスキル**: `/spec auto` / `/design auto` / `/prototype auto` / `/tasks auto` / `/impl … auto` / `/test <feature> auto` / `/fix <feature> auto` / `/review auto` / `/qa auto` / `/commit auto` / `/create-pr auto` / `/watch-ci auto` / `/resolve-comments auto`。人間承認を待たず自己レビューゲートで進む（各スキルは `auto` 時に完了カードを出さず 1 行の簡易ログのみ残す）
- **prototype**: 目視承認の代わりに Playwright での操作確認＋スクショ取得。**動くコードを `<feature>-proto` ブランチに残す**（後段の impl が「参照して昇格」で流用する）。design.md へ書き戻したら次へ
- **commit**: フェーズループの中で各フェーズのブランチにコミットする（PR 作成はこの直後）
- **create-pr**: `auto` 引数で**フェーズループの中で**起動し、**そのフェーズの PR を 1 本だけ**作る（`p1` の base = デフォルトブランチ、`pN` の base = `<feature>-p(N-1)`）。単一フェーズなら通常の 1 PR（base = デフォルトブランチ）。未コミットがあれば `/commit auto` を自動で呼ぶ。Notion URL が最初の指示にあれば引数で渡す
- **watch-ci**: `auto` 引数で**フェーズループの中で**起動する。対象はそのフェーズの PR（既に作成済みの下位フェーズ PR も列挙対象に入るが、既に green なので追加コストは小さく、rebase で壊れていないかの確認になる）。CI green でも **Ready for review に自動で切り替えない**。draft のまま次へ
- **resolve-comments**: `auto` 引数で**フェーズループの中で**起動する。次フェーズを積む前に、そのフェーズの CodeRabbit 指摘を解消しきる（これが rebase 伝播を避ける肝）

## 進め方
1. `$ARGUMENTS[0]` を feature 名として使う。未指定なら「使い方: /orchestrator <feature>」を表示して終了
2. `/spec <feature> auto` を起動し、`.specs/<feature>/requirements.md` を生成する（spec-review-agents によるレビューを経て確定。承認を待たず次へ）
3. `/design <feature> auto` を起動し、`.specs/<feature>/design.md` を生成 → 承認を待たず次へ
4. **prototype 分岐判定**（下記「prototype 分岐」参照）
   - 必要 → `/prototype <feature> auto` を起動 → design.md 更新後に次へ
   - 不要 → そのまま次へ
5. `/tasks <feature> auto` を起動し、`.specs/<feature>/tasks.md` を生成 → 承認を待たず次へ
6. tasks.md を読んで**フェーズ構成（大タスク数）**を確認する。大タスク = フェーズ = 1 PR = 1 ブランチ。複数フェーズは依存順に並べる（stacked PR になる）
7. **フェーズループ**: 各フェーズ pN を依存順に、以下のフルサイクルで回す（単一フェーズなら 1 周だけ）。**1 周 = 1 PR を CI green + CodeRabbit 解決まで閉じきる**。qa 以外の工程はすべてこのループ内＝PR 単位：
   1. `/impl <feature> [pN] auto` を起動（単一は `<feature>`、複数は `pN`。`pN` のブランチは `p(N-1)` にスタック）
   2. `/test <feature> auto` を起動し PASS / FAIL を確認。FAIL → `/fix <feature> auto` → `/test <feature> auto` を再実行（test FAIL 3連続で停止）
   3. `/review <feature> auto` を起動。NG は下記「例外処理」（設計起因は `/design auto`→`/impl`、それ以外は `/impl` に戻す）
   4. `/commit auto` を起動し、**このフェーズのブランチにコミットする**
   5. `/create-pr auto` を起動し、**このフェーズの draft PR を 1 本だけ**作る（base = `p(N-1)`、`p1` と単一フェーズはデフォルトブランチ）。draft でも CodeRabbit が自動でレビューを開始する
   6. `/watch-ci auto` を起動し、この PR の CI green を待つ。赤ならログを取得して自己修正 → push → 再監視（2回直しても green にならなければ報告して停止）
   7. **CodeRabbit コメント対応ループ（このフェーズについて最大2巡）**:
      - `/resolve-comments` の Step 2 のコマンドで PR のレビュー／コメントを取得し、**現在の HEAD コミットより後**の `coderabbitai[bot]` のレビューが届くまでポーリングする（1巡目は最初のレビュー、2巡目以降は push 後の再レビュー。一定時間来なければ報告して停止）
      - CodeRabbit は対応済みと判断したスレッドを**自分で resolve する**ため、`isResolved == false` の有無が終了シグナルになる
      - 未解決コメントが**あり** → `/resolve-comments auto` を起動（CodeRabbit のみ対応）→ `/commit auto` → push → **6 に戻る**（push で CI も再レビューも自動で再実行される）
      - 未解決コメントが**なし** → 8 へ
      - 2巡しても未解決コメントが残る → 報告して停止
   8. **（保留中の差し込み位置）人間レビューの依頼**: 現状は何もせず次へ進む。フェーズごとに人間レビューを回す運用にする場合、この位置で `gh pr ready <PR番号>` に切り替える（会社ルール上、人間レビューは Ready 以降のため）。**現状は自走では切り替えない**
   9. 次フェーズへ（前フェーズは commit 済み・CI green・コメント解決済みなので、clean な土台の上に stack できる）
8. **全フェーズ完了後の受け入れゲート**: 最終スタックブランチ（＝全実装が乗った状態）で `/qa <feature> auto` を起動する（ブラウザ動作確認。feature 全体の受け入れを 1 回で確認）
   - 全 pass → 次へ
   - fail → qa の指摘から**原因フェーズを特定**し、そのフェーズのブランチに戻って `/fix <feature> auto`（設計起因なら `/design auto`・`/impl <feature> [pN] auto`）→ 該当フェーズの `/test <feature>`→`/review`→`/commit` を通し、**上位フェーズへ変更を反映（stack を rebase 伝播）**する。その後、**変更が乗った全 PR について Step 7-6〜7-7（`/watch-ci`→CodeRabbit 対応）を回し直して**から `/qa` に再合流。qa↔fix が2周しても収束しない、または rebase 伝播を自走で安全に行えないと判断したら報告して停止
9. **全 PR の最終確認**: 全フェーズの PR が「CI green + CodeRabbit 未解決コメントなし」であることを確認する（各フェーズでは閉じているが、後続フェーズの push や qa 起因の rebase 伝播で状態が動いている可能性があるため、ここで一度まとめて見る）。崩れていれば該当 PR について Step 7-6〜7-7 を回し直す
10. **停止点**: draft PR（複数なら stacked PR 群）+ 全 PR が CI green + CodeRabbit コメント解決済みの状態で、PR の URL と結果を人に報告して止まる。**Ready for review への切替と merge は人が判断する**。「マージ後は `/cleanup <feature>` で後片付けできます」と一言添える

## prototype 分岐
`/design` 完了後、`design.md` の内容から以下を判定する：

- **大きい修正** か？（目安: 新規画面が複数ある／tasks が複数フェーズにまたがる規模／操作フローが新規）
- かつ **UI を含む** か？

両方 Yes のときだけ `/prototype` を起動する。それ以外（小さい修正・UI を伴わない修正）は `/tasks` に直行する。判定理由を一言ログに残す。

## 例外処理（人を呼ぶ＝停止する条件）
回復可能なものは自己修正ループで潰し、以下のときだけ停止して人に報告する：

- **test FAIL が3回連続** → 報告して停止
- `/fix` が「設計の問題」と判断 → `/design` に戻す。design↔impl のループが2周しても収束しない → 報告して停止
- **レビュー NG**:
  - 「設計の根本的な問題」が含まれる → `/design` に戻す
  - それ以外（コード品質・実装ミス）→ `/impl` に戻す
- **qa FAIL** → 原因フェーズを特定してそのフェーズで `/fix <feature>`（設計起因なら `/design`・`/impl`）→ そのフェーズの `/test <feature>`→`/review`→`/commit` を通し、stack を rebase 伝播 → 影響 PR の CI / CodeRabbit を通し直してから `/qa` に再合流。qa↔fix が2周しても収束しない、または rebase 伝播を自走で安全に行えない → 報告して停止
  - **rebase 伝播が必要になるのはここだけ**（フェーズループ内で PR を閉じきっているため、CI / CodeRabbit 起因の修正は常に先端ブランチで完結する）
- **CI 失敗** → ログを取得し自己修正して push し直す。2回直しても green にならない → 報告して停止（フェーズループ内なので、失敗しているのは原則そのフェーズの PR）
- **CodeRabbit コメント対応がそのフェーズで2巡しても収束しない** → 報告して停止（次フェーズを積まない）
- **CodeRabbit のレビューが一定時間来ない** → 報告して停止
- **PR に人間のレビューコメントが付いた** → 自動対応せず報告して停止
- 各スキルが判断できない（要件の曖昧さ等）→ 報告して指示を仰ぐ

## 実装中の変更
実装中に仕様・設計・タスクの変更が必要になった場合は、**変更が生じた工程から編集モードで再入し、OK の前進チェーンを辿り直す**（前進カスケード）。どの工程から再入するか（＝影響範囲の判断）はここで決める：

- 要件が変わる → `/spec <feature>`（編集）→ `/design`（編集）→ `/tasks`（編集）→ 実装へ
- 設計だけ変わる → `/design <feature>`（編集）→ `/tasks`（編集）→ 実装へ
- タスクだけ変わる → `/tasks <feature>`（編集）→ 実装へ

各スキルは編集モードの再入時に上流 doc との整合を自分で再チェックし、ズレがあれば差分だけを patch する。

## 完了条件
draft PR（複数フェーズなら stacked PR 群）が作られ、CI が green、CodeRabbit の未解決コメントが無い状態を、PR の URL とともに人に報告したら完了。
Ready for review への切替・merge は人が判断する。

## 完了カード
停止点に到達したら、Step 10 の報告を次の完了カードに畳んで**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。Ready for review への切替・merge は自走で行わず人の判断を待つ。

- 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（フェーズ数・CI / CodeRabbit の状態など。工程ごとの経過は各工程の成果物に寄せ、カードには列挙しない）。
- 🔗 行は**全フェーズの PR を 1 本 1 行**で本数ぶん出す（行数上限は主要な結果にだけ課すので、PR が n 本なら 🔗 も n 行）。
- 各工程の `⏳` は各スキルが自分で出すので、orchestrator が工程開始の実況を代わりに出さない。

✅ パイプライン完走（停止点）
<feature 名とフェーズ数・到達状態を 1 行>
- <主要な結果 最大 3 行>
🔗 <フェーズ 1 の PR の URL>
🔗 <フェーズ N の PR の URL>
▶ OK：Ready for review / merge を判断（人）
▶ 後片付け：/cleanup <feature>

「例外処理」の停止条件に当たって完走できずに終了するときは、同じ構成でヘッダを `⚠ パイプライン中断` に差し替え、一言サマリに停止理由（test FAIL 3 連続・rebase 伝播が安全に行えない・人間コメントありなど）、▶ 行に復帰の判断先を書く（作成済みの PR があれば 🔗 行は残す）。
