---
name: recover
description: セッションが予期せず閉じた後、どこから再開すればいいかを調べて提案する。
argument-hint: "[feature]"
allowed-tools: Bash(git *), Bash(gh *), Bash(ls *), Bash(find *), Read
---

# セッション再開スキル

## 役割
中断した開発セッションの状態を調べ、どのスキルから再開すべきかをコマンド付きで提案する。

## 引数
- `$ARGUMENTS`: feature名（省略可。省略時は `.specs/` の一覧から選ばせる）

## 進め方

### Step 1: feature名を決定する

`$ARGUMENTS` が指定されていればそれを使用する。

未指定なら `.specs/` 以下のディレクトリを列挙する：

```
ls -1 .specs/ 2>/dev/null
```

- 候補が1件もない場合: 「`.specs/` にディレクトリが見つかりません。orchestrator を使った開発中ではないかもしれません」と伝えて終了する
- 候補がある場合: 番号付きで提示し、選ばせる：

```
.specs/ 以下のディレクトリが見つかりました：

1: foo-feature
2: bar-feature

番号で選んでください（その他: 手入力）:
```

### Step 2: .specs/<feature> の中身を確認する

以下のファイルの有無と内容を確認する：

```
ls -1 .specs/<feature>/
```

確認するファイル：
- `requirements.md` — spec 工程の成果物
- `design.md` — design 工程の成果物
- `tasks.md` — tasks 工程の成果物

存在するファイルの内容を Read で確認し、どこまで進んでいるか把握する。
特に `tasks.md` が存在する場合は、各タスクの完了状態（チェックボックス）を確認する。

### Step 3: git・PR の状態を確認する

```
git branch --show-current
git status --short
git log --oneline -5
```

PRが存在するか確認する：

```
gh pr view --json number,state,isDraft,title,headRefName 2>/dev/null
```

PRが存在する場合はCIの状態も確認する：

```
gh pr checks --json name,state,conclusion 2>/dev/null
```

### Step 4: 工程を推定して再開コマンドを提案する

収集した情報をもとに、以下の判定ロジックで現在の工程を推定する：

| 状態 | 推定工程 | 提案コマンド |
|---|---|---|
| requirements.md がない | spec 未完了 | `/spec <feature>` |
| requirements.md のみある | design 未完了 | `/design <feature>` |
| design.md まであり tasks.md がない | tasks 未完了 | `/tasks <feature>` |
| tasks.md はあるが未完了タスクが多い | impl 未完了 | `/impl <feature>` |
| tasks.md が完了済みだが未コミット変更あり・test 未実施 | test 未実施 | `/test` |
| test PASS 済みだが review 未実施 | review 中 | `/review <feature>` |
| review OK だが qa.md に未チェックのシナリオあり | qa 中 | `/qa <feature>` |
| コミット済みだが PR がない | commit 済み・PR 未作成 | `/create-pr` |
| PR が draft で CI pending/unknown | CI 監視中 | `/watch-ci` |
| PR が draft で CI 成功・未解決コメントあり | コメント対応中 | `/respond-pr-comments` |
| PR が draft で CI 成功・未解決コメントなし | 停止点（マージ待ち） | `/cleanup <feature>` （マージ後） |
| PR が MERGED | マージ済み | `/cleanup <feature>` |

上記の判定を提示するときは、まず現在の状態を要約する：

- .specs/<feature>/ の状態: （ファイル一覧と完了具合）
- ブランチ: （ブランチ名）
- 未コミット変更: （あり/なし）
- PR: （なし / draft / open / merged）

続けて、末尾の「次ステップ提示」の定型ブロックで再開コマンドを提示する。推定コマンドは自動起動せず、ユーザーの実行を待つ。

## 完了条件
- 再開コマンドを提案したら完了
- 人間がコマンドを実行するかどうかはこのスキルの範囲外（実行しない）

## 次ステップ提示
現在の状態の要約に続けて、次の定型ブロックを**コードフェンスで囲まず**プレーンテキストで出力する。推定工程が一意に確定するなら該当コマンドを 1 つ提示する。

```
✅ 再開ポイント特定
OK：<推定した再開コマンド（例: /impl <feature>）>
```

複数の工程にまたがって曖昧な場合は、`OK：` 行を候補列挙に差し替え、2〜3 件をそれぞれの条件付きで提示して人間に選ばせる。

```
✅ 再開ポイント特定
OK（条件A）：<コマンドA>
OK（条件B）：<コマンドB>
```
