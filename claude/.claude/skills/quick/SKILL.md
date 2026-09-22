---
name: quick
description: requirements.mdを受け取り、design/tasksを介さず直接実装する軽量スキル。.specs/<feature>/requirements.mdが出来上がり、設計判断も大タスクへの分割も不要なほど小さい変更のときに使う。
allowed-tools: Read, Bash, Glob, Agent
argument-hint: "<feature>"
---

# クイック実装スキル

## 役割
`.specs/<feature>/requirements.md` だけを仕様として、design / tasks を介さず実装する。
実装は `implementer` に委譲し、自分はコードを書かない。
`requirements.md` の中身も `implementer` だけが読み、自分は読まない。requirements.md だけで実装が通るかで仕様の自己完結性を検証するため。

## 判断が割れる点の扱い
途中でユーザーに質問も承認要求もしない。
仕様に根拠が無く `implementer` が自分で決めた判断は、完了カードの要確認に出す。

## 進め方

### Step 1: 開始条件の確認

- `$ARGUMENTS[0]` が無ければ「使い方: /quick <feature>」を表示して終了
- `.specs/<feature>/requirements.md` の存在だけを確認し、中身は読まない。無ければ Step 4 の中断カードで報告して終了
- テスト・ビルドコマンドを `package.json`、`Makefile`、`go.mod`、`pyproject.toml` から確認する
- `git status --porcelain` でベースラインを押さえる

### Step 2: 実装ブランチの確定

実装ブランチ `<feature>` の上で実装する。
HEAD の状態で分岐する:
- `<feature>` ブランチが既にある → checkout して前回の実装を再開する
- detached HEAD → `git checkout -b <feature>` で今の HEAD から切る
  - worktree はデフォルトブランチの先端に detached で作られているので、これが起点になる
- ブランチ上 → デフォルトブランチを最新化し、その先端から切る

```
DEFAULT=$(git default-branch)
git fetch origin "+refs/heads/$DEFAULT:refs/heads/$DEFAULT"
git checkout -b <feature> "$DEFAULT"
```

### Step 3: 実装

1 つの `implementer` に次を渡して配布する。
- feature 名と specs のパス
- 「`.specs/<feature>/requirements.md` だけを仕様として、全要件を実装すること」
- リポジトリのテスト・ビルドコマンド
- 「git には触れず、報告フォーマットで返す」旨

品質水準は指定せず、`implementer` の既定である本番品質・タスク単位の確認ありをそのまま使う。

報告が返ったら次を行う。
- `変更ファイル`・`作業ごとの確認` を確認する
- `自分で決めた判断` は控え、Step 4 の要確認に出す
- `blockers` があれば内容で分ける
  - 軽微な曖昧さなら追加指示を添えて `implementer` を再配布する
  - 実装方針で悩む・想定より影響範囲が広いのように設計判断が要るなら中断する。`/quick` を選んだ判断そのものが誤りなので `/quick` 内でループしない

最後にリポジトリ全体のテスト・ビルドを 1 回実行し、`requirements.md` の各要件が満たされているか確認する。
テストが失敗したら根本原因を調査し、`implementer` に再配布して最小限の修正を試み、それでも通らなければ中断する。

### Step 4: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### クイック実装中断` にし、1 行目に中断理由を書き、次の一手は `requirements.md` が無ければ `/spec <feature>`、設計判断が要る blockers なら `/design <feature>` にする。

```markdown
### クイック実装完了
<何を実装したかを 1 行>

### 要確認
- <仕様に根拠が無く implementer が自分で決めた点> 該当: ファイル

### 次の一手
- テストを回す: `/test <feature>`
- テストが無いリポジトリならレビューに進む: `/review <feature>`
```

要確認は無ければブロックごと省略する。
