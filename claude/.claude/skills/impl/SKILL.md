---
name: impl
description: タスクリストを受け取り実装を行う。.specs/<feature>/tasks.mdが出来上がったら使う。
allowed-tools: Read, Write, Edit, MultiEdit, Bash, Glob, Grep, Agent, WebSearch, WebFetch
argument-hint: "<feature> [pN|task-numbers]"
---

# 実装スキル

## 役割
`.specs/<feature>/tasks.md` のタスクを実行し、コードを実装する。

## 入力
- `.specs/<feature>/requirements.md`
- `.specs/<feature>/design.md`
- `.specs/<feature>/tasks.md`

## 引数
- `$ARGUMENTS[0]`: feature 名（必須）
- `$ARGUMENTS[1]`: フェーズ指定または手動モード
  - 省略: シングルフェーズ（全タスクを自律実行）
  - `p1`, `p2`, ... : マルチフェーズの指定フェーズを実行
  - タスク番号（例: `1.1`, `1,2`）: 手動モードで指定タスクのみ実行

## 実行モード
- **自律モード**（フェーズ指定なし）: 全ての未完了タスクを並列実行
- **フェーズモード**（`p1`, `p2`, ...）: 指定フェーズのタスクのみ実行
- **手動モード**（タスク番号指定）: 指定タスクをメインコンテキストで実行

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]` が未指定なら「使い方: /impl <feature> [pN|task-numbers]」を表示して終了
- feature 名、フェーズ、手動タスク番号を確定する

### Step 2: ブランチ準備
tasks.md のブランチ名ルールに従い、ブランチを作成して切り替える：

**シングルフェーズ（フェーズ指定なし）:**
- ブランチ名: `<feature>`
- デフォルトブランチから作成する

**フェーズ p1:**
- ブランチ名: `<feature>-p1`
- デフォルトブランチから作成する

**フェーズ pN（N > 1）:**
- ブランチ名: `<feature>-pN`
- 現在のブランチが `<feature>-p(N-1)` であることを確認する
- 一致しない場合はエラーを表示して終了する：
  > `<feature>-pN` を作成するには `<feature>-p(N-1)` ブランチにいる必要があります。
  > 現在のブランチ: `<現在のブランチ名>`

確認後、以下の手順でブランチを作成する：

**シングルフェーズ・フェーズ p1（デフォルトブランチから作成）:**
```
DEFAULT=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
git checkout "$DEFAULT"
git pull
git checkout -b <ブランチ名>
```

**フェーズ pN（N > 1）（前フェーズのブランチから作成）:**
```
git checkout -b <ブランチ名>
```

### Step 3: コンテキスト収集
以下を並行して読み込む：
- `.specs/<feature>/requirements.md`, `.specs/<feature>/design.md`, `.specs/<feature>/tasks.md`
- ステアリング文書（あれば）
- 既存コードの関連パターン（Grep/Glob）

### Step 4: 実行前チェック
- `git status --porcelain` でベースラインを確認
- テスト・ビルドコマンドをリポジトリの設定ファイルから確認
  （`package.json`, `Makefile`, `go.mod`, `pyproject.toml` など）

### Step 5: タスク実行

#### 自律モード / フェーズモード
1. tasks.md から対象タスクを読み込む（フェーズモードは指定フェーズのタスクのみ）
2. `(P)` マーカーのあるタスクは並列サブエージェントで実行
3. 依存関係（`_Depends:_`）を確認し、前提タスクが完了していることを確認
4. 1タスク完了ごとに `.specs/<feature>/tasks.md` の `[ ]` を `[x]` に更新
5. 実装後にテスト・ビルドを実行して確認

#### 手動モード
1. 指定されたタスクを直接実行する
2. 実装後にテストを実行する
3. タスクを完了済みにマークする

### Step 6: タスク完了後の確認
各タスク完了時に：
- [ ] タスクの完了条件を満たしているか
- [ ] テスト・ビルドがパスしているか
- [ ] 関連する要件（`_Requirements:_`）に対応しているか

### Step 7: 全タスク完了後
全タスク完了後は `/review <feature>` を起動する。

## 例外処理
- 判断できない場面や設計の曖昧さがある場合 → ユーザーに確認
- テストが失敗し続ける場合 → 根本原因を調査して最小限の修正を試みる

## 完了条件
全タスクが `[x]` になり、テスト・ビルドがパスしたら完了。
