---
name: orchestrator
description: 開発パイプライン全体を管理する。新規開発や機能追加の指示を受けたら使う。
disable-model-invocation: true
---

# オーケストレーター

## 役割
仕様駆動開発のパイプライン全体を管理し、各スキルを順番に起動する。

## パイプライン
```
/spec → /design → /tasks → /impl → /test → /review
                                      ↓FAIL
                                     /fix → /test
```

1. `/spec` - 要件策定（ユーザーと対話、`specs/<feature>/requirements.md` を生成）
2. `/design` - 技術設計（ユーザーと対話、`specs/<feature>/design.md` を生成）
3. `/tasks` - タスク生成（ユーザーと対話、`specs/<feature>/tasks.md` を生成）
4. `/impl` - 実装（全自動 or タスク指定）
5. `/test` - テスト実行（全自動）
6. `/fix` - テスト失敗時の最小限修正（FAIL時のみ）
7. `/review` - コードレビュー（全自動）

## 進め方
1. ユーザーから開発指示を受け取る
2. `/spec` を起動し、`specs/<feature>/requirements.md` が承認されるまで待つ
3. `/design` を起動し、`specs/<feature>/design.md` が承認されるまで待つ
4. `/tasks` を起動し、`specs/<feature>/tasks.md` が承認されるまで待つ
5. `/impl` を起動する
6. `/test` を起動し、判定（PASS / FAIL）を確認する
7. FAIL の場合 → `/fix` を起動し、完了後に `/test` を再実行する
8. PASS になったら `/review` を起動する
9. レビュー結果を受け取り判定する

## 例外処理
- テスト FAIL が3回続く → ユーザーに報告して止まる
- `/fix` が「設計の問題」と判断 → `/design` に戻す
- レビュー NG：
  - 「設計の根本的な問題」が含まれる → `/design` に戻す
  - それ以外（コード品質・実装ミス）→ `/impl` に戻す
- 各スキルが判断できない場合 → ユーザーに報告して指示を仰ぐ

## 実装中の変更
実装中に仕様・設計・タスクの変更が必要になった場合は `/change` を使う。
`/change` が影響範囲を判断し、適切なフェーズに戻してドキュメントを更新する。

## 完了条件
レビューOKが出たら完了をユーザーに報告する。
