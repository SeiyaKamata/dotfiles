---
name: hostdev-setup
description: backend の lint/codegen/test をコンテナ非経由でホスト実行する hostdev を、新しいプロジェクトに展開する。api コンテナのマウント切り替えが面倒なとき、対象PJに hostdev.conf を用意して lint/test をホストで回せるようにする。「hostdev 展開」「ホストで lint/test したい」「コンテナ立てずにテスト」などで使う。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
argument-hint: "[対象プロジェクト]"
---

# hostdev 展開スキル

backend のツール (lint / codegen / test) を、api コンテナに入らずホストで実行できるようにする `hostdev` を、新しいリポジトリに展開する手順。

## これは何か

並列 worktree 開発では、ソースを bind mount する api コンテナを worktree ごとにマウント切り替えする必要があり、それが lint/test/codegen のたびの詰まりになる。`hostdev` はこれを回避する個人用ランチャー (swws と同じ思想)。

- **共通エンジン**: `~/.local/bin/hostdev` (プロジェクト非依存。1本だけ存在)
- **各リポジトリ直下の `hostdev.conf`**: そのPJ固有の値とコマンドだけを定義 (git 管理外)

`hostdev <サブコマンド>` を叩くと、エンジンが repo root 直下の `hostdev.conf` を読み込み、その中の `cmd_<サブコマンド>` 関数を実行する。

### 二分の原則

- **DB 不要** (lint / di / gqlgen / mockgen / format) → ホストで完結。コンテナ不要。
- **DB 必要** (test) → DB コンテナだけあればよい。DB コンテナはソースを bind mount しないので、api コンテナのマウント切り替え対象外。稼働中コンテナから環境変数を取り込み、DB 接続先だけホスト到達先へ向け替えて実行する。

## いつ使うか

- 新しい Go プロジェクトで、コンテナ非経由の lint/test を使いたいとき
- 構造の似た Go プロジェクト群が対象。Node 系 (training-email-next 等) は Go ツールチェーンの前提が当てはまらないため対象外

## 展開手順

### Step 1: 前提を確認する

ホスト側ツールと、対象PJの稼働コンテナを確認する。

```bash
# ホスト側ツール (Go プロジェクトの場合)
which go golangci-lint gotestsum sql-migrate mockgen
# 稼働中コンテナと、DB のホスト露出ポート
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

- DB がホストの何番ポートに露出しているか (例 `0.0.0.0:4306->3306`) を控える → `HOST_DB_ADDR`
- api コンテナ名 (環境変数の取り込み元) と DB コンテナ名を控える

### Step 2: 固有値を集める

対象PJの Makefile / compose / DB 接続コードを読み、以下を確定する。ドキュメントを鵜呑みにせず実コードで確認する。

- `WORKDIR`: ツールを実行する作業ディレクトリ (repo root からの相対。モノレポなら `xxx-backend` 等)
- `API_CONTAINER` / `DB_CONTAINER`: `docker ps` の実名
- `HOST_DB_ADDR`: ホストから届く DB アドレス (例 `127.0.0.1:4306`)
- lint / di / gqlgen / mockgen / format 各コマンド (多くは本体 Makefile のターゲットに委譲できる)
- test の流れ: test DB のリセット方法 / マイグレーションコマンド / テストランナー
- go テストが DB 接続に使う環境変数名 (例 `ELEARNING_DB_HOST`)。ホスト到達先へ上書きする対象

補足: go-sql-driver は `mysql.Config.Addr` にポートを含められるので、接続コードが `Addr` に環境変数をそのまま入れているなら `ENV=127.0.0.1:4306` で足りる。マイグレーションツールの config がホスト:ポートを固定文字列で持つ場合は、ホスト向け config を別途用意する (下の実例参照)。

### Step 3: hostdev.conf を書く

repo root 直下に `hostdev.conf` を作る。source される shell なので、変数と `cmd_*` 関数を定義する。エンジンが提供するヘルパー `hd_import_container_env <container>` を test で使える。

契約:
- `WORKDIR` を設定 (未設定なら repo root)
- `cmd_<サブコマンド>()` を定義すると `hostdev <サブコマンド>` で呼ばれる。第1引数以降がそのまま渡る

### Step 4: git 管理外にする

tracked な `.gitignore` は触らず、共通 `.git/info/exclude` に登録する (worktree では info/exclude は共通 git ディレクトリにあり全 worktree で共有)。

```bash
common="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
grep -qxF '/hostdev.conf' "$common/info/exclude" || printf '/hostdev.conf\n' >> "$common/info/exclude"
git status --porcelain | grep -i hostdev && echo "NG: git に出ている" || echo "OK"
```

### Step 5: 検証する

小さいパッケージで lint と test を実際に流し、通ることを確認する。

```bash
hostdev lint <自己完結した小さいパッケージ>
hostdev test <DBのみに依存する repository/query 層の小さいパッケージ>
```

## 制約

- Redis クラスタ等、コンテナ間 DNS (`xxx_rediscluster` 等) に依存するテストはホストから名前解決できず対象外。DB のみに依存する repository/query 層向け。
- 環境変数の丸ごと取り込みでは、コンテナ側の `PATH` や `GOTOOLCHAIN=local` がホスト値を上書きすると docker/go が壊れる。エンジンの `hd_import_container_env` がホスト固有変数と Go ビルド変数を除外して対処済み。新たな除外が必要なら Step 2 で見極める。

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

## 共通エンジン (再インストール用)

`~/.local/bin/hostdev` が無い環境ではこれを設置する (PATH に `~/.local/bin` が必要)。

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
