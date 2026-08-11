---
name: hostdev-setup
description: backend の lint/codegen/test をコンテナ非経由でホスト実行する hostdev を、新しいプロジェクトに展開する。api コンテナのマウント切り替えが面倒なとき、対象PJに hostdev.conf を用意して lint/test をホストで回せるようにする。「hostdev 展開」「ホストで lint/test したい」「コンテナ立てずにテスト」などで使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[対象プロジェクト]"
---

# hostdev 展開スキル

## 役割
backend のツール（lint / codegen / test）を api コンテナに入らずホストで実行できるようにする `hostdev` を、新しいリポジトリに展開する。

並列 worktree 開発では、ソースを bind mount する api コンテナを worktree ごとにマウント切り替えする必要があり、それが lint/test/codegen のたびの詰まりになる。`hostdev` はこれを回避する**個人用ランチャー**（`swws` と同じ思想）。

- **共通エンジン**: `~/.local/bin/hostdev`（プロジェクト非依存。1 本だけ存在）
- **各リポジトリ直下の `hostdev.conf`**: そのPJ固有の値とコマンドだけを定義（**git 管理外**）

`hostdev <サブコマンド>` を叩くと、エンジンが repo root 直下の `hostdev.conf` を読み込み、その中の `cmd_<サブコマンド>` 関数を実行する。

### 二分の原則
- **DB 不要**（lint / di / gqlgen / mockgen / format）→ ホストで完結。コンテナ不要
- **DB 必要**（test）→ DB コンテナだけあればよい。DB コンテナはソースを bind mount しないので**api コンテナのマウント切り替え対象外**。稼働中コンテナから環境変数を取り込み、DB 接続先だけホスト到達先へ向け替えて実行する

## 入出力
- **入力**: 対象PJの Makefile / compose / DB 接続コード、稼働中コンテナ
- **出力**: 対象PJの repo root 直下 `hostdev.conf`（git 管理外）

## いつ使うか
- 新しい Go プロジェクトで、コンテナ非経由の lint/test を使いたいとき
- **構造の似た Go プロジェクト群が対象。** Node 系（training-email-next 等）は Go ツールチェーンの前提が当てはまらないため対象外

## モード
人が起動する 1 回きりのセットアップ。

固有値は**ドキュメントを鵜呑みにせず実コードで確認する**。確認できない値は推測で埋めず、要確認に挙げる。

## 進め方

### Step 1: 前提確認
ホスト側ツールと、対象PJの稼働コンテナを確認する。

```bash
# ホスト側ツール（Go プロジェクトの場合）
which go golangci-lint gotestsum sql-migrate mockgen
# 稼働中コンテナと、DB のホスト露出ポート
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

- DB がホストの何番ポートに露出しているか（例 `0.0.0.0:4306->3306`）を控える → `HOST_DB_ADDR`
- api コンテナ名（環境変数の取り込み元）と DB コンテナ名を控える

ホスト側ツールが揃っていない場合は、何が足りないかを示して中断する。

**完了ゲート:** ツールとコンテナの状況を把握したか。

### Step 2: 固有値を集める
対象PJの Makefile / compose / DB 接続コードを読み、次を確定する。

| 値 | 内容 |
|---|---|
| `WORKDIR` | ツールを実行する作業ディレクトリ（repo root からの相対。モノレポなら `xxx-backend` 等） |
| `API_CONTAINER` / `DB_CONTAINER` | `docker ps` の実名 |
| `HOST_DB_ADDR` | ホストから届く DB アドレス（例 `127.0.0.1:4306`） |
| 各コマンド | lint / di / gqlgen / mockgen / format（多くは本体 Makefile のターゲットに委譲できる） |
| test の流れ | test DB のリセット方法 / マイグレーションコマンド / テストランナー |
| DB 接続の環境変数名 | go テストが使うもの（例 `ELEARNING_DB_HOST`）。ホスト到達先へ上書きする対象 |

> go-sql-driver は `mysql.Config.Addr` にポートを含められるので、接続コードが `Addr` に環境変数をそのまま入れているなら `ENV=127.0.0.1:4306` で足りる。マイグレーションツールの config がホスト:ポートを固定文字列で持つ場合は、**ホスト向け config を別途用意する**（下の実例参照）。

**完了ゲート:** 表の値が実コードで裏取りできたか（できない値は要確認に回す）。

### Step 3: 書き出し

**3-1 `hostdev.conf` を書く**

repo root 直下に作る。source される shell なので、変数と `cmd_*` 関数を定義する。エンジンが提供するヘルパー `hd_import_container_env <container>` を test で使える。

契約：
- `WORKDIR` を設定する（未設定なら repo root）
- `cmd_<サブコマンド>()` を定義すると `hostdev <サブコマンド>` で呼ばれる。第 1 引数以降がそのまま渡る

**3-2 git 管理外にする**

tracked な `.gitignore` は触らず、共通 `.git/info/exclude` に登録する（worktree では info/exclude は共通 git ディレクトリにあり**全 worktree で共有**される）。

```bash
common="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
grep -qxF '/hostdev.conf' "$common/info/exclude" || printf '/hostdev.conf\n' >> "$common/info/exclude"
git status --porcelain | grep -i hostdev && echo "NG: git に出ている" || echo "OK"
```

**完了ゲート:** `hostdev.conf` を作り、`git status` に出ないことを確認したか。

### Step 4: 検証
小さいパッケージで lint と test を実際に流し、通ることを確認する（**書いて終わりにしない**）。

```bash
hostdev lint <自己完結した小さいパッケージ>
hostdev test <DBのみに依存する repository/query 層の小さいパッケージ>
```

**完了ゲート:** lint と test が実際に通ったか。

### Step 5: 出力

次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。

### hostdev 展開完了
<どの PJ に展開し、何が通ったかを 1 行>
- <定義したサブコマンド・検証したパッケージ 最大 3 行>

生成物: `<対象PJ>/hostdev.conf`

### 要確認
- <実コードで裏取りできず暫定にした値>
- <ホストから回せないテスト>（例: Redis クラスタ等コンテナ間 DNS 依存）

### 次の一手
- 使ってみる: `hostdev lint` / `hostdev test`

カードは**やったこと**・**要確認**・**次の一手**の 3 ブロックに分ける。混ぜない。

- やったこと: 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**。`hostdev.conf` の中身は転記しない。
- 要確認: **対象外にしたテスト**と**裏取りできなかった値**を必ず挙げる。ここを黙ると「ホストで全部回る」と誤解される。無ければブロックごと省略する。
- 次の一手: 1 行に留める。

**中断時**: ヘッダを `### hostdev 展開中断` に差し替え、一言サマリに中断理由（ホスト側ツールが足りない・固有値を確定できない・検証が通らないなど）、次の一手に必要な対応を書く（`hostdev.conf` を作った後なら生成物の行は残す）。

## 制約
- **Redis クラスタ等、コンテナ間 DNS（`xxx_rediscluster` 等）に依存するテストはホストから名前解決できず対象外。** DB のみに依存する repository/query 層向け
- 環境変数の丸ごと取り込みでは、コンテナ側の `PATH` や `GOTOOLCHAIN=local` がホスト値を上書きすると docker/go が壊れる。エンジンの `hd_import_container_env` がホスト固有変数と Go ビルド変数を除外して対処済み。**新たな除外が必要なら Step 2 で見極める**

## 実例: elearning-service の hostdev.conf

```bash
WORKDIR="elearning-backend"

API_CONTAINER="${API_CONTAINER:-ev2_api}"
DB_CONTAINER="${DB_CONTAINER:-sec_db}"
HOST_DB_ADDR="${HOST_DB_ADDR:-127.0.0.1:4306}"

# DB 不要
cmd_lint() { golangci-lint run --fix --max-issues-per-linter 0 --max-same-issues 0 "${1:-./...}"; }
cmd_di() { make di; }
cmd_gqlgen() { make gqlgen; }
cmd_mockgen() { make mockgen; }
cmd_format() { make format; }

# DB 必要
cmd_test() {
  local target="${1:-./...}"
  case "$target" in
    *.go | ./...) ;;
    *) target="./$target/..." ;;
  esac

  hd_import_container_env "$API_CONTAINER"
  export ELEARNING_DB_HOST="$HOST_DB_ADDR"
  export CUBE_DB_HOST="$HOST_DB_ADDR"

  docker exec "$DB_CONTAINER" mysql -u"$ELEARNING_DB_USER" -p"$ELEARNING_DB_PASSWORD" \
    -e "DROP DATABASE IF EXISTS \`${ELEARNING_TEST_DB_NAME}\`; CREATE DATABASE \`${ELEARNING_TEST_DB_NAME}\`;"

  local dbconfig
  dbconfig="$(mktemp -t hostdev-dbconfig.XXXXXX)"
  trap 'rm -f "$dbconfig"' RETURN
  cat >"$dbconfig" <<YAML
test:
  dialect: mysql
  datasource: \${ELEARNING_DB_USER}:\${ELEARNING_DB_PASSWORD}@tcp(${HOST_DB_ADDR})/\${ELEARNING_TEST_DB_NAME}?parseTime=true
  dir: ./internal/app/infra/db/mysql/migrations
YAML

  sql-migrate up -config="$dbconfig" -env=test
  gotestsum --format dots -- -race "$target"
}
```

## 共通エンジン（再インストール用）

`~/.local/bin/hostdev` が無い環境ではこれを設置する（PATH に `~/.local/bin` が必要）。

```bash
#!/usr/bin/env bash
set -euo pipefail

die() { echo "hostdev: $*" >&2; exit 1; }

# 稼働中コンテナの環境変数一式を取り込む。PATH や Go ビルド系変数はコンテナ値で
# 上書きするとホスト側のツール解決・ビルドが壊れるため取り込まない。
hd_import_container_env() {
  local container="$1"
  local kv
  while IFS= read -r -d '' kv; do
    case "${kv%%=*}" in
      PATH | HOME | HOSTNAME | PWD | OLDPWD | SHLVL | TERM | USER | _) continue ;;
      GOPATH | GOROOT | GOTOOLCHAIN | GOCACHE | GOMODCACHE | GOFLAGS | GOENV) continue ;;
    esac
    export "$kv"
  done < <(docker exec "$container" env -0)
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "git リポジトリ内で実行してください"
conf="$repo_root/hostdev.conf"
[ -f "$conf" ] || die "設定が見つかりません: $conf"

WORKDIR="."
# shellcheck disable=SC1090
source "$conf"

[ $# -ge 1 ] || die "使い方: hostdev <サブコマンド> [引数]"
sub="$1"; shift
cd "$repo_root/$WORKDIR"
declare -F "cmd_$sub" >/dev/null || die "未対応のサブコマンド: $sub"
"cmd_$sub" "$@"
```

## 完了条件
対象PJの repo root に `hostdev.conf` を作り、`git status` に出ないことを確認し、**`hostdev lint` と `hostdev test` が実際に通った**ら完了。書いただけ・検証していない状態は未完了。
