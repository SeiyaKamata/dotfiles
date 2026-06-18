---
name: cleanup
description: PRマージ後の後片付けをする。作業ブランチの削除・specsの削除・mainへの移動・会話のクリアを行う。
argument-hint: "<feature>"
allowed-tools: Bash(git *), Bash(gh *), Bash(rm *)
---

# マージ後の後片付け

## 役割
PRがマージされた後、作業ブランチと `.specs/<feature>` を削除してmainに戻す。

## 引数
- `$ARGUMENTS`: feature名（省略可。省略時は `.specs/` の一覧から選ばせる）。ブランチ名は現在のブランチから自動取得する

## 進め方

### Step 1: feature名と現在のブランチを確認する

**feature名の決定:**

`$ARGUMENTS` が指定されていればそれを使用する。

未指定なら `.specs/` 以下のディレクトリを列挙し、番号で選ばせる：

```
ls -1 .specs/
```

候補が1件もない場合は「`.specs/` にディレクトリが見つかりません。feature名を直接入力してください」と伝えて入力を待つ。

候補がある場合は番号付きで提示する：

```
.specs/ 以下のディレクトリが見つかりました：

1: foo-feature
2: bar-feature

番号で選んでください（その他: 手入力）:
```

人間の回答をfeature名として使用する。

**現在のブランチの取得:**

現在のブランチを取得する：

```
git branch --show-current
```

現在のブランチが `main` / `master` の場合、削除対象がないため人間に確認する。

### Step 2: PRのマージ状態を確認する

```
gh pr view <現在のブランチ名> --json state,mergedAt,headRefName --jq '{state, mergedAt, branch: .headRefName}'
```

- `state` が `MERGED` → Step 3へ
- `state` が `OPEN` → 「PRはまだマージされていません」と伝え、本当に後片付けするか確認する
- `state` が `CLOSED`（マージなしクローズ）→ 人間に確認する
- PRが見つからない → 人間に確認する

### Step 3: mainブランチに移動する

```
git checkout main
git pull origin main
```

### Step 4: ローカルブランチを削除する

```
git branch -d <元のブランチ名>
```

`-d` で削除できない（未マージ警告）場合、マージ済みであることを確認したうえで `-D` を使う。

### Step 5: .specs/<feature> を削除する

`.specs/<feature>` ディレクトリが存在するか確認し、存在すれば削除する：

```
rm -rf .specs/<feature>
```

存在しない場合はスキップする。

### Step 6: 完了を報告して /clear を提案する

削除したブランチ名・specs の削除結果を報告する。

> 後片付けが完了しました。
> 会話履歴をリセットするには `/clear` を実行してください。

## 完了条件
- mainブランチに移動済み
- 作業ブランチがローカルから削除済み（または削除不要と確認済み）
- `.specs/<feature>` が削除済み（または存在しなかった）
- `/clear` を提案したら完了

## エラー処理
- `git checkout main` で失敗する場合: `git fetch origin` してから再試行する
- ローカルブランチが存在しない: スキップして次へ
- `.specs/<feature>` が存在しない: スキップして次へ
