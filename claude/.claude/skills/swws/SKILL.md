---
name: swws
description: git worktree を Docker のマウント先として起動し直す。切り替え前に使用中の worktree を調べ、別 worktree が使用中なら勝手に奪わず確認する。並列開発の事故防止用。
argument-hint: "[-loop] [web|full|api|sec-web|worker|stop|status]"
allowed-tools: Bash(swws *), Bash(docker ps *), Bash(git rev-parse *)
---

# worktree マウント切り替えスキル

## 役割
現在いる git worktree を Docker のマウント先にして compose を起動し直す（`swws` コマンドのラッパー）。

compose プロジェクトは 1 リポジトリ 1 つしかなく、`swws` で up すると**他の worktree で稼働中の同プロジェクトを黙って奪ってしまう**。別セッションが別 worktree で作業中だと事故になる。

使用中判定は `swws` コマンド本体のガード（別 worktree 稼働中なら exit 2）に任せ、**この skill は「exit 2 が返ったら勝手に奪わず人間に確認する」という判断ポリシーだけを担う**。

## 入出力
- **入力**: カレント worktree（`git rev-parse --show-toplevel`）と起動プロファイル
- **出力**: ファイル成果物は持たない（Docker の稼働状態が変わる）

**状態は自前で持たない。Docker の稼働中コンテナが唯一の真実。** `swws status` は稼働中コンテナの `com.docker.compose.project.working_dir` ラベルを見て、今どの worktree がマウントされているかを返す。**起動＝占有 / 停止＝解放**で、停止済みコンテナは解放とみなす。

## モード
**別 worktree を奪う判断は人がする**（勝手に奪うと他セッションの作業を壊す）。

exit 2（別 worktree 使用中）のときだけ確認する。**破壊的操作なので確認を残す**（成果物の内容については確認しない）。

## 引数
- `$ARGUMENTS`: 起動プロファイル（`web` / `full` / `api` / `sec-web` / `worker`）、または `stop`（解放）/ `status`（確認のみ）。省略時は `web`
- `-loop`: 別 worktree が使用中のとき **5 分 → 10 分 → 10 分で最大 3 回まで空くのを待って**切り替える。空かなければ失敗し、**別 worktree は奪わない**。ユーザーが `/swws -loop <profile>` と明示した場合はそれを尊重する

## 進め方

### Step 1: 前提確認
`git rev-parse --show-toplevel` で今いる worktree を把握する。**git worktree 外なら中止**して「worktree 内で実行してください」と伝える。

`$ARGUMENTS` が空なら `web` とみなす。

### Step 2: `status` / `stop` はそのまま実行する
- `status` → `swws status` を実行して結果を伝えるだけ（切り替えない）。Step 4 へ
- `stop` → `swws stop` を実行して解放する。Step 4 へ

### Step 3: 切り替える（up 系）

**3-1 そのまま叩く**

使用中判定はコマンド側のガードに任せる：

```
swws <profile>
```

`swws` 本体が**自分以外の worktree が稼働中なら exit 2 で止まる**（空き・自分の worktree のときはそのまま起動）。exit コードで分岐する：

| exit | 意味 | 進み先 |
|---|---|---|
| 0 | 切り替え成功 | Step 4 |
| 2 | 別 worktree 使用中 or 混在 | **勝手に奪わず** 3-2 |
| 1 / `未対応:` | エラー | 「エラー処理」へ |

ユーザーが `-loop` を明示していた場合は `swws -loop <profile>` を **`run_in_background` で**実行する（最大 25 分待ちうるため）。

**3-2 exit 2 のときは人間に確認する**

コマンドが stderr に出した使用中 worktree を提示し、番号で選ばせる（**勝手に進めない**）：

```
<project> は別の worktree で使用中です:
  使用中: <他の worktree パス>
  今ここ: <自分の worktree パス>

どうしますか？
1: 空くのを待って切り替える（swws -loop <profile>・最大25分・別worktreeは奪わない）
2: 中止する（別セッションが作業中かもしれない）
3: 今すぐ強制的に奪って切り替える（SWWS_FORCE=1・別セッションの環境を止める）
4: 状態だけ見て何もしない
```

- **1** → `swws -loop <profile>` で空くまで待つ。**最大 25 分（5+10+10）待ちうるため Bash のタイムアウトを超える。必ず `run_in_background` で実行する。** 空かずに失敗（exit 2）したら 3-2 に戻って再確認する
- **2** → 何もせず終了する
- **3** → `SWWS_FORCE=1 swws <profile>` で強制的に切り替える
- **4** → `swws status` を実行して状態を再掲し終了する

`swws status` が**混在**（同一プロジェクトに複数 worktree が同居）を示したときは、まず `swws stop` で全停止 → 自分の worktree で起動し直す、を推奨として添える。

### Step 4: 出力

次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。

### worktree 切り替え完了
<どのプロジェクトをどのプロファイルで起動したかを 1 行>
- <切替先 worktree・プロファイルなど 最大 3 行>

### 要確認
- 混在: <同一プロジェクトに複数 worktree が同居している旨と推奨手順>

### 次の一手
- この worktree で作業を続行

カードは**やったこと**・**要確認**・**次の一手**の 3 ブロックに分ける。混ぜない。

- やったこと: 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**。切替先 worktree のパスとプロファイル（`status` なら使用中の worktree）を載せ、`docker compose` の出力ログは転記しない。swws は**ファイル成果物を持たない**ので生成物の行は出さない。
- 要確認: 混在を検知したとき、強制切替（`SWWS_FORCE=1`）で**別セッションを止めたとき**に出す。無ければブロックごと省略する。
- 次の一手: 1 行に留める。

3-2 の確認フローは**対話ゲート**なので、ナレーション制限の対象外として従来どおり出す（そのうえで確認後の結果をカードに畳む）。

**中断時**: ヘッダを `### worktree 切り替え中断` に差し替え、一言サマリに中断理由、次の一手に判断先を書く（別 worktree 使用中なら `- 強制切替を判断: SWWS_FORCE=1 swws <profile>`）。

## エラー処理
- **git worktree 外で実行された** → 中止して worktree 内で実行するよう伝える
- **`未対応:` が出た**（swws のリポジトリ表に無い）→ 対象リポジトリでないため中止する
- **swws が exit 2（ガード発動）** → 3-2 の確認フローに入る。**ユーザー承認なしに `SWWS_FORCE=1` を付けない**

## 完了条件
- `status`: 使用中状態を報告した
- `stop`: 解放した
- up 系: 自分の worktree に切り替えた、**または別 worktree 使用中を検知して人間の判断を仰いだ**（奪わずに止まるのも完了）
