---
name: aws-logs
description: awscli で CloudWatch Logs を調査し、結果を .specs/<feature>/log-report.md に記録する。AWS 上のエラー原因の追跡・ログ横断・件数集計を頼まれたら使う。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Bash(aws logs describe-log-groups *), Bash(aws logs describe-log-streams *), Bash(aws logs tail *), Bash(aws logs filter-log-events *), Bash(aws logs get-log-events *), Bash(aws logs start-query *), Bash(aws logs get-query-results *), Bash(aws sts get-caller-identity *), Bash(aws configure list-profiles), Bash(date *), Bash(grep *), Bash(rg *), Bash(jq *), Bash(wc *), Bash(head *), Bash(tail *), Bash(sort *), Bash(uniq *), Bash(mkdir *)
argument-hint: "<feature> [調べたいこと]"
---

# AWS ログ調査スキル

## 役割
awscli で CloudWatch Logs を調べ、「ログに何が出ているか」を `.specs/<feature>/log-report.md` に記録する。
対象は `filter-log-events` と Logs Insights だけで、ALB/S3 アクセスログ・CloudTrail・ECS のタスク状態は範囲外。
コードは直さず、ログに出ていない因果も書かない。原因の確定は別工程が担う。

## 判断が割れる点の扱い
プロファイルとロググループは候補を番号付きで提示して人に選ばせ、1 つに定まるときだけ確認せず進む。
それ以外は自分で決めて進め、ログから確定できなかった点は完了カードの要確認に出す。

## 守る境界

| 事項 | 扱い |
|---|---|
| プロファイル | `$ARGUMENTS` の `--profile <名前>`、無ければ環境変数 `AWS_PROFILE`。どちらも無ければ止まって聞き、勝手に `default` を使わない。途中で別プロファイルに変えない |
| 本番 | 使わない。プロファイル名に `prd` / `prod` を含む、または `sts get-caller-identity` の Account が本番アカウントなら中断して人に返す。read-only ロールでも例外にしない |
| SSO 認証 | 人がやる。ブラウザ対話が要るので `aws sso login` を実行せず、失効を検知したらコマンドを提示して中断する |
| リージョン | プロファイルの設定に従い、`--region` を足さない。必要なら人が引数で渡す |
| コマンド | `aws logs` の読み取り系のみ。すべての `aws` に `--no-cli-pager` を付ける |
| 生ログ | 100 行を超えそうならスクラッチパッドにファイルで落として `grep` / `rg` で絞る。`.specs/` にも会話にも全文を貼らない |

## log-report.md のフォーマット

既にあればマージ・追記する。
所見は事実だけを書き、推測と分ける。
何も見つからなかったときも、窓・パターン・グループの条件と「出なかった」ことを記録し、次の調査で同じ空振りを繰り返さないようにする。

````markdown
# ログ調査: [対象]

## 調査条件
- プロファイル: [name]。Account: [id]、Region: [region]
- ロググループ: [group]
- 期間: [JST 表記]。epoch: [from]–[to]
- 検索: [filter-pattern または Insights クエリ]

## 所見
- [ログから読み取れた事実]

## 該当ログ、抜粋
```
[代表的な行を数行だけ]
```

## 読み取れなかったこと
- [ログに出ていないため確定できない点]

## 次に見るべきもの
- [別のロググループ・別の時間窓・アプリ側で追加すべきログ]
````

## 進め方

### Step 1: 入力の確認

- `$ARGUMENTS[0]` が無ければ「使い方: /aws-logs <feature> [調べたいこと]」を表示して終了
- 調べたいことは `$ARGUMENTS` の残りか対話で受ける。症状・エラー文言・時間帯・リクエスト ID
- `.specs/<feature>/bug-report.md` があれば症状と時間帯の起点として読む

### Step 2: プロファイルの確定

引数の `--profile <名前>`、環境変数 `AWS_PROFILE` の順に見る。
どちらも無ければ `aws configure list-profiles` の結果を番号付きで提示して止まる。
名前に `prd` / `prod` が大小問わず含まれるなら、本番は調べない旨と stg 等を指定し直す旨を伝えて Step 11 の中断カードで終了する。
以降のすべての `aws` に `--profile <確定した名前>` を付ける。

### Step 3: 認証確認

```
aws sts get-caller-identity --profile <p> --no-cli-pager
```

- 成功 → `Account` を控える。本番アカウントなら Step 2 と同じく中断する。名前が実体とずれている可能性があるためここでも見る
- `SSO session ... expired` / `Token has expired` / `Unable to locate credentials` → 次を提示して Step 11 の中断カードで終了する

```
認証が切れています。ログインしてから再実行してください:
  aws sso login --profile <p>
  復帰: /aws-logs <feature>
```

### Step 4: ロググループの確定

指定が無ければ prefix で候補を絞って提示し、全件列挙はしない。

```
aws logs describe-log-groups --log-group-name-prefix <あたり> \
  --query 'logGroups[].logGroupName' --output text --profile <p> --no-cli-pager
```

`ResourceNotFoundException` が出たら綴り違いなので、このコマンドで存在確認してから再試行する。

### Step 5: 時間窓の確定

窓を決めずに検索しない。全期間スキャンは遅く高くつく。
指定が無ければ直近 1 時間を既定にし、外れていたら広げる。
ログは UTC、人が話す時刻は JST なので、macOS の BSD date で epoch に変換して渡す。

```
date -v-1H +%s
date -j -f '%Y-%m-%d %H:%M:%S' '2026-07-30 10:00:00' +%s
```

| コマンド | `--start-time` / `--end-time` の単位 |
|---|---|
| `aws logs filter-log-events` | ミリ秒。秒 × 1000 |
| `aws logs start-query` | 秒 |
| `aws logs tail` | `--since 1h` のような相対指定 |

### Step 6: まず眺める

```
aws logs tail <group> --since 1h --format short --profile <p> | tail -100
```

`--follow` はブロックするので使わず、追尾が要るときだけ `run_in_background` で実行する。

### Step 7: パターンで拾う

```
aws logs filter-log-events --log-group-name <group> \
  --start-time <ms> --end-time <ms> \
  --filter-pattern '?ERROR ?Exception ?Traceback' \
  --max-items 100 --profile <p> --no-cli-pager \
  --query 'events[].[timestamp,message]' --output text
```

- スペース区切りは AND、`?foo ?bar` は OR、`-foo` は除外
- 大小を区別するので、両方拾うなら `?ERROR ?error`
- JSON ログは `'{ $.level = "error" }'` のようにフィールド指定できる
- 部分一致は `%正規表現%` で書く

### Step 8: 集計・横断で絞る

複数ロググループの横断、件数集計、上位抽出は Insights を使う。

```
QID=$(aws logs start-query --log-group-names <group1> <group2> \
  --start-time <sec> --end-time <sec> \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50' \
  --query queryId --output text --profile <p> --no-cli-pager)

aws logs get-query-results --query-id "$QID" --profile <p> --no-cli-pager
```

`status` が `Running` の間は結果が空なので、数秒おきに 2〜3 回まで取り直し、`Complete` になってから読む。
それでも `Running`、または `ThrottlingException` なら窓を狭めて出し直し、並列には投げない。

```
fields @message | filter @message like /ERROR/ | stats count() by bin(5m)
fields @timestamp, @logStream, @message | filter @message like /<request_id>/ | sort @timestamp asc
fields @timestamp, @duration | filter @duration > 1000 | sort @duration desc | limit 20
```

### Step 9: 深掘り

当たりが付いたら、そのストリームの前後を読む。

```
aws logs get-log-events --log-group-name <group> --log-stream-name <stream> \
  --start-time <ms> --limit 200 --start-from-head --profile <p> --no-cli-pager
```

Step 6〜9 は広く浅くから絞って深くの順に進み、空振りしたら窓・パターン・大小文字・ロググループの順に疑って回す。
3 回変えても空なら「出なかった」を所見として記録して終える。

### Step 10: 記録

「log-report.md のフォーマット」で `.specs/<feature>/log-report.md` に書き出す。

### Step 11: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### ログ調査中断` にし、1 行目に中断理由を書き、生成物の行を省き、次の一手は復帰コマンドにする。

```markdown
### ログ調査完了
<何を調べて何が分かったかを 1 行>

生成物: `.specs/<feature>/log-report.md`

### 要確認
- <ログからは確定できなかった点・空振りした条件>

### 次の一手
- 原因を特定する: `/bughunt <feature>`
- 窓を変えて再調査: `/aws-logs <feature> [条件]`
```

要確認は無ければブロックごと省略する。
