---
name: swws
description: git worktree を Docker のマウント先として起動し直す。切り替え前に使用中の worktree を調べ、別 worktree が使用中なら勝手に奪わず確認する。並列開発の事故防止用。
argument-hint: "[-loop] [web|full|api|sec-web|worker|stop|status]"
allowed-tools: Bash(swws *), Bash(docker ps *), Bash(git rev-parse *)
---

# swws（worktree マウント切り替え・使用中チェック付き）

## 役割
現在いる git worktree を Docker のマウント先にして compose を起動し直す（`swws` コマンドのラッパー）。
compose プロジェクトは 1 リポジトリ 1 つしかなく、`swws` で `up` すると **他の worktree で稼働中の同プロジェクトを黙って奪ってしまう**。別セッションが別 worktree で作業中だと事故になる。
使用中判定は `swws` コマンド本体のガード（別 worktree 稼働中なら exit 2）に任せ、**この skill は「exit 2 が返ったら勝手に奪わず人間に確認する」という判断ポリシーだけを担う**。

## 前提（状態の持ち方）
状態は自前で持たない。**Docker の稼働中コンテナが唯一の真実**。
`swws status` は、そのプロジェクトの稼働中コンテナが持つ `com.docker.compose.project.working_dir` ラベルを見て、今どの worktree がマウントされているかを返す。
**「起動＝占有 / 停止＝解放」**。停止済みコンテナは解放とみなす（稼働中のみ使用中判定）。

## 引数
- `$ARGUMENTS`: 起動プロファイル（`web` / `full` / `api` / `sec-web` / `worker`）、または `stop`（解放）/ `status`（確認のみ）。省略時は `web`。
- `-loop`: 併せて指定すると、別 worktree が使用中のとき **5分 → 10分 → 10分 で最大 3 回まで空くのを待って**切り替える（`swws -loop <profile>`）。空かなければ失敗し、**別 worktree は奪わない**。ユーザーが `/swws -loop <profile>` と明示した場合はそれを尊重する。

## 進め方

### Step 1: 現在の worktree とプロファイルを確認する
`git rev-parse --show-toplevel` で今いる worktree を把握する。git worktree 外なら中止して「worktree 内で実行してください」と伝える。
`$ARGUMENTS` が空なら `web` とみなす。

### Step 2: `status` / `stop` はそのまま実行する
- `$ARGUMENTS` が `status` → `swws status` を実行して結果を伝えるだけ（切り替えない）。ここで終了。
- `$ARGUMENTS` が `stop` → `swws stop` を実行して「解放しました」と伝える。ここで終了。

### Step 3: 切り替える（up 系）
使用中判定はコマンド側のガードに任せ、そのまま叩く：
```
swws <profile>
```
`swws` 本体が **自分以外の worktree が稼働中なら exit 2 で止まる**（空き・自分の worktree のときはそのまま起動）。exit コードで分岐する：

- **exit 0** → 切り替え成功。Step 5 へ。
- **exit 2**（別 worktree 使用中 or 混在）→ 勝手に奪わない。Step 4 へ。
- **exit 1 / `未対応:`** → エラー処理へ。

ユーザーが `-loop` を明示していた場合は `swws -loop <profile>` を **`run_in_background` で**実行する（最大 25分待ちうるため）。

### Step 4: exit 2（別 worktree 使用中）のときは人間に確認する
コマンドが stderr に出した使用中 worktree を提示し、番号で選ばせる（勝手に進めない）：

```
⚠️ <project> は別の worktree で使用中です:
  使用中: <他の worktree パス>
  今ここ: <自分の worktree パス>

どうしますか？
1: 空くのを待って切り替える（swws -loop <profile>・最大25分・別worktreeは奪わない）
2: 中止する（別セッションが作業中かもしれない）
3: 今すぐ強制的に奪って切り替える（SWWS_FORCE=1・別セッションの環境を止める）
4: 状態だけ見て何もしない
```

- **1** を選んだら `swws -loop <profile>` で空くまで待って切り替える。**最大 25分（5+10+10）待ちうるため、Bash ツールのタイムアウトを超える。必ず `run_in_background` で実行する**こと。空かずに失敗（exit 2）したら Step 4 に戻って再度確認する。
- **2** を選んだら何もせず終了する。
- **3** を選んだら `SWWS_FORCE=1 swws <profile>` で強制的に切り替える。
- **4** を選んだら `swws status` を実行して状態を再掲し終了する。

`swws status` が **`⚠️ 混在:`**（同一プロジェクトに複数 worktree が同居）を示したときは、まず `swws stop` で全停止 → 自分の worktree で起動し直す、を推奨として添える。

### Step 5: 結果を報告する
どの worktree のどのプロファイルに切り替えたか（または解放したか）を 1 行で報告する。

## 完了条件
- `status`: 使用中状態を報告した
- `stop`: 解放した
- up 系: 自分の worktree に切り替えた、または別 worktree 使用中を検知して人間の判断を仰いだ

## エラー処理
- git worktree 外で実行された: 中止して worktree 内で実行するよう伝える
- `未対応:` が出た（swws のリポジトリ表に無い）: 対象リポジトリでないため中止する
- swws が exit 2（ガード発動）: Step 4 の確認フローに入る。ユーザー承認なしに `SWWS_FORCE=1` を付けない
