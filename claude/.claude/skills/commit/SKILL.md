---
name: commit
description: 変更内容を確認してコミットプランを提示し、承認後にコミットする。
argument-hint: "[auto]"
---

# コミット

## 役割
変更内容を確認し、`commit-planner` エージェントにコミット分割計画を作成させ、承認後に実行する。

## 自走モード（`auto` 引数）
`$ARGUMENTS` に `auto` が含まれる場合、Phase 4 のプラン承認を自動承認として扱い、プランを提示したらそのまま Phase 5 を実行する。引数なしの単体起動では従来どおり承認を待つ。

## 進め方
各 Phase は順番に実行する。末尾の完了ゲートを通過するまで次へ進まない。

---

## Phase 1: ブランチチェック

現在のブランチ名とデフォルトブランチ名を取得する：
```
CURRENT=$(git branch --show-current)
DEFAULT=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
```

判定：
- `CURRENT` が空（detached HEAD）→ 警告へ
- `CURRENT` が `DEFAULT` と一致 → 警告へ
- リモートでマージ済み（下記がマッチ）→ 警告へ
  ```
  git fetch origin
  git branch -r --merged "origin/$DEFAULT" | sed 's/^[ *]*//' | grep -xF "origin/$CURRENT"
  ```
- いずれも該当しなければ Phase 2 へ

**警告文:**
> 現在のブランチ `<CURRENT>` は <デフォルトブランチ／マージ済み／detached> の状態です。新しいブランチを切ってからコミットしますか？

- 「はい」→ デフォルトブランチを最新化してから新ブランチを作成し Phase 2 へ
  ```
  git checkout "$DEFAULT" && git pull
  git checkout -b <新ブランチ名>
  ```
  ブランチ名は変更内容から `<type>/<短い説明>`（例: `fix/login-redirect`）の形で提案する。
- 「このまま進める」→ Phase 2 へ

**完了ゲート:** ブランチ状態を判定し、必要なら新ブランチを切ったか。

---

## Phase 2: 変更ファイルを確認する

```
git status
git diff
```

生成物・秘密情報・無関係ファイルなど **コミットすべきでないものが混ざっていないか** を確認する。

**完了ゲート:** 変更内容を把握し、コミット対象を絞り込んだか。

---

## Phase 3: commit-planner エージェントでコミット計画を作成する

`@commit-planner` サブエージェントを起動してコミット分割計画を作成させる。
サブエージェントは diff 分析 → 初回計画 → 関心事分離レビュー → 30行ルール研磨 の 4 パスを内部で実行し、最終計画を返す。

**完了ゲート:** commit-planner が最終計画を返したか。

---

## Phase 4: プランを提示して承認を得る

commit-planner が返した計画をそのまま提示し、承認を得てから Phase 5 に移る。

**完了ゲート:** 人間の承認を得たか（`auto` モード時は自動承認）。

---

## Phase 5: ステージング＆コミットを実行する

**commit-planner が返した計画（コミット数・順序・内容・メッセージ）をそのまま実行すること。自己判断で集約・簡略化・変更してはならない。**

計画を変更できるのは **ユーザーが明示的に指示した場合のみ**。

プランの項目ごとに、**その項目の対象ファイルだけを `git add` してからコミットする**。これを順番に繰り返す。

```
git add <対象ファイル>
git commit -m "$(cat <<'EOF'
<commit-planner が生成したメッセージ>

Co-Authored-By: <ハーネス指定のモデル行>
EOF
)"
```

**注意:**
- メッセージは HEREDOC で渡す。変数展開を避けるため本文は `<<'EOF'`（literal mode）を使う
- 末尾に `Co-Authored-By` 行を必ず付与する。モデル行はハーネス（環境）が指定する形式に従い、**スキル内に固定のモデル名を書かない**（ズレ防止）
- hunk 分割が必要な場合は commit-planner の指示に従う

**完了ゲート:** プランの全項目を、対象ファイル単位でコミットしたか。

---

## Phase 6: push または PR 作成を提案する

コミット完了後に確認する：

> push しますか？／ PR を作成しますか？（/create-pr を使います）

push 時にリモートのデフォルトブランチへ直接 push しようとしていないか確認する。回答に応じて `git push` または `/create-pr` を実行し、どちらも不要なら終了する。
