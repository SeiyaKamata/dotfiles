---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
argument-hint: "<feature>"
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキル（工程）を順番に起動する。
**唯一の承認ゲートは requirements（要件）の人間承認**で、それ以降は draft PR + CI green + CodeRabbit のコメント解決まで自走する。途中の失敗は自己修正ループで潰し、人を呼ぶのは承認ゲート・安全停止点・回復不能な詰まりだけにする。

## 用語（前提）
用語は `claude/CLAUDE.md`「用語集」に従う。特に：
- **工程 (stage)** = パイプラインの各段階（各スキル）。
- **フェーズ = 大タスク = ブランチ = 1 PR**。tasks.md が大タスクを 1 フェーズに 1:1 で割る。複数フェーズ = **stacked PR**（`pN` を `p(N-1)` にスタック）。
- **test / review / commit はフェーズ単位**（PR 単位で閉じる）だが、**qa は feature 全体の受け入れゲート**なので**全フェーズ実装後に 1 回だけ**回す。

## パイプライン
```
/spec →【要件承認ゲート(人)】→ /design →(分岐)→ [/prototype] → /tasks
  → フェーズループ（大タスクごと・依存順・stacked）:
        /impl pN → /test → /review → /commit
          ↓FAIL          ↓NG
         /fix→/test     /design or /impl に戻す
  → 全フェーズ完了後（最終スタックブランチ = 全実装）:
        /qa → /create-pr(draft, 複数なら stacked PR を一斉作成)
         ↓FAIL(qa)
        原因フェーズを特定し /fix（設計起因なら /design・/impl）→ 再合流
  → /watch-ci → /respond-pr-comments(CodeRabbit のみ) → 停止(人に報告)
```

承認ゲート: **requirements.md 完成後に人間の承認を待つ**（spec だけ人間判断を挟む）。承認後は自走。
停止点: **draft PR（複数なら stacked PR 群）+ CI green + CodeRabbit の未解決コメントが無い状態**で人に報告して止まる。merge と Ready for review への切替は人が判断する（自走では行わない）。

## 自走モードの起動（重要）
人間承認を待つステップを持つスキルは **`auto` 引数**で起動して承認をスキップする。各スキルの `auto` 時の挙動は、それぞれの SKILL.md の「自走モード（`auto` 引数）」節に定義されている：

- **`auto` つきで起動するスキル**: `/design auto` / `/prototype auto` / `/tasks auto` / `/impl … auto` / `/test auto` / `/fix auto` / `/review auto` / `/qa auto` / `/commit auto` / `/create-pr auto` / `/watch-ci auto` / `/respond-pr-comments auto`。人間承認を待たず自己レビューゲートで進む（各スキルは `auto` 時に次ステップの定型ブロックを出さず 1 行の簡易ログのみ残す）
- **spec だけは `auto` を渡さない**: requirements は唯一の人間承認ゲート（下記 Step 3）。spec 通常挙動（ドラフト → 承認 → 保存）で人間の承認を取る
- **prototype**: 目視承認の代わりに Playwright での操作確認＋スクショ取得。**動くコードを `<feature>-proto` ブランチに残す**（後段の impl が「参照して昇格」で流用する）。design.md へ書き戻したら次へ
- **commit**: フェーズループの中で各フェーズのブランチにコミットする。**stacked 運用では PR をまだ作らない**（次フェーズの作業へ移る）
- **create-pr**: `auto` 引数で起動する。単一フェーズは通常の 1 PR（ベース = デフォルトブランチ）。**複数フェーズは stacked PR を一斉作成**（p1 の base = デフォルトブランチ、pN の base = `<feature>-p(N-1)`）。未コミットがあれば `/commit auto` を自動で呼ぶ。Notion URL が最初の指示にあれば引数で渡す
- **watch-ci**: `auto` 引数で起動する。複数 PR なら全 PR を対象にする。CI green でも **Ready for review に自動で切り替えない**。draft のまま次へ

## 進め方
1. `$ARGUMENTS[0]` を feature 名として使う。未指定なら「使い方: /orchestrator <feature>」を表示して終了
2. `/spec <feature>` を起動し、`.specs/<feature>/requirements.md` を生成する
3. **要件承認ゲート**: requirements.md を人間に提示し、**承認を待つ**。承認後に次へ（修正要望があれば spec に戻す）
4. `/design <feature> auto` を起動し、`.specs/<feature>/design.md` を生成 → 承認を待たず次へ
5. **prototype 分岐判定**（下記「prototype 分岐」参照）
   - 必要 → `/prototype <feature> auto` を起動 → design.md 更新後に次へ
   - 不要 → そのまま次へ
6. `/tasks <feature> auto` を起動し、`.specs/<feature>/tasks.md` を生成 → 承認を待たず次へ
7. tasks.md を読んで**フェーズ構成（大タスク数）**を確認する。大タスク = フェーズ = 1 PR = 1 ブランチ。複数フェーズは依存順に並べる（stacked PR になる）
8. **フェーズループ**: 各フェーズ pN を依存順に、以下のフルサイクルで回す（単一フェーズなら 1 周だけ）。**test / review / commit はこのループ内＝PR 単位**：
   1. `/impl <feature> [pN] auto` を起動（単一は `<feature>`、複数は `pN`。`pN` のブランチは `p(N-1)` にスタック）
   2. `/test auto` を起動し PASS / FAIL を確認。FAIL → `/fix auto` → `/test auto` を再実行（test FAIL 3連続で停止）
   3. `/review <feature> auto` を起動。NG は下記「例外処理」（設計起因は `/design auto`→`/impl`、それ以外は `/impl` に戻す）
   4. `/commit auto` を起動し、**このフェーズのブランチにコミットする**（stacked 運用なので PR はまだ作らない）
   5. 次フェーズへ（前フェーズが commit 済みなので clean に stack できる）
9. **全フェーズ完了後の受け入れゲート**: 最終スタックブランチ（＝全実装が乗った状態）で `/qa <feature> auto` を起動する（ブラウザ動作確認。feature 全体の受け入れを 1 回で確認）
   - 全 pass → 次へ
   - fail → qa の指摘から**原因フェーズを特定**し、そのフェーズのブランチに戻って `/fix auto`（設計起因なら `/design auto`・`/impl <feature> [pN] auto`）→ 該当フェーズの `/test`→`/review`→`/commit` を通し、**上位フェーズへ変更を反映（stack を rebase 伝播）**してから `/qa` に再合流。qa↔fix が2周しても収束しない、または rebase 伝播を自走で安全に行えないと判断したら報告して停止
10. `/create-pr auto` を起動する。**単一フェーズは 1 PR、複数フェーズは stacked PR を一斉作成**（各 PR の base は前フェーズのブランチ、p1 は デフォルトブランチ）。draft でも CodeRabbit が自動でレビューを開始する
11. `/watch-ci auto` を起動する（全 PR の CI green まで監視。赤なら下記ループ）
12. **最新コミットへの CodeRabbit レビューを待つ**: `/respond-pr-comments` の Step 2 のコマンドで PR のレビュー／コメントを取得し、**現在の HEAD コミットより後**の `coderabbitai[bot]` のレビューが届くまでポーリングする（1巡目は最初のレビュー、2巡目以降は push 後の再レビューを待つ。一定時間来なければ報告して停止）
13. **CodeRabbit コメント対応ループ（最大2巡）**:
    - CodeRabbit は対応済みと判断したスレッドを**自分で resolve する**ため、`isResolved == false` の有無が終了シグナルになる
    - 未解決の CodeRabbit コメントが**あり** → `/respond-pr-comments auto` を起動（CodeRabbit のみ対応）→ 対応を `/commit auto` → push → **11 に戻る**（push で CI も CodeRabbit 再レビューも自動で再実行される）
    - 未解決の CodeRabbit コメントが**なし**（CodeRabbit が全スレッドを resolve した）→ 停止点へ
    - 2巡しても未解決コメントが残る → 報告して停止
14. **停止点**: draft PR（複数なら stacked PR 群）+ CI green + CodeRabbit コメント解決済みの状態で、PR の URL と結果を人に報告して止まる。「マージ後は `/cleanup <feature>` で後片付けできます」と一言添える

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
- **qa FAIL** → 原因フェーズを特定してそのフェーズで `/fix`（設計起因なら `/design`・`/impl`）→ そのフェーズの `/test`→`/review`→`/commit` を通し、stack を rebase 伝播してから `/qa` に再合流。qa↔fix が2周しても収束しない、または rebase 伝播を自走で安全に行えない → 報告して停止
- **CI 失敗** → ログを取得し自己修正して push し直す。2回直しても green にならない → 報告して停止
- **CodeRabbit コメント対応が2巡しても収束しない** → 報告して停止
- **CodeRabbit のレビューが一定時間来ない** → 報告して停止
- **PR に人間のレビューコメントが付いた** → 自動対応せず報告して停止
- 各スキルが判断できない（要件の曖昧さ等）→ 報告して指示を仰ぐ

## 実装中の変更
実装中に仕様・設計・タスクの変更が必要になった場合は `/change <feature>` を使う。
`/change` が影響範囲を判断し、適切な工程に戻してドキュメントを更新する。

## 完了条件
draft PR（複数フェーズなら stacked PR 群）が作られ、CI が green、CodeRabbit の未解決コメントが無い状態を、PR の URL とともに人に報告したら完了。
Ready for review への切替・merge は人が判断する。
