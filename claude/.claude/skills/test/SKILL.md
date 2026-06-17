---
name: test
description: 実装完了後にテストを実行し結果を報告する。impl完了後に使う。
allowed-tools: Read, Write, Bash, Glob
---

# テストスキル

## 役割
実装後にテストを実行し、PASS/FAILを判定する。
テストを書くのは `/impl` の責任。ここは**実行と検証のみ**。

## 進め方

### Step 1: 環境ロック取得
ユーザーに調停役のエージェント名を確認する：

> テスト環境の調停役エージェント名を教えてください。（例: `Seculio`）

エージェント名が分かったら `send-message` スキルで env-lock を要求する：

```
send-message で <エージェント名> に以下を送信:
  type: request
  action: env-lock
  payload: {"worktree": "<現在のworktree名>"}
```

response を待ち、結果を判定する：
- `"status": "ready"` → Step 2 へ進む
- `"status": "busy"` → ユーザーに報告して待機するか確認する

### Step 2: テストコマンド検出
PJ ごとにテスト体系も実行方法も異なる（RSpec / go test / vitest / docker 経由など）ため、**プロジェクト CLAUDE.md の指定を最優先**で使う。

1. **プロジェクト CLAUDE.md のテスト節を読む**（`## テスト` / `### Testing` などの見出し）。テストコマンドが書かれていれば **そのまま採用する**。`docker compose exec web bundle exec rspec ...` のような実行ラッパや、複数コマンドの指定もそのまま従う（CLAUDE.md が PJ 固有のビルド手順の正）
2. CLAUDE.md に記載が無ければ、リポジトリ構成からフォールバック検出する：
   - `Gemfile` + `spec/`（または `.rspec`）→ `bundle exec rspec`
   - `Makefile` に `test` ターゲット → `make test`
   - `package.json` に `test` スクリプト → そのリポジトリのパッケージマネージャの test（`npm test` 等）
   - `go.mod` → `go test ./...`
   - `pyproject.toml` / `pytest.ini` → `pytest`
   - `Cargo.toml` → `cargo test`
   - `mix.exs` → `mix test`
   - モノレポ・多言語で複数該当する場合は、変更されたファイルに対応するものを選ぶ
   - 注: docker 等のラッパが要る PJ はフォールバックでは導けない。その場合は CLAUDE.md への記載が前提
3. それでも確定できない場合は **推測でテストを実行しない**。確認を求める（単体起動ではユーザーに質問、orchestrator 自走時は「判断できない」として報告・停止する）

### Step 3: テスト実行
検出したコマンドを実行する。

### Step 4: 環境ロック解放
テスト完了後（PASS/FAIL問わず）必ず env-unlock を送信する：

```
send-message で <エージェント名> に以下を送信:
  type: request
  action: env-unlock
  payload: {"worktree": "<現在のworktree名>"}
```

### Step 5: 結果判定・報告
結果をコンソールに出力し、PASS/FAILを明示する。

**PASS の場合:** `/review` を起動する。

**FAIL の場合:** 以下の情報を添えて `/fix` に渡す：
- 失敗したテスト名
- エラーメッセージ
- 関連するファイル（推測）

## 出力フォーマット
```
## テスト結果: PASS / FAIL

- 実行数: N
- 成功: N
- 失敗: N

### 失敗したテスト（FAILの場合）
- [テスト名]: [エラー内容]
```

## 完了条件
PASS → `/review` へ。FAIL → `/fix` へ。
