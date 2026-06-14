---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキルを順番に起動する。
**各フェーズの承認待ちはせず、draft PR + CI green まで自走する。** 途中の失敗は自己修正ループで潰し、人を呼ぶのは安全停止点と回復不能な詰まりだけにする。

## パイプライン
```
/spec → /design →(分岐)→ [/prototype] → /tasks → /impl → /test → /review → /commit → /create-pr(draft) → /watch-ci → 停止
                                                          ↓FAIL              ↓NG
                                                         /fix → /test    /design or /impl に戻す
```

停止点: **draft PR が作られ CI が green になった状態**で人に報告して止まる。merge と Ready for review への切替は人が判断する（自走では行わない）。

## 自走モードの承認読み替え（重要）
各スキル単体には「ユーザー承認を待つ」ステップがあるが、orchestrator 経由では以下に読み替える：

- **spec / design / tasks**: 「ユーザー承認を待つ」→「各スキルの自己レビューゲート（書き込み前チェックリスト）を通過したら次へ進む」。承認は求めない
- **prototype**: 目視承認の代わりに Playwright での操作確認＋スクショ取得。design.md へ書き戻したら次へ
- **commit**: コミットプランを自動承認して実行する。プラン内容はログとして残す
- **create-pr**: ベースブランチはリポジトリのデフォルトブランチを自動採用する。未コミット確認は通過扱い。Notion URL が最初の指示にあれば引数で渡す
- **watch-ci**: CI green でも **Ready for review に自動で切り替えない**。draft のまま停止して人に渡す

## 進め方
1. ユーザーから開発指示を受け取る
2. `/spec` を起動し、`.specs/<feature>/requirements.md` を生成 → 承認を待たず次へ
3. `/design` を起動し、`.specs/<feature>/design.md` を生成 → 承認を待たず次へ
4. **prototype 分岐判定**（下記「prototype 分岐」参照）
   - 必要 → `/prototype` を起動 → design.md 更新後に次へ
   - 不要 → そのまま次へ
5. `/tasks` を起動し、`.specs/<feature>/tasks.md` を生成 → 承認を待たず次へ
6. `/impl` を起動する
7. `/test` を起動し、判定（PASS / FAIL）を確認する
8. FAIL → `/fix` を起動し、完了後に `/test` を再実行する
9. PASS → `/review` を起動する
10. レビュー結果を判定する（NG なら下記「例外処理」のループへ。OK なら次へ）
11. `/commit` を起動する（コミットプランを自動承認して実行）
12. `/create-pr` を起動する（デフォルトブランチをベースに draft PR を作成）
13. `/watch-ci` を起動する（CI green まで監視。赤なら下記ループ）
14. **停止点**: draft PR + CI green の状態で URL と結果を人に報告して止まる

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
- 各スキルが判断できない（要件の曖昧さ等）→ 報告して指示を仰ぐ

## 実装中の変更
実装中に仕様・設計・タスクの変更が必要になった場合は `/change` を使う。
`/change` が影響範囲を判断し、適切なフェーズに戻してドキュメントを更新する。

## 完了条件
draft PR が作られ CI が green になった状態を、PR の URL とともに人に報告したら完了。
Ready for review への切替・merge は人が判断する。
