---
name: impl
description: タスクリストを受け取り実装を行う。.specs/<feature>/tasks.mdが出来上がったら使う。
allowed-tools: Read, Write, Edit, MultiEdit, Bash, Glob, Grep, Agent, WebSearch, WebFetch
argument-hint: "<feature> [task-numbers]"
---

# 実装スキル

## 役割
`.specs/<feature>/tasks.md` のタスクを実行し、コードを実装する。

## 入力
- `.specs/<feature>/requirements.md`
- `.specs/<feature>/design.md`
- `.specs/<feature>/tasks.md`

## 実行モード
- **自律モード**（`$ARGUMENTS[1]` なし）: 全ての未完了タスクをサブエージェントで並列実行
- **手動モード**（`$ARGUMENTS[1]` にタスク番号あり、例: `1.1` または `1,2`）: 指定タスクをメインコンテキストで実行

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]` が未指定なら「使い方: /impl <feature> [task-numbers]」を表示して終了
- feature 名を確定する
- `$ARGUMENTS[1]` があればタスク番号として扱い手動モードで実行、なければ自律モードで実行

### Step 2: コンテキスト収集
以下を並行して読み込む：
- `.specs/<feature>/requirements.md`, `.specs/<feature>/design.md`, `.specs/<feature>/tasks.md`
- ステアリング文書（あれば）
- 既存コードの関連パターン（Grep/Glob）

### Step 3: 実行前チェック
- `git status --porcelain` でベースラインを確認
- テスト・ビルドコマンドをリポジトリの設定ファイルから確認
  （`package.json`, `Makefile`, `go.mod`, `pyproject.toml` など）

### Step 4: タスク実行

#### 自律モード
1. `.specs/<feature>/tasks.md` から未完了タスク（サブタスク X.Y）を読み込む
2. `(P)` マーカーのあるタスクは並列サブエージェントで実行
3. 依存関係（`_Depends:_`）を確認し、前提タスクが完了していることを確認
4. 1タスク完了ごとに `.specs/<feature>/tasks.md` の `[ ]` を `[x]` に更新
5. 実装後にテスト・ビルドを実行して確認

#### 手動モード
1. 指定されたタスクを直接実行する
2. 実装後にテストを実行する
3. タスクを完了済みにマークする

### Step 5: タスク完了後の確認
各タスク完了時に：
- [ ] タスクの完了条件を満たしているか
- [ ] テスト・ビルドがパスしているか
- [ ] 関連する要件（`_Requirements:_`）に対応しているか

### Step 6: 全タスク完了後
全タスク完了後は `/review` を起動する。

## 例外処理
- 判断できない場面や設計の曖昧さがある場合 → ユーザーに確認
- テストが失敗し続ける場合 → 根本原因を調査して最小限の修正を試みる

## 完了条件
全タスクが `[x]` になり、テスト・ビルドがパスしたら完了。
