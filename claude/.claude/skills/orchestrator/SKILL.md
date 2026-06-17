---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
argument-hint: "<feature>"
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキルを順番に起動する。
**唯一の承認ゲートは requirements（要件）の人間承認**で、それ以降は draft PR + CI green + CodeRabbit のコメント解決まで自走する。途中の失敗は自己修正ループで潰し、人を呼ぶのは承認ゲート・安全停止点・回復不能な詰まりだけにする。

## パイプライン
```
/spec →【要件承認ゲート】→ /design →(分岐)→ [/prototype] → /tasks → /impl → /test → /review → /commit → /create-pr(draft)
  → /watch-ci → /respond-pr-comments(CodeRabbit のみ) → 停止
                ↓FAIL              ↓NG                  ↺ 最大2巡
               /fix → /test    /design or /impl に戻す
```

承認ゲート: **requirements.md 完成後に人間の承認を待つ**（spec だけ人間判断を挟む）。承認後は自走。
停止点: **draft PR + CI green + CodeRabbit の未解決コメントが無い状態**で人に報告して止まる。merge と Ready for review への切替は人が判断する（自走では行わない）。

## 自走モードの起動（重要）
人間承認を待つステップを持つスキルは **`auto` 引数**で起動して承認をスキップする。各スキルの `auto` 時の挙動は、それぞれの SKILL.md の「自走モード（`auto` 引数）」節に定義されている：

- **`auto` つきで起動するスキル**: `/design auto` / `/tasks auto` / `/commit auto` / `/create-pr auto` / `/watch-ci auto` / `/respond-pr-comments auto`。人間承認を待たず自己レビューゲートで進む
- **spec だけは `auto` を渡さない**: requirements は唯一の人間承認ゲート（下記 Step 3）。spec 通常挙動（ドラフト → 承認 → 保存）で人間の承認を取る
- **prototype**: 目視承認の代わりに Playwright での操作確認＋スクショ取得。design.md へ書き戻したら次へ
- **create-pr**: `auto` 引数で起動する。ベースブランチはデフォルトを自動採用。未コミットがあれば `/commit auto` を自動で呼ぶ。Notion URL が最初の指示にあれば引数で渡す
- **watch-ci**: `auto` 引数で起動する。CI green でも **Ready for review に自動で切り替えない**。draft のまま次へ

## 進め方
1. `$ARGUMENTS[0]` を feature 名として使う。未指定なら「使い方: /orchestrator <feature>」を表示して終了
2. `/spec <feature>` を起動し、`.specs/<feature>/requirements.md` を生成する
3. **要件承認ゲート**: requirements.md を人間に提示し、**承認を待つ**。承認後に次へ（修正要望があれば spec に戻す）
4. `/design <feature> auto` を起動し、`.specs/<feature>/design.md` を生成 → 承認を待たず次へ
5. **prototype 分岐判定**（下記「prototype 分岐」参照）
   - 必要 → `/prototype <feature>` を起動 → design.md 更新後に次へ
   - 不要 → そのまま次へ
6. `/tasks <feature> auto` を起動し、`.specs/<feature>/tasks.md` を生成 → 承認を待たず次へ
7. tasks.md を読んでフェーズ構成を確認する
   - シングルフェーズ → `/impl <feature>` を起動する
   - マルチフェーズ → `/impl <feature> p1`, `/impl <feature> p2`, ... を順番に起動する（各フェーズ完了後に次フェーズへ）
8. `/test` を起動し、判定（PASS / FAIL）を確認する
9. FAIL → `/fix` を起動し、完了後に `/test` を再実行する
10. PASS → `/review <feature>` を起動する
11. レビュー結果を判定する（NG なら下記「例外処理」のループへ。OK なら次へ）
12. `/commit auto` を起動する（コミットプランを自動承認して実行）
13. `/create-pr auto` を起動する（デフォルトブランチをベースに draft PR を作成）。draft でも CodeRabbit が自動でレビューを開始する
14. `/watch-ci auto` を起動する（CI green まで監視。赤なら下記ループ）
15. **最新コミットへの CodeRabbit レビューを待つ**: `/respond-pr-comments` の Step 2 のコマンドで PR のレビュー／コメントを取得し、**現在の HEAD コミットより後**の `coderabbitai[bot]` のレビューが届くまでポーリングする（1巡目は最初のレビュー、2巡目以降は push 後の再レビューを待つ。一定時間来なければ報告して停止）
16. **CodeRabbit コメント対応ループ（最大2巡）**:
    - CodeRabbit は対応済みと判断したスレッドを**自分で resolve する**ため、`isResolved == false` の有無が終了シグナルになる
    - 未解決の CodeRabbit コメントが**あり** → `/respond-pr-comments auto` を起動（CodeRabbit のみ対応）→ 対応を `/commit auto` → push → **14 に戻る**（push で CI も CodeRabbit 再レビューも自動で再実行される）
    - 未解決の CodeRabbit コメントが**なし**（CodeRabbit が全スレッドを resolve した）→ 停止点へ
    - 2巡しても未解決コメントが残る → 報告して停止
17. **停止点**: draft PR + CI green + CodeRabbit コメント解決済みの状態で、PR の URL と結果を人に報告して止まる

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
- **CI 失敗** → ログを取得し自己修正して push し直す。2回直しても green にならない → 報告して停止
- **CodeRabbit コメント対応が2巡しても収束しない** → 報告して停止
- **CodeRabbit のレビューが一定時間来ない** → 報告して停止
- **PR に人間のレビューコメントが付いた** → 自動対応せず報告して停止
- 各スキルが判断できない（要件の曖昧さ等）→ 報告して指示を仰ぐ

## 実装中の変更
実装中に仕様・設計・タスクの変更が必要になった場合は `/change <feature>` を使う。
`/change` が影響範囲を判断し、適切なフェーズに戻してドキュメントを更新する。

## 完了条件
draft PR が作られ、CI が green、CodeRabbit の未解決コメントが無い状態を、PR の URL とともに人に報告したら完了。
Ready for review への切替・merge は人が判断する。
