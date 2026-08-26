---
name: aws-logs
description: awscli で CloudWatch Logs を調査し、結果を .specs/<feature>/log-report.md に記録する。AWS 上のエラー原因の追跡・ログ横断・件数集計を頼まれたら使う。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(aws logs *), Bash(aws sts get-caller-identity *), Bash(aws configure list-profiles), Bash(date *), Bash(grep *), Bash(rg *), Bash(jq *), Bash(wc *), Bash(head *), Bash(tail *), Bash(sort *), Bash(uniq *), Bash(mkdir *)
argument-hint: "<feature> [調べたいこと]"
---

# AWS ログ調査スキル

## 役割
awscli で **CloudWatch Logs** を調べ、所見を `.specs/<feature>/log-report.md` に記録する。

対象は CloudWatch Logs だけ（`filter-log-events` と Logs Insights）。ALB/S3 アクセスログ・CloudTrail・ECS のタスク状態は**この skill の範囲外**で、必要になったら人が別途調べる。

**コードは直さない** — 修正は `/fix`、症状からの原因特定は `/bughunt` に委ねる。ここは「ログに何が出ているか」を確定させる工程。

## 入出力
- **入力**:
  - 調べたいこと（症状・エラー文言・時間帯・リクエスト ID など。`$ARGUMENTS` または対話で受ける）
  - `.specs/<feature>/bug-report.md`（存在すれば。症状と時間帯の起点として読む）
  - `.specs/<feature>/log-report.md`（存在すれば。前回までの調査結果。追記ベースにする）
- **出力**: `.specs/<feature>/log-report.md`
- **生ログ**: セッションのスクラッチパッドに落とす。`.specs/` にも会話にも**貼らない**（量でコンテキストを潰すため）

## 前提（守る境界）

**プロファイルは人が指定する。skill は選ばない・切り替えない。**

| 事項 | 扱い |
|---|---|
| プロファイル | `$ARGUMENTS` の `--profile <名前>`、または環境変数 `AWS_PROFILE`。**どちらも無ければ止まって聞く**（勝手に `default` を使わない） |
| 本番（Prd） | **使わない**。プロファイル名に `prd` / `prod` を含む、または `sts get-caller-identity` の Account が本番アカウントなら**中断**して人に判断を返す |
| SSO 認証 | **人がやる**。skill は `aws sso login` を実行しない（ブラウザ対話が要るため）。失効を検知したらコマンドを提示して中断する |
| リージョン | プロファイルの設定に従う。skill から `--region` を足さない（必要なら人が引数で渡す） |
| コマンド | `aws logs` の読み取り系のみ。`put-*` / `delete-*` / `create-*` は使わない |

## 進め方

### Step 1: 引数チェック
- `$ARGUMENTS[0]`（feature）が未指定なら「使い方: /aws-logs \<feature\> [調べたいこと]」を表示して終了

### Step 2: プロファイルの確定（自分で選ばない）

引数の `--profile <名前>` → 環境変数 `AWS_PROFILE` の順に見る。どちらも無ければ `aws configure list-profiles` の結果を**番号付きで提示して止まる**：

```
どのプロファイルで調べますか？
1: <profile A>
2: <profile B>
...
```

**Prd 判定**: 選ばれた名前に `prd` / `prod`（大小問わず）が含まれるなら、ここで中断する：

```
本番プロファイルが指定されました: <name>
この skill は本番ログを調べません。stg 等のプロファイルを指定し直してください。
```

以降のすべての `aws` 実行に `--profile <確定した名前>` を付ける。**途中で別プロファイルに変えない**（変える必要が出たら止めて人に返す）。

### Step 3: 認証確認（失効なら中断）

```
aws sts get-caller-identity --profile <p> --no-cli-pager
```

- **成功** → 返ってきた `Account` を控える。本番アカウントだった場合は Step 2 の Prd 判定と同じく中断する（名前が実体とずれている可能性があるため、ここでも見る）
- **失効・未ログイン**（`SSO session ... expired` / `Token has expired` / `Unable to locate credentials`）→ **自分でログインしない**。次を提示して中断する：

```
認証が切れています。ログインしてから再実行してください:
  aws sso login --profile <p>
  復帰: /aws-logs <feature>
```

ユーザーはこのコマンドを `! aws sso login --profile <p>` の形でこのセッションから実行できる。

### Step 4: 調査対象の確定

**4-1 ロググループ**

指定が無ければ候補を絞って提示する（全件列挙はしない）：

```
aws logs describe-log-groups --log-group-name-prefix <あたり> \
  --query 'logGroups[].logGroupName' --output text --profile <p> --no-cli-pager
```

候補が複数あれば番号で選ばせる。1 つに定まるなら確認せず進む。

**4-2 時間窓**

窓を決めずに検索しない（全期間スキャンは遅く高くつく）。指定が無ければ**直近 1 時間**を既定にし、外れていたら広げる。

**ログは UTC、人が話す時刻は JST。** epoch へ変換して渡す（macOS の BSD date）：

```
date -v-1H +%s                                    # 1 時間前（秒）
date -j -f '%Y-%m-%d %H:%M:%S' '2026-07-30 10:00:00' +%s   # JST 指定 → 秒
```

**単位に注意（取り違えると空振りする）**：

| コマンド | `--start-time` / `--end-time` の単位 |
|---|---|
| `aws logs filter-log-events` | **ミリ秒**（秒 × 1000） |
| `aws logs start-query`（Insights） | **秒** |
| `aws logs tail` | `--since 1h` のような相対指定 |

### Step 5: 調査ループ

**広く浅く → 絞って深く**の順に進む。1 回で当てようとせず、空振りしたら窓かパターンを変えて回す。

**5-1 まず眺める（軽い）**

```
aws logs tail <group> --since 1h --format short --profile <p> | tail -100
```

`--follow` は**使わない**（ブロックする）。追尾が要るときだけ `run_in_background` で実行する。

**5-2 パターンで拾う（filter-log-events）**

```
aws logs filter-log-events --log-group-name <group> \
  --start-time <ms> --end-time <ms> \
  --filter-pattern '?ERROR ?Exception ?Traceback' \
  --max-items 100 --profile <p> --no-cli-pager \
  --query 'events[].[timestamp,message]' --output text
```

filter-pattern の要点：

- スペース区切り = **AND**、`?foo ?bar` = **OR**、`-foo` = 除外
- 大小を区別する（`ERROR` と `error` は別物。両方拾うなら `?ERROR ?error`）
- JSON ログなら `'{ $.level = "error" }'`、`'{ $.request_id = "abc123" }'` のようにフィールド指定できる
- 部分一致は `%正規表現%`（例: `'{ $.message = %timeout% }'`）

**5-3 集計・横断（Logs Insights）**

複数ロググループの横断、件数集計、上位抽出はこちら。**start-query → get-query-results のポーリング**が要る：

```
QID=$(aws logs start-query --log-group-names <group1> <group2> \
  --start-time <sec> --end-time <sec> \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50' \
  --query queryId --output text --profile <p> --no-cli-pager)

aws logs get-query-results --query-id "$QID" --profile <p> --no-cli-pager
```

`status` が `Running` の間は結果が空。**数秒おきに 2〜3 回まで取り直し**、`Complete` になってから読む。それでも `Running` なら窓を狭めて出し直す。

よく使うクエリ：

```
# エラーの種類別に件数を出す
fields @message | filter @message like /ERROR/ | stats count() by bin(5m)

# request_id で横断して時系列に並べる
fields @timestamp, @logStream, @message | filter @message like /<request_id>/ | sort @timestamp asc

# 遅いリクエスト上位
fields @timestamp, @duration | filter @duration > 1000 | sort @duration desc | limit 20
```

**5-4 深掘り**

当たりが付いたら、そのストリームの前後を読む：

```
aws logs get-log-events --log-group-name <group> --log-stream-name <stream> \
  --start-time <ms> --limit 200 --start-from-head --profile <p> --no-cli-pager
```

**出力量の扱い**: 100 行を超えそうなら**スクラッチパッドにファイルで落として `grep` / `rg` で絞る**。全文を会話に出さない。

### Step 6: 記録

`.specs/<feature>/log-report.md` に書き出す（既にあればマージ・追記）。

````markdown
# ログ調査: [対象]

## 調査条件
- プロファイル: <name>（Account: <id> / Region: <region>）
- ロググループ: <group>
- 期間: <JST 表記> （epoch: <from>–<to>）
- 検索: <filter-pattern または Insights クエリ>

## 所見
- [ログから読み取れた事実。推測と分けて書く]

## 該当ログ（抜粋）
```
<代表的な行を数行だけ。全文は貼らない>
```

## 読み取れなかったこと
- [ログに出ていないため確定できない点]

## 次に見るべきもの
- [別のロググループ・別の時間窓・アプリ側で追加すべきログ など]
````

**事実と推測を混ぜない。** ログに出ていない因果を所見に書かない（それは `/bughunt` の仕事）。

**何も見つからなかった場合**も、条件（窓・パターン・グループ）と「出なかった」ことを記録する。次の調査で同じ空振りを繰り返さないため。

### Step 7: 出力

完了カードの共通仕様（CLAUDE.md）に従う。見出しは `### ログ調査完了` /
中断時 `### ログ調査中断`。

```markdown
### ログ調査完了
<何を調べて何が分かったかを 1 行>
- <主要な結果 最大 3 行>

生成物: `.specs/\<feature\>/log-report.md`

### 要確認
- <ログからは確定できなかった点>

### 次の一手
- 原因を特定する: `/bughunt \<feature\>`
- 窓を変えて再調査: `/aws-logs \<feature\> [条件]`
```

**生ログは転記しない**（レポートに書く）。要確認はログに出ておらず確定できなかった点、
空振りした条件。次の一手は調査で終わりなら `/bughunt` 行を省いてよい。

**中断時**: 一言サマリに中断理由（認証切れ・Prd 指定・プロファイル未確定）、次の一手に復帰コマンドを書く。

## エラー処理
- **認証切れ** → Step 3 のとおり `aws sso login` を提示して中断。**自分で実行しない**
- **Prd が指定された** → 中断。read-only ロールでも例外にしない
- **`ResourceNotFoundException`** → ロググループ名の綴り違い。`describe-log-groups --log-group-name-prefix` で存在確認してから再試行する
- **結果が空** → 窓・パターン・大小文字・ロググループの順に疑う。3 回変えても空なら「出なかった」を所見として記録して終える（無限に試さない）
- **`ThrottlingException` / クエリが遅い** → 期間を短く割って回す。並列に投げない
- **ページャで止まる** → すべての `aws` に `--no-cli-pager` を付ける（付け忘れが原因）

## 完了条件
指定された条件で CloudWatch Logs を検索し、**所見（見つかった／見つからなかった）を `.specs/<feature>/log-report.md` に記録したら完了**。原因の確定は完了条件に含めない（それは `/bughunt`・`/fix`）。
