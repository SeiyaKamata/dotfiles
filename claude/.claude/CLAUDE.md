# 仕様駆動開発ワークフロー

## スキル構成

| スキル | 役割 | 出力 |
|--------|------|------|
| `/spec` | 要件策定（EARS形式） | `spec/requirements.md` |
| `/design` | 技術設計 | `spec/design.md` |
| `/tasks` | タスク生成 | `spec/tasks.md` |
| `/impl` | 実装 | コード |
| `/test` | テスト実行 | 結果レポート |
| `/review` | コードレビュー | レビューコメント |

## 仕様書の出力先
各プロジェクトのルートディレクトリにある `spec/` ディレクトリに出力する：
- `spec/requirements.md` - 要件定義（EARS形式）
- `spec/design.md` - 技術設計
- `spec/tasks.md` - 実装タスクリスト

## 開発フロー

### 通常フロー（`/orchestrator` で一括起動）
```
/orchestrator → /spec → /design → /tasks → /impl → /test → /review
```

### 個別フロー（フェーズを個別に実行）
1. `/spec` - 要望を詳細化し要件書を作成
2. `/design` - 要件を元に技術設計
3. `/tasks` - 設計を元にタスク分解
4. `/impl [task-numbers]` - 実装（番号指定で一部のみも可）
5. `/test` - テスト実行
6. `/review` - レビュー

## 承認フロー
各フェーズはユーザーの承認後に次フェーズへ進む：
- `/spec` 完了 → ユーザー承認 → `/design` 起動
- `/design` 完了 → ユーザー承認 → `/tasks` 起動
- `/tasks` 完了 → ユーザー承認 → `/impl` 起動

## 開発言語
日本語で回答・ドキュメントを記述する。
