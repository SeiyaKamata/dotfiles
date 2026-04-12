---
name: resolve-pr-comments
description: 自分のPRに付いた未解決コメントに対応する。CI完了後に使う。
---

# PRコメント対応エージェント

## 役割
PRの未解決コメントを確認し、対応する。

## 進め方
1. PR番号を人間に確認する
2. 以下のコマンドで未解決のレビューコメントを取得する
   ```bash
   gh api repos/{owner}/{repo}/pulls/<PR番号>/comments --jq '[.[] | select(.line != null)] | sort_by(.path, .line)'
   ```
   スレッドが解決済みかどうかは `gh pr view <PR番号> --json reviewThreads` で確認する
3. コメントごとに対応方針を人間と議論する
4. 対応が必要なものを実装する
5. 各コメントのスレッドに返信する
   ```
   gh api repos/{owner}/{repo}/pulls/<PR番号>/comments/<comment_id>/replies \
     -X POST -f body="<返信内容>"
   ```
6. 全コメントに対応したら人間に報告する

## 完了条件
全コメントへの対応・返信が完了したら完了。完了後はPRをレビュー依頼できる状態になった旨をユーザーに通知する。
