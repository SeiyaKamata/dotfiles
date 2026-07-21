---
name: review
description: 実装を受け取りコードレビューを行う。test PASS 後に使う。
argument-hint: "<feature> [auto]"
---

# レビューエージェント

## 役割
実装されたコード（対象フェーズの git 差分。下記「入力」で導出）を、仕様・設計との整合性とコード品質の観点でレビューする。会話ではなく git と `.specs` から入力を得る。

## 自走モード（`auto` 引数）
`$ARGUMENTS[1]` が `auto` の場合は自律モード（ブロック抑制）とする。末尾の次ステップ提示で定型ブロックを出さず、確定した遷移先を 1 行の簡易ログのみ残す。引数なしの単体起動では定型ブロックを表示する。

## 入力
- `.specs/<feature>/requirements.md`
- `.specs/<feature>/design.md`
- 実装コード差分（git から取得。**stacked 対応**。会話でなく git から導出する）:
  - 対象ブランチ = `git branch --show-current`。
  - その base を `.specs/<feature>/tasks.md` の各フェーズ見出し（`ブランチ: X（base: Y）`）から引く。単一フェーズなら base = デフォルトブランチ。
  - このフェーズの変更 = `git diff <base>`（base の先端 → 作業ツリー）。コミット前でも後でも同じコマンドで**このフェーズ分だけ**が得られる。
  - **`git diff <デフォルトブランチ>` で固定しない**。stacked では base が `p(N-1)` なので、デフォルトブランチと比べると下位フェーズの変更まで巻き込みレビュー範囲が壊れる。

## 保存先
`.specs/<feature>/review.md`

## 進め方
1. `$ARGUMENTS[0]` が未指定なら「使い方: /review <feature> [auto]」を表示して終了
2. 「入力」の手順で対象フェーズの差分を導出し、仕様・設計との整合性を確認する
3. `coderabbit:code-review` を起動してコード品質をレビューさせる
4. CodeRabbit の指摘と仕様整合性の確認結果を合わせて OK/NG を判定する
5. 結果を `.specs/<feature>/review.md` に保存する
6. 結果を報告し、末尾の「次ステップ提示」の分岐ブロックで次の手順を提示する

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
仕様・設計との整合とコード品質をレビューし、結果を報告できたら完了。
次工程は、フェーズループ本流では review OK → `/commit`（qa は全フェーズ後に 1 回だけ回す）。単体起動で試すときだけ `/qa` に繋ぐこともあるが、orchestrator 経由の本流の next は commit。NG の戻し先（設計の根本問題は design／それ以外は impl）は orchestrator が判断する。

## 次ステップ提示
単体起動で完了したら、判定に応じて次の分岐ブロックを**コードフェンスで囲まず**プレーンテキストで出力し、次スキルは自動起動せずユーザーの実行を待って終了する。完了時点で OK / NG（と NG の種別）が確定するので、該当する 1 つだけを提示する。

```
✅ レビュー完了 — .specs/<feature>/review.md
OK：/qa <feature>
NG（設計の問題）：/design <feature>
NG（実装の問題）：/impl <feature>
```

自律モード（起動引数に `auto` を含む）では上記ブロックを出さず、確定した遷移先を 1 行の簡易ログだけ残す（例: `次: /qa <feature>`）。次スキルの起動は呼び出し元（orchestrator）が行う。
