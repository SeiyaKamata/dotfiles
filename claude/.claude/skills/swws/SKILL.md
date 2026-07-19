---
name: swws
description: git worktree を Docker のマウント先として起動し直す。切り替え前に使用中の worktree を調べ、別 worktree が使用中なら勝手に奪わず確認する。並列開発の事故防止用。
argument-hint: "[web|full|api|sec-web|worker|stop|status]"
allowed-tools: Bash(swws *), Bash(docker ps *), Bash(git rev-parse *)
---

# swws（worktree マウント切り替え・使用中チェック付き）

## 役割
現在いる git worktree を Docker のマウント先にして compose を起動し直す（`swws` コマンドのラッパー）。
compose プロジェクトは 1 リポジトリ 1 つしかなく、`swws` で `up` すると **他の worktree で稼働中の同プロジェクトを黙って奪ってしまう**。別セッションが別 worktree で作業中だと事故になる。
そのため **切り替え前に必ず使用中の worktree を調べ、自分以外が使用中なら勝手に切り替えず人間に確認する**。

## 前提（状態の持ち方）
状態は自前で持たない。**Docker の稼働中コンテナが唯一の真実**。
`swws status` は、そのプロジェクトの稼働中コンテナが持つ `com.docker.compose.project.working_dir` ラベルを見て、今どの worktree がマウントされているかを返す。
**「起動＝占有 / 停止＝解放」**。停止済みコンテナは解放とみなす（稼働中のみ使用中判定）。

## 引数
- `$ARGUMENTS`: 起動プロファイル（`web` / `full` / `api` / `sec-web` / `worker`）、または `stop`（解放）/ `status`（確認のみ）。省略時は `web`。

## 進め方

### Step 1: 現在の worktree とプロファイルを確認する
`git rev-parse --show-toplevel` で今いる worktree を把握する。git worktree 外なら中止して「worktree 内で実行してください」と伝える。
`$ARGUMENTS` が空なら `web` とみなす。

### Step 2: `status` / `stop` はそのまま実行する
- `$ARGUMENTS` が `status` → `swws status` を実行して結果を伝えるだけ（切り替えない）。ここで終了。
- `$ARGUMENTS` が `stop` → `swws stop` を実行して「解放しました」と伝える。ここで終了。

### Step 3: 切り替え前に使用中を調べる（up 系のときのみ）
`swws status` を実行し、出力で分岐する：

- **`空き:`** → 誰も使っていない。Step 5 へ進んで切り替える。
- **`使用中(自分):`** → 自分の worktree が既に稼働中。同じ worktree なので安全。Step 5 へ進んで再起動する。
- **`使用中(別worktree):`** → **別の worktree が使用中**。勝手に切り替えない。Step 4 へ。
- **`⚠️ 混在:`** → 同一プロジェクトに複数 worktree が同居している異常状態。勝手に切り替えない。Step 4 へ。

### Step 4: 別 worktree が使用中／混在のときは人間に確認する
どの worktree が使っているかを提示し、番号で選ばせる（勝手に進めない）：

```
⚠️ <project> は別の worktree で使用中です:
  使用中: <他の worktree パス>
  今ここ: <自分の worktree パス>

どうしますか？
1: 中止する（別セッションが作業中かもしれない）
2: 使用中側を止めてから自分に切り替える（SWWS_FORCE=1 で強制切り替え）
3: 状態だけ見て何もしない
```

- **1** を選んだら何もせず終了する。
- **2** を選んだら `SWWS_FORCE=1 swws <profile>` で強制的に切り替える。混在の場合は先に `swws stop` で全停止してから起動し直すときれいになる旨を添える。
- **3** を選んだら `swws status` の内容を再掲して終了する。

**混在（`⚠️ 混在:`）のとき**は、まず `swws stop` で全停止 → 自分の worktree で起動し直す、を推奨として提示する。

### Step 5: 切り替える
```
swws <profile>
```
swws 本体にも同じガードが入っているため、万一別 worktree が使用中なら exit 2 で止まる。その場合は Step 4 に戻って人間に確認する。

### Step 6: 結果を報告する
どの worktree のどのプロファイルに切り替えたか（または解放したか）を 1 行で報告する。

## 完了条件
- `status`: 使用中状態を報告した
- `stop`: 解放した
- up 系: 自分の worktree に切り替えた、または別 worktree 使用中を検知して人間の判断を仰いだ

## エラー処理
- git worktree 外で実行された: 中止して worktree 内で実行するよう伝える
- `未対応:` が出た（swws のリポジトリ表に無い）: 対象リポジトリでないため中止する
- swws が exit 2（ガード発動）: Step 4 の確認フローに入る。ユーザー承認なしに `SWWS_FORCE=1` を付けない
