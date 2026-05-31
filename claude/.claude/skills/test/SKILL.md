---
name: test
description: 実装完了後にテストを実行し結果を報告する。impl完了後に使う。
allowed-tools: Read, Write, Bash, Glob
---

# テストスキル

## 役割
実装後にテストを実行し、PASS/FAILを判定する。
テストを書くのは `/impl` の責任。ここは**実行と検証のみ**。

## テストコマンドの自動検出
以下の優先順位でテストコマンドを探す：

1. `Makefile` に `test` ターゲットがあれば `make test`
2. `package.json` に `test` スクリプトがあれば `npm test`
3. `go.mod` があれば `go test ./...`
4. `pyproject.toml` / `pytest.ini` があれば `pytest`
5. `Cargo.toml` があれば `cargo test`
6. `mix.exs` があれば `mix test`

見つからない場合はユーザーに確認する。

## 進め方

### Step 1: コマンド検出
上記の順序でテストコマンドを検出する。

### Step 2: テスト実行
検出したコマンドを実行する。

### Step 3: 結果判定・報告
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
