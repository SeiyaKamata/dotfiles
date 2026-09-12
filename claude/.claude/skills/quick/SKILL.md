---
name: quick
description: requirements.mdを受け取り、design/tasksを介さず直接実装する軽量スキル。.specs/<feature>/requirements.mdが出来上がり、設計判断も大タスクへの分割も不要なほど小さい変更のときに使う。
allowed-tools: Read, Bash, Glob, Agent
argument-hint: "<feature>"
---

# クイック実装スキル（コーディネーター）

## 役割
`.specs/<feature>/requirements.md` だけを仕様として直接実装する。

実装そのものは `implementer` サブエージェントに委譲し、このスキル自身はコーディネーターに徹してコードを直接書かない。
メインは `requirements.md` の中身を読まず、実際に読むのは `implementer` 自身。
これにより「requirements.md だけで実装が通るか＝仕様の自己完結性」を検証できる。

## 入出力
- 入力: `.specs/<feature>/requirements.md`
- 出力: 実装コード

## 引数
- `$ARGUMENTS[0]`: feature 名（必須）

## 対話方針
途中でユーザーに何も聞かない。
実装を続けられない事態では止まる。

## 用語（前提）
用語の定義は `claude/CLAUDE.md`「用語集」に従う。

## 進め方
各 Step は順番に実行する。
**完了ゲート**を通過するまで次へ進まない。

### Step 1: 引数チェック
- `$ARGUMENTS[0]`（feature）が未指定なら「使い方: /quick <feature>」を表示して終了

**完了ゲート:** feature 名を確定したか。

### Step 2: 入力確認とコンテキスト収集
ブランチを切る前に行う。
ここで止まる場合、空のブランチを残さない。

- `.specs/<feature>/requirements.md` の存在確認だけを行う。
  中身は読まない。
  無ければ中断し「先に /spec <feature> を実行してください」を示す
- テスト・ビルドコマンドを `package.json`、`Makefile`、`go.mod`、`pyproject.toml` などから確認する
- `git status --porcelain` でベースライン

**完了ゲート:** `requirements.md` の存在を確認し、テスト・ビルドコマンドと `git status` のベースラインを押さえたか。

### Step 3: ブランチ準備
PR 運用の有無に関わらず、常にブランチを切る。
実装を隔離しておけば、途中で捨てる・作り直すのが安全になる。

ブランチ名は `<feature>`。
デフォルトブランチから作成する：

```
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); DEFAULT=${DEFAULT##*/}
[ -z "$DEFAULT" ] && { git remote set-head origin --auto >/dev/null; DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD); DEFAULT=${DEFAULT##*/}; }
git fetch origin "$DEFAULT"
git checkout -b <feature> "origin/$DEFAULT"
```

`sed` をパイプで挟まないのは、権限の allowlist に無く承認待ちで止まるため。

**完了ゲート:** 実装ブランチ `<feature>` を作成したか。

### Step 4: 実装

implementer への配布: 1 つの `implementer` エージェントに配布する。
プロンプトに渡すもの：
- feature 名。specs のパスを含む
- 「`.specs/<feature>/requirements.md` だけを仕様として、全要件を実装すること」
- リポジトリのテスト／ビルドコマンド
- 「git には触れず、報告フォーマットで返す」旨

品質水準は指定せず、`implementer` の既定である本番品質・タスク単位の確認ありをそのまま使う。

報告の取り込み: `implementer` の報告が返ったら：
1. `変更ファイル`・`作業ごとの確認` を確認する
2. `blockers` があれば「エラー処理」に従う
3. `自分で決めた判断` は控えておき、Step 5 の「要確認」に出す

最終確認:
- リポジトリ全体のテスト・ビルドを実行する。最終確認はメインが 1 回まとめて行う
- `requirements.md` の各要件が満たされているか確認する

**完了ゲート:** blockers が無く、最終確認まで完了したか。

### Step 5: 出力

次の完了カードを、コードフェンス自体は出さずに中身だけそのまま出力して終了する。
カードの前後に作業サマリ・所感・補足を足さない。

```markdown
### クイック実装完了
<何を実装したかを 1 行>
- <主要な結果 最大 3 行>

### 要確認
- <仕様に根拠が無く implementer が自分で決めた点> 該当: ファイル

### 次の一手
- テストを回す: `/test <feature>`
```

カードは**やったこと**・**要確認**・**次の一手**の 3 ブロックに分ける。
混ぜない。

- やったこと: 一言サマリは 1 行。
  主要な結果は `- ` の箇条書きで最大 3 行。
  無ければ行ごと省略する。
  変更ファイルの一覧や implementer の報告詳細は列挙せず、git 差分に寄せる。
- 要確認: `implementer` の報告の `自分で決めた判断` をそのまま出す。
  無ければブロックごと省略する。
- 次の一手: テストが無いリポジトリなら `- レビューに進む: /review <feature>` に差し替える。
  テストコマンドの有無は Step 2 で分かっている。

**中断時**: 同じブロック構成でヘッダを `### クイック実装中断` に差し替える。

- やったこと: 一言サマリに中断理由を書く。
  `requirements.md` が無い・blockers・最終テスト失敗などが該当する。
- 次の一手: 復帰コマンド。
  `requirements.md` が無ければ `- 要件を作る: /spec <feature>`。
  blockers が設計判断を要するものなら `- /design <feature> へ合流`。

**完了ゲート:** カードを出力したか。

## エラー処理
- `implementer` が `blockers` を報告 → メインで判断する。
  - 軽微な曖昧さなら追加指示を添えて `implementer` を再配布する
  - 設計判断が要る内容なら中断カードを出し `/design <feature>` への合流を促す。
    実装方針で悩む・想定より影響範囲が広いなどがこれに当たる。
    この場合 `/quick` を選んだ判断そのものが誤りだったので、`/quick` 内でループしない
- 最終テストが失敗し続ける場合 → 根本原因を調査し、`implementer` に再配布して最小限の修正を試みる。
  それでも通らなければ中断する

## 完了条件
`requirements.md` の全要件が実装され、リポジトリ全体のテスト・ビルドがパスしたら完了。
次工程の起動は完了条件に含めない。
