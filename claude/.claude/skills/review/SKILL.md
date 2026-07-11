---
name: review
description: 実装を受け取りコードレビューを行う。test PASS 後に使う。
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
3. `/coderabbit:review uncommitted` を起動してコード品質をレビューさせる
4. CodeRabbit の指摘と仕様整合性の確認結果を合わせて OK/NG を判定する
5. 結果を `.specs/<feature>/review.md` に保存する
6. オーケストレーターに結果を報告する

## OK/NG の判定基準
- 仕様・設計との不整合がある → NG
- CodeRabbit が重大な問題（バグ・セキュリティ・クラッシュ）を指摘した → NG
- CodeRabbit の指摘がスタイル・軽微な改善のみ → OK（指摘は review.md に記録する）

## 出力フォーマット
### 判定
OK / NG

### 仕様整合性
- 指摘内容と該当箇所

### CodeRabbit の指摘
- 指摘内容と該当箇所（重大度付き）

### 推奨対応
- 対応方針

## 完了条件
レビュー結果をオーケストレーターに報告したら完了。OK なら `/qa` を起動する。NGの場合の戻し先はオーケストレーターが判断する。
