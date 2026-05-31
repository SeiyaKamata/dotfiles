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
以下の優先順位でテストコマンドを探す：

1. `Makefile` に `test` ターゲットがあれば `make test`
2. `package.json` に `test` スクリプトがあれば `npm test`
3. `go.mod` があれば `go test ./...`
4. `pyproject.toml` / `pytest.ini` があれば `pytest`
5. `Cargo.toml` があれば `cargo test`
6. `mix.exs` があれば `mix test`

見つからない場合はユーザーに確認する。

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
