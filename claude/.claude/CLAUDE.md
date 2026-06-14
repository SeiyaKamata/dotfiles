# 仕様駆動開発ワークフロー

## スキル構成

| スキル | 役割 | 出力 |
|--------|------|------|
| `/spec` | 要件策定（EARS形式） | `spec/requirements.md` |
| `/design` | 技術設計 | `spec/design.md` |
| `/prototype` | ローカルでUIモックを動かし設計精度を高める（大きいUI修正時のみ） | `spec/design.md` への書き戻し |
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

### 通常フロー（`/orchestrator` で一括起動・自走）
```
/orchestrator → /spec → /design →(分岐)→ [/prototype] → /tasks → /impl → /test → /review → /commit → /create-pr(draft) → /watch-ci → 停止
```
`/orchestrator` 経由では各フェーズの承認待ちをせず、draft PR + CI green まで自走する。`/prototype` は大きい修正かつ UI を含むときだけ `/design` 後に挿入される（それ以外は `/tasks` に直行）。停止点は draft PR + CI green の状態で、merge と Ready for review への切替は人が判断する。

### 個別フロー（フェーズを個別に実行）
1. `/spec` - 要望を詳細化し要件書を作成
2. `/design` - 要件を元に技術設計
3. `/prototype` - 大きいUI修正のときローカルでモックを動かし design.md を磨く（任意）
4. `/tasks` - 設計を元にタスク分解
5. `/impl [task-numbers]` - 実装（番号指定で一部のみも可）
6. `/test` - テスト実行
7. `/review` - レビュー

## 承認フロー
- **`/orchestrator` 経由（自走）**: 各フェーズで承認を求めず draft PR + CI green まで走り切る。途中の失敗（test FAIL / review NG / CI 赤）は自己修正ループで潰し、人を呼ぶのは安全停止点（draft PR + CI green）と回復不能な詰まり（FAIL 3連続など）だけ。
- **個別フロー（スキル単体起動）**: 各フェーズはユーザーの承認後に次フェーズへ進む。
  - `/spec` 完了 → ユーザー承認 → `/design` 起動
  - `/design` 完了 → ユーザー承認 → `/tasks`（または `/prototype`）起動
  - `/tasks` 完了 → ユーザー承認 → `/impl` 起動

## 開発言語
英語で思考を行い日本語で回答する。
日本語で回答・ドキュメントを記述する。

## ファイル編集の制約
現在のプロジェクトディレクトリ（`$PWD`）外のファイルを編集・作成してはならない。シンボリックリンク経由であっても、パスがプロジェクト外であれば操作しない。変更が必要な場合はユーザーに提案し、ユーザー自身に実行してもらう。
