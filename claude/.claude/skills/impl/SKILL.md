---
name: impl
description: 実装計画のタスク一覧を受け取り実装を行う。.specs/plan.jsoncが出来上がったら使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, WebSearch, WebFetch
argument-hint: "[task-numbers]"
---

# 実装スキル

## 役割
`.specs/plan.jsonc` の `tasks` を実装する。
コードは `implementer` サブエージェントに書かせ、自分はコーディネーターとして配布・ビルド確認・進捗更新だけを行う。
仕様だけで実装が通るかを確かめるため、自分ではコードを書かない。

## 判断が割れる点の扱い
途中でユーザーに質問も承認も求めない。
未完了の事前セットアップ・implementer の blockers・ビルド失敗のように実装を続けられない事態では止まり、結果に理由を書いて分岐を呼び出し元に委ねる。
推測で埋めると誤った実装がそのまま積み上がる。

## 配布の単位
タスクごとに `implementer` を 1 体、依存順に逐次呼ぶ。
同じ作業ツリーへの Write が衝突するので並列には配布しない。
タスクが大きすぎても impl 側で分割せず、タスク分解の側を直す。

## 進め方

### Step 1: 引数の確認
- `$ARGUMENTS[0]` に `1,2` の形でタスク番号があれば手動モードにし、指定タスクだけを実装する
- `.specs/feature.jsonc` の `repo` が、今いる worktree の `git rev-parse --path-format=absolute --git-common-dir` の basename と違えば、Step 7 の次の一手で「`<repo>` の worktree で叩く」と案内して終了

### Step 2: コンテキスト収集
配布と確認に要るものだけを集め、`requirements.jsonc` の本文と `plan.jsonc` の `summary` `decisions` `deviations` `appendix` は読まない。
仕様の裏取りは `implementer` が自分で行う。

- `.specs/plan.jsonc` の `tasks` から、タスクごとのメタ情報 `req` `depends` `follows` と狙いの文、細部
- ビルド設定ファイルから読み取ったテスト・ビルドコマンド

対象のタスクの `depends` に `setup` の `done` が `false` の `S<n>` があれば、人の作業待ちなので止まる。
結果に当該項目の内容と `to` をそのまま書く。
次の一手は、`to` があれば相手 PJ のセッションと会話して詰め、無ければ当該項目を実施して `/impl` を再実行する。

### Step 3: 実装ブランチの確定
実装ブランチ `<branch>` 1 本の上で全タスクを実装する。
実装を隔離しておけば、途中で捨てる・作り直すのが安全になる。
実装ブランチ名 `<branch>` は `.specs/feature.jsonc` の `branch_name` にする。
HEAD の状態で分岐する:
- `<branch>` ブランチが既にある → checkout して前回の実装を再開する
- detached HEAD → `git checkout -b <branch>` で今の HEAD から切る
  - worktree はデフォルトブランチの先端に detached で作られているので、これが起点になる

### Step 4: 配布対象の決定

- 手動モードでなければ、未完了のタスクの最初の 1 つ。タスクの完了は `done` が `true` かで判定する
- 手動モードなら指定タスクだけ

### Step 5: implementer に配布

プロンプトに渡すもの:
- `tasks` の該当の要素から転記した `goal`・`req`・`details`
- タスクに `follows` があれば、そのパスをそのまま渡し、その形に合わせて書く旨を明示する
- 「plan.jsonc のタスク一覧に書かれた順に実装し、git・plan.jsonc・テストとビルドの実行には触れず、報告フォーマットで返す」旨
  - `implementer` 側にも定義済みだが明示する

### Step 6: 報告の取り込みとビルド確認

`implementer` の報告が返ったら次を順に行う。
1. `変更ファイル`・`タスクごとの確認` を確認する
2. Step 2 で確定したビルドコマンドでビルドを実行する。コマンドが無いリポジトリでは飛ばす
3. 完了と報告されたタスクの `"done": false` を、Edit で該当のタスクの 1 か所だけ `"done": true` に置換する。全体は書き直さない。`setup` の `S<n>` は人が書き換えるので触らない
4. `blockers` があるタスクは `done` を変えず、次で分ける
   - 軽微なら追加指示を添えて同じタスクを再配布する
   - 上流の工程の問題なら Step 7 の結果に理由を書いて止め、戻し先は呼び出し元に委ねる
5. `自分で決めた判断` を控え、Step 7 の要確認に出す

ビルドが通らないまま次のタスクを配布しない。
壊れた土台を渡すと、既存コードに合わせて書く次の `implementer` がそれに引きずられる。
ビルドエラーを添えて同じタスクを再配布し、それでも通らなければ Step 7 の結果に理由を書いて止める。

手動モードでなく `tasks` に未完了のタスクが残っていれば Step 4 に戻り次を配布し、残っていなければ Step 7 へ進む。

### Step 7: 出力

次を出して終了する。
- 結果: 何タスクを実装したか
- 詳細: `.specs/plan.html`
- 次の一手: `/test`。テストコマンドが無ければ `/review`

要確認があれば `要確認: <内容>` を 1 件 1 行で足す。
