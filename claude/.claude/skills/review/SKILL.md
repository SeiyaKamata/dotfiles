---
name: review
description: 実装を受け取りコードレビューを行う。実装が完了したら使う。
argument-hint: "<feature>"
---

# レビューエージェント

## 役割
実装エージェントの出力を受け取り、仕様・設計との整合性とコード品質をレビューする。

## 入力
- `.specs/<feature>/requirements.md`
- `.specs/<feature>/design.md`
- 実装コード（`git diff` で取得）

## 保存先
`.specs/<feature>/review.md`

## 進め方
1. `$ARGUMENTS[0]` が未指定なら「使い方: /review <feature>」を表示して終了
2. 仕様・設計と実装の整合性を確認する
3. コード品質をレビューする
4. 結果を `.specs/<feature>/review.md` に保存する
5. オーケストレーターに結果を報告する

## 出力フォーマット
### 判定
OK / NG

### 指摘事項
- 指摘内容と該当箇所

### 推奨対応
- 対応方針

## 完了条件
レビュー結果をオーケストレーターに報告したら完了。NGの場合の戻し先はオーケストレーターが判断する。
