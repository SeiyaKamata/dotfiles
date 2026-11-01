---
name: pr-response
description: Draft の PR を「人間レビューに出せる状態」まで仕上げる手順書。ラベルを 1 つに絞る・担当者を付ける・CodeRabbit にレビューを依頼する・指摘に対応する往復を Draft のまま回し、CI が緑かつ指摘が 0 件になったら最後に Ready For Review へ昇格させる。「PR を仕上げて」「レビュー指摘に対応して」「Ready に上げて」「CodeRabbit の指摘を潰して」「PR のラベルと担当者を整えて」のような依頼で発火するほか、`dispatch` の `ship` モード工程 7 と、PR の仕上げ操作を生の gh で組み立てようとしたときに差し戻すフック (`hooks/pr-response-gate.py`) から呼ばれる。**PR が立ったあとの仕上げを自分で組み立てず、必ずここを開くこと。**
---

# pr-response — PR を人間レビューに出せる状態まで仕上げる

Draft の PR を「人間レビューに出せる状態」まで持っていく。ラベル付与・担当者指定・CodeRabbit へのレビュー依頼・指摘対応を Draft のまま回し、CI が緑かつ CodeRabbit の指摘が 0 件になったら最後に Ready For Review へ昇格させる。

## いちばん大事な考え方 (順序の意図)

Ready For Review は「人間さん、レビューお願いします」の合図。だから **最後** に出す。それまでは Draft のまま CodeRabbit と往復してコードをきれいにする。人間の時間を使う前に、機械 (CI / CodeRabbit) が満足する状態を先に作るための順序。

```text
Draft のまま:  ①最適ラベル1つ → ②担当者 → ③CodeRabbit にレビュー依頼 → ④指摘対応(往復)
                                                                        ↓
                        CI 緑 + CodeRabbit 指摘0件 を確認 → ⑤Ready For Review へ昇格
```

迷ったら (設計判断・仕様に関わる指摘・対応方針が定まらない等) `slack-to-shogun` スキルでユーザーに連絡する。会話画面を見ているとは限らないので、節目は Slack に流す。

### この拡張の外にあるものへの参照

本文の中で次の名前を挙げている。**入っていない環境では、手元にある同等の手段に読み替える** (どれも無くてもこの手順は完走できる)。

| 名前 | 何をするもの | 無いときどうするか |
| --- | --- | --- |
| `slack-to-shogun` | 節目を Slack の報告スレッドへ投下する (拡張 `slack-notify`) | 会話の中でユーザーに伝える |
| `/recipient-centric:commit` | 受け取る側が読める形にコミットを刻む (拡張 `recipient-centric`) | そのリポジトリのコミット規約に従う |
| `break-loop` | 待ち時間を挟んで自分を起こし直す | バックグラウンドのポーリングに載せる |

## 手順

### 0. PR を特定し、通知の宛先を確定する

**最初に宛先を変数に置く。この 3 つは以降のすべての手順で使う。**

```bash
OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"
gh pr view "$PR" --repo "$OWNER/$REPO" --json number,url,title,headRefName,isDraft,labels,assignees,reviewRequests
gh pr checks "$PR" --repo "$OWNER/$REPO"
```

**以降のコマンド例は `--repo` を省いて短く書いてあるが、省いてよいのは cwd が対象リポの clone の中にあるときだけ。** それ以外では、`gh pr` 系のすべて (`view` / `checks` / `edit` / `comment` / `ready`、および HEAD の取得) に `--repo "$OWNER/$REPO"` を付ける。cwd を取り違えると、**同じ番号の別リポの PR を読む・書き換える**。ラベルだけの話ではなく、担当者の付け替えも Ready 昇格も同じ経路で起きる。

`gh api` には `--repo` を足さない (足すと逆に壊れる)。代わりに、**宛先を URL の中に書く**。`gh api repos/{owner}/{repo}/...` の `{owner}` / `{repo}` は `gh` が cwd から補う穴で、`--repo` を省いたときと同じ取り違えが起きる。以降の REST の例は `repos/$OWNER/$REPO/...` と書いてあり、変数は**その例のブロックの中で置き直している** (シェルの変数は次のコマンド実行には残らないため。理由は次の節)。GraphQL の例は宛先を `-F o=... -F r=...` で渡しているので、そのままでよい。

PR が見つからない場合はユーザーに番号 / URL を確認する。以降の Slack 通知には、どの PR の話かを示すリンク (Slack mrkdwn) を `--topic` で渡す。形はこれひとつ:

```text
<https://github.com/<owner>/<repo>/pull/<PR番号>|<repo> / PR#<PR番号>>
```

**変数に入れて後の手順まで持ち回らない。使う場所で、その呼び出しの中で書く。** シェルの変数は 1 回のコマンド実行の中だけの存在で、**次にコマンドを打つときには消えている** (手元で確認するなら、1 回目で `export X=abc`、2 回目で `echo "[$X]"` を別々に打つと `[]` が返る)。手順 0 で組み立てて手順 4 や手順 6 で参照する書き方だと、そこでは空文字に展開され、`<| / PR#>` という宛先も表示名も無い文字列が Slack に並ぶ。

**空でも `notify.sh` は成功を返す**ので、打った本人は成功したと見え、受け取った側だけが「どの PR の話か」を失う。同じ理由で、URL と番号を `gh pr view` の出力から別の名前 (`PR_URL` など) に入れ直すこともしない — 代入の書き忘れが同じ空リンクになる。上の `<owner>` / `<repo>` / `<PR番号>` を手順 0 で確定させ、通知のたびにその 3 つを当てはめて書けば、間に持ち回るものが無くなる。

ファイルに書き出して持ち回る案は採らない。複数のセッションが同じ PR とは限らないので、固定のパスに置くと**別の走行の宛先を上書きする** (シェルの変数は他のセッションへ漏れないので、こちらを避ければ取り違えは起きない)。

### 1. ラベルを最適なもの一つだけにする

PR の性格に最も合うラベルを 1 つだけ残す。複数付いていたら余分を外す。

```bash
gh label list --repo "<owner>/<repo>"            # そのリポで使えるラベル一覧
gh pr edit "<PR番号>" --add-label "<最適な1つ>"
gh pr edit "<PR番号>" --remove-label "<余分なもの>"
```

選び方の目安 (リポにあるラベル名は揺れるので一覧で実名を確認してから決める):

| PR の中身 | 典型ラベル |
| --- | --- |
| 新機能・新しい振る舞いの追加 | `new-feature` / `feature` |
| 既存バグの修正 | `bug-fix` / `bug` |
| 脆弱性そのものへの対応 | `security` |
| リファクタ・雑務・設定変更 | `chore` / `refactor` |

**複数の性格を併せ持つ PR** (例: 新機能だが既存バグも直す) は、優先順位 `security` > `bug-fix` > `new-feature` > `chore` で 1 つ選ぶ。最もリスク・注意を要する性格を代表させる、という考え方 (脆弱性を含むなら何より先に `security`)。

**1 つに絞る理由**: 「この PR は何の PR か」を一目で言えるようにするため。例えば新機能 PR に `security` が同居していると、脆弱性対応 PR だと誤読される。`security` は「脆弱性そのものを塞ぐ PR」にだけ付ける。

### 2. 担当者を指定する

```bash
gh pr edit "<PR番号>" --add-assignee @me
```

`@me` は `gh` が実行者のアカウントに解決する。**特定のアカウント名を書かない** — この手順書は他の人の手元でも走る。別の人を担当にする明示指示があるときだけ、その名前を書く。

### 3. CodeRabbit にレビューを依頼する (Draft のまま)

PR へのコメントで明示的に依頼する。本文は `@coderabbitai review` の 1 行。

**なぜ明示依頼するのか**: CodeRabbit は Draft PR を自動レビューしない設定のことが多い。この手順では Ready 化を最後まで遅らせるので、自動トリガーに頼れない。だから自分から起こす。

**増分レビューの落とし穴**: CodeRabbit はコミット SHA に紐づく増分レビューで、同じコミットは再レビューしない。古いレビューを見て「0 件」と判断すると、その後 push したコミットを見落とす。必ず **現 HEAD に対する** レビューかを確認する (手順4)。さらに **`@coderabbitai review` はそのコミットの diff 範囲しか見ない** ため、大量ファイルを一括追加した PR では大半のファイルが評価されないまま「0 件」に見える。この落とし穴と対策 (`@coderabbitai full review`) は 4-1c、指摘の 2 系統 (inline / body fold) は 4-1b を参照。

### 4. レビューを待ち、指摘に対応する

**4-0. 待ちの順番 — 今を 1 度見る → ① CI の収束 → ② CodeRabbit の結論**

待ちに入る前に、自分にこう聞く。

> **待ちに入る前に現状を 1 度見たか? 待つ条件に、失敗で抜ける条件と上限が入っているか? CI 収束 → CodeRabbit の結論の順で見たか? 監視が動いていることを起動直後に確かめたか?**

1. **まず今を 1 度見る。** 依頼や push から時間が経っていれば、もう結果が出ていることがある。出ていれば待たずに先へ進む。
2. **① CI の収束を待つ。** 抜けるのは「まだ走っている check が 0 になった」か「失敗が 1 件でも出た」のどちらか。失敗を見たらその時点で抜けて 4-5 で直す (直して push すれば HEAD が変わり、CodeRabbit のレビューもどのみちやり直しになるので、その結論を待つ理由はもう無い)。**回数か時間の上限を必ず入れる。**
3. **② CI が収束してから CodeRabbit の結論を見る。** 見るのは 4 点: サマリーコメントのレビュー対象コミットが現 HEAD と一致しているか (4-1 の完了シグナル 3) / `No actionable comments` か / 未解決スレッドが 0 か (手順 5 の条件 2) / 折りたたみ (4-1b)。
4. **監視を起動した直後に、動いている証拠を見る。** バックグラウンドの監視は、起動に失敗してもすぐ終わるだけで何も言わない。起動直後に最初の出力か終了コードを見て、待ちが本当に回っていることを確かめる。

① は `gh pr checks` の終了コードで抜けられる (`0` = 全部通った / `8` = まだ走っている / それ以外 = 失敗あり、または取得に失敗)。macOS には `timeout` コマンドが無い (打つと `command not found` の終了コード 127 で即座に終わる) ので、上限は回数で持つ。

```bash
OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
for i in $(seq 1 40); do                          # 30 秒 × 40 回 = 20 分で打ち切る
  gh pr checks "$PR" --repo "$OWNER/$REPO" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 8 ] && break
  sleep 30
done
echo "rc=$rc round=$i"                            # rc=8 のまま抜けたら上限切れ。slack-to-shogun で報告する
```

CodeRabbit が commit status として出るリポジトリでは、この `gh pr checks` に `CodeRabbit ... Review completed` の行も並ぶので、① が抜けた時点で ② の最初の確認 (レビューが終わったか) も同時に見えている。

CodeRabbit のレビューは数分〜十数分かかることがある。バックグラウンドでポーリングしながら待つ。**無言で待ち続けない**: 目安 15 分を超えても現 HEAD のレビューが返らない、または bot が無応答なら、`@coderabbitai review` を最大 2 回まで打ち直す。それでも返らなければ `slack-to-shogun` で状況を報告して判断を仰ぐ (外部 bot 待ちは止まることがあるので、必ず打ち切り条件を持つ)。**ただしレート制限 (`Review limit reached`) が確認できたときは、この打ち切りではなく下の督促ループに倒す** (時間が経てば必ず解ける待ちなので、打ち切る理由がない)。

> [!IMPORTANT]
> **レート制限 (`Review limit reached`) に当たっても飛ばさない。潰し切ってから先へ進む** (2026-08-27 ユーザー確定・恒久ルール。2026-07-19 の「待たずに飛ばす」はこれに置き換わった)。
>
> サマリーコメント本文に `## Review limit reached` (Fair Usage Limits Policy。"Next review available in: N minutes" が併記される) が出ていたら、それはレビューが **まだ走っていない** サイン。この PR を「レビュー済み」扱いにも「先送り」にもしない。現 HEAD のレビューが返るまで、次の督促ループを回す。
>
> 1. **15 分おきに `slack-to-shogun` で 1 通投下する**。投下する本文には **PR の URL** と **`@coderabbitai review`** を必ず入れる。**これは「ユーザーに GitHub へ投稿してもらう依頼」** なので、URL とコマンドは加工せずそのまま貼る (Slack からコピーしてそのまま PR のコメント欄に貼れる形にする)。
>
>    ```text
>    本文: 🙏 CodeRabbit がレート制限中です。下の PR に `@coderabbitai review` を投稿してください (N 回目 / 15 分おきに再送します)
>          https://github.com/<owner>/<repo>/pull/<PR番号>
>          @coderabbitai review
>    引数: --header "🙏 PR#<番号> / @coderabbitai review を投稿してほしい" --color "#F2803C" --topic "<https://github.com/<owner>/<repo>/pull/<PR番号>|<repo> / PR#<PR番号>>"
>    ```
>
> 2. **自分から打ち直さない**。レート制限中の再投稿は空振りする。**投稿はユーザーの手に渡し、こちらは通知を出し続ける役に徹する**。
> 3. **待ち時間は自分のセッションで持つ**。前面で `sleep` して固まらず、15 分後に自分を起こす仕掛け (`break-loop` のような one-shot の目覚まし) か、バックグラウンド監視に載せる。次の発火で 4-1 の完了シグナル (OR) を見る。
> 4. **完了シグナルが立ったらループを止め**、手順4 の残り (指摘対応) へ戻る。`Review limit reached` が消えないうちは 1 に戻る。
>
> **打ち切って飛ばすことはしない。** 制限が長引いても既定は「通知を出し続ける」。ただし通知が 8 回 (目安 2 時間) を超えたら、その回の通知に「長期化している」と明記して判断を仰ぐ。仰いだあとも、ユーザーが明示的に先送りを指示するまでは ⑤Ready 昇格も完了報告もしない (レビュー未完で手順5 の 3 条件は満たしようがない)。

**4-1. レビューが「完了」したかを機械的に判定する (特定文字列に賭けない)**

ここが最大の落とし穴。完了判定を「`No actionable comments ... 🎉` が出たか」のような **特定文字列の有無に賭けると取りこぼす**。CodeRabbit の出力フォーマットはレビュープロファイル (CHILL かどうか) やレート制限の状態で変わり、🎉 が出ないまま完了することがある (トップレベルの review オブジェクトを作らず、サマリーコメントをその場で書き換えて進める挙動など)。`gh pr view --json reviews` の coderabbit エントリが空のまま完了することもある。

完了は **状態遷移シグナルの OR** で判定する (どれか 1 つ立てば「完了 → 結論を読みに行く」)。

1. **CodeRabbit の GitHub check-run が `completed` に遷移** (最も堅い一次シグナル):

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   HEAD=$(gh pr view "$PR" --repo "$OWNER/$REPO" --json headRefOid --jq '.headRefOid')
   gh api repos/$OWNER/$REPO/commits/$HEAD/check-runs \
     --jq '.check_runs[] | select(.name|test("CodeRabbit";"i")) | {status, conclusion}'
   ```

   **リポジトリによっては check-run ではなく commit status として出る。** そのときは上のコマンドは 0 件を返し続けるので、check-run の完了を待つ条件はいつまでも成り立たない。両方の形を 1 回で拾えるのは `statusCheckRollup` (check-run は `name` / `status` / `conclusion`、commit status は `context` / `state` に入る):

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   gh pr view "$PR" --repo "$OWNER/$REPO" --json statusCheckRollup \
     --jq '.statusCheckRollup[] | select((.name // .context) | test("CodeRabbit";"i"))
           | {type: .__typename, status, conclusion, state}'
   ```

2. **インラインのレビュースレッド件数が前進した** (`pulls/{pr}/comments` の coderabbit[bot])。依頼前にスナップショットを取り、増えたら完了の有力サイン:

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   gh api --paginate --slurp repos/$OWNER/$REPO/pulls/$PR/comments \
     --jq 'add | [.[] | select(.user.login=="coderabbitai[bot]")] | length'
   ```

3. **サマリーコメント (issue-comment。同じ id がその場で書き換えられる) から処理中の目印が消えた**: body が `Currently processing` (review in progress) も `Review limit reached` も含まず、`## Walkthrough` または結論の行を含み、`updated_at` が依頼時刻より新しい。さらに body 内 "Commits between … and `<sha>`" の `<sha>` が現 HEAD を含むことを照合:

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   gh api --paginate --slurp repos/$OWNER/$REPO/issues/$PR/comments \
     --jq 'add | [.[] | select(.user.login=="coderabbitai[bot]")] | sort_by(.updated_at) | last | {updated_at, body}'
   ```

**「処理中の目印も結論の文字列も無い」状況を待機継続の条件にしてはいけない** (これが素通りしたまま永久に待つ正体)。上の OR が立たないまま目安 15 分を超えたら、手順4冒頭の打ち切り (再依頼最大 2 回 → `slack-to-shogun`) に倒す。ポーリングは必ず「**完了シグナル(OR) + 時間上限 + リトライ回数 + エスカレーション先**」の 4 点を備える。

bot のログイン名はツールによって表記が違うので注意。

- `gh pr view --json reviews` / GraphQL 経由 → `.author.login == "coderabbitai"`
- REST API (`gh api .../comments`) 経由 → `.user.login == "coderabbitai[bot]"`

`reviews[]` でトップレベルのレビューが取れるならそれも完了シグナルの 1 つ (`submittedAt!=null`、本文の "Commits between X and `<HEAD>`" が現 HEAD を含むか照合)。だが **取れないことを「未完了」の根拠にしない**。古い SHA 止まりのレビューしか無いなら `@coderabbitai review` を打ち直して現 HEAD のレビューを促す。

**4-1b. CodeRabbit の指摘は「2 系統」ある — `reviewThread` だけ見ると片方を丸ごと取りこぼす**

CodeRabbit の指摘は置き場所が 2 つあり、**別々に確認しないと片方を見落とす**。

1. **inline レビュースレッド (reviewThread)**: コードの特定行に紐づく指摘。`isResolved` で機械判定でき、手順5の GraphQL で数えられる。**actionable comments はここに来る**。
2. **レビュー本文の折りたたみ (body fold)**: review オブジェクトの `body` の中に `⚠️ Outside diff range comments (N)` / `🧹 Nitpick comments (N)` / `🟡 Minor comments (N)` として畳まれる指摘。**reviewThread には出ない** ので、手順5の未解決カウントには一切数えられない。Major 級の指摘がここに入ることもある (指摘行が diff の範囲外だと inline スレッドにできず body に回るため)。

つまり **「未解決 reviewThread 0 件 = クリーン」ではない**。body fold 側に未対応の指摘が残っていても reviewThread は 0 のままになる (実際にこれで 2 回クリーンを誤判定した)。body fold は各 review の `body` から機械抽出する。

```bash
OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"
HEAD=$(gh pr view "$PR" --repo "$OWNER/$REPO" --json headRefOid --jq '.headRefOid')

CURSOR=null; FOUND=""
while : ; do                                             # 新しい側から 20 件ずつ、見つかるまで遡る
  PAGE=$(gh api graphql -f query='
    query($o:String!,$r:String!,$n:Int!,$c:String){repository(owner:$o,name:$r){
      pullRequest(number:$n){reviews(last:20, before:$c){
        pageInfo{hasPreviousPage startCursor}
        nodes{databaseId author{login} commit{oid} body}}}}}' \
    -F o="$OWNER" -F r="$REPO" -F n="$PR" -F c="$CURSOR")

  HIT=$(jq -r --arg h "$HEAD" '[.data.repository.pullRequest.reviews.nodes[]
        | select(.author.login|test("coderabbit";"i"))
        | select(.commit.oid == $h)                      # 現 HEAD に付いた review だけ
        | select(.body | length > 0)]                    # 本文が空の受領スタブを捨てる
      | sort_by(.databaseId) | last                      # そのうち最新の 1 本だけ
      | if . == null then "" else
        "REVIEW \(.databaseId) commit=\(.commit.oid[0:10]): " +
        (.body | [scan("Outside diff range comments \\(([0-9]+)\\)"),
                  scan("Nitpick comments \\(([0-9]+)\\)"),
                  scan("Minor comments \\(([0-9]+)\\)"),
                  scan("Actionable comments posted: ([0-9]+)")] | flatten | @json) end' <<<"$PAGE")

  [ -n "$HIT" ] && { FOUND="$HIT"; break; }
  [ "$(jq -r '.data.repository.pullRequest.reviews.pageInfo.hasPreviousPage' <<<"$PAGE")" = "true" ] || break
  CURSOR=$(jq -r '.data.repository.pullRequest.reviews.pageInfo.startCursor' <<<"$PAGE")
done
echo "${FOUND:-現 HEAD への review はまだ無い (未レビュー)}"
```

**この 4 つを外さない。外すと判定が静かに壊れる。**

| 書き方 | 外すと何が起きるか |
| --- | --- |
| `commit.oid` が現 HEAD と一致するものだけに絞る | 過去 HEAD の折りたたみを数えて、直したのに終われなくなる |
| **本文が空の review を捨てる** (`.body \| length > 0`) | `@coderabbitai review` / `resolve` を打つたびに**本文が空の受領 review が現 HEAD に積まれる**。数える語が 1 つも無いので折りたたみが `[]` で返り、**レビュー前なのに「指摘 0 件」に見える** |
| そのうち **最新の 1 本** だけを見る | 同じ HEAD に複数の review が付く (再依頼・full review) ので、古いほうを読んで解消済みの指摘を数える |
| **新しい側から取り、見つかるまで `before` で遡る** | 1 ページ (20 件) だけ見て打ち切ると、往復の多い PR で現 HEAD の review が取得する範囲から落ちる。**実在するのに「未レビュー」と判定され、Ready 判定がそこから進まなくなる** |

遡りに件数の上限は置かない。`pageInfo.hasPreviousPage` が `false` になるまで遡り、そこで初めて未レビューと判定する。**「上限に達した」と「本当に review が無い」は区別できない**ので、上限で打ち切ると実在する review を見落とし、そのまま Ready 判定が止まる。往復の多い PR では review が 100 件を超えることがあるため、打ち切る位置を件数ではなくページの尽きるところに置く。抜けたときは未レビューとして 4-1 の完了判定に戻る (Ready には進まない)。

**「取れなかった」も「空だった」も、指摘 0 件ではない。** どちらも未レビューとして 4-1 の完了判定に戻る。空の受領 review は実際に出る — レート制限中に `@coderabbitai review` を打つと、本文の無い review が現 HEAD に付き、サマリーコメント側にだけ `Review limit reached` が出る (2026-09-14 に本 PR で実測。空の review が 3 本積まれていた)。**折りたたみの数だけを見て 0 件と判定せず、必ずサマリーコメントを時刻順に全部読んで `Review limit reached` と `Currently processing` が消えているかを確かめる** (4-1 の完了シグナル 3)。

**body fold は「撤回されない」**: 該当箇所を直しても、過去の review の body に書かれた折りたたみのテキストはそのまま残る (歴史的な記録)。だから「折りたたみが消えたか」では解消を判定できない。解消は **直した上で、現 HEAD に対する新しい review の body に折りたたみが出ないこと** で判定する (下記 full review)。

**4-1c. 増分レビュー vs full review — 大量ファイル追加 PR の盲点**

CodeRabbit は SHA に紐づく **増分レビュー** で、push ごとの自動レビューも手動の `@coderabbitai review` も **そのコミットの diff 範囲しか見ない**。

- **手動の `@coderabbitai review` は、自動レビュー ON の PR では何もしないことがある**: 「already reviewed / This command is applicable only when automatic reviews are paused」と返り、新しい指摘を出さない (push 時点で自動レビュー済みのため)。
- **200+ ファイルを一括追加するような PR では、大半のファイルが「初回コミットの diff 範囲外」に落ちる**。増分レビューを何度回しても指摘は部分的にしか出ず、reviewThread 0・body fold 0 に見えても、全ファイルはまだ評価されていない。
- **全ファイルを再評価させるには `@coderabbitai full review` を打つ**。これは diff 範囲ではなく PR の全ファイルを見直すので、増分では埋もれていた指摘 (多くは body fold) が初めて表に出る。

**full review の完了判定**: full review も「新規指摘ゼロなら新しい review オブジェクトを作らない」ことがある (増分と同じ)。完了は「現 HEAD に対する新しい review が出た (折りたたみは 4-1b で確認)」「CodeRabbit が対応を是認する issue-comment を出した」「サマリーの処理中の目印が消えた」の OR で見る。バックグラウンド監視は **「新しい review の `databaseId` が、依頼前に記録した基準値を超え、かつ `commit.oid` が現 HEAD と一致して出る」** を主シグナルにすると、処理中の目印が立って消えるのをポーリングの隙間で見逃す取りこぼしを避けられる。

**4-2. 指摘を 3 つに分類して対応する**

レビュー指摘は必ずしも正しくない。指摘箇所の実装意図・周辺コード (呼び出し元 / 先 / テスト) を読んでから判断する。

| 分類 | 意味 | 対応 |
| --- | --- | --- |
| **対応する** | 指摘が正しく修正が必要 | コード修正 → `/recipient-centric:commit` でコミット |
| **対応しない** | 指摘が誤り or 既に考慮済み | コードの根拠を示して返信 → **スレッドを解決させる** (下記) |
| **判断保留** | 自信がない・トレードオフがある | `slack-to-shogun` でユーザーに相談 |

**「対応しない」と決めた actionable は、返信だけだとスレッドが開いたまま残る**。手順5の Ready ゲートは「未解決の reviewThread 0 件」なので、開いたままの指摘があると 0 件に到達できない穴がある。これを塞ぐため、対応しない指摘は返信に続けてスレッドを解決させる。

**`@coderabbitai resolve` はスレッドへの返信に書いても効かない。PR 全体へのコメントとして投稿する。** スレッド返信に書くと CodeRabbit が「`@coderabbitai resolve` または `@coderabbitai approve` を新しい PR コメントとして投稿してください」と返し、**その返信自体がスレッドに 1 件積まれるので未解決のまま増える** (2026-08-12 に実測。返信に書いた回は `未解決=1` のまま、PR 全体へのコメントとして投げ直したら `未解決=0` になった)。

手順は 2 つ。

1. 該当スレッドへ、対応しない理由を返信する。本文はファイルに書いて `-F body=@<ファイル>` で渡す (改行と記号がそのまま届く)

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   gh api "repos/$OWNER/$REPO/pulls/$PR/comments/<コメント id>/replies" -F "body=@<本文のファイル>"
   ```

2. 解決の依頼は **PR 全体へのコメント** として別に投げる (GitHub の画面でいう Resolve conversation 相当)。本文は `@coderabbitai resolve` の 1 行

`resolve` は PR 内の未解決スレッドをまとめて畳むので、**1 本ずつ投げる必要はない** (返信を全部済ませてから最後に 1 回でよい)。

返信と解決のあとは、**未解決の reviewThread が 0 件になったか** を手順5の GraphQL で機械確認する (🎉 の有無ではなく `isResolved` で判定する)。**0 件に到達できない (誤検知を承知で残すしかない) 場合は、Ready を強行せず `slack-to-shogun` で状況と自信度を添えて判断を仰ぐ**。

一方「対応する」指摘は、修正をコミットして push → 再レビューすれば actionable は畳まれる。スレッドが `isResolved` になったか (残っていれば PR 全体へのコメントで `@coderabbitai resolve`) を確認すれば解決確認になる。

CodeRabbit の指摘には種類がある。**actionable comments** (インラインのレビュースレッドとして付く実害のある指摘) と、**body fold の指摘** (レビュー本文の折りたたみ。低優先度の nitpick だけでなく、diff 範囲外に落ちた `Outside diff range` の Major / Minor もここに入る。4-1b)。**両方を確認対象にする**。nitpick (純粋な好み) は拾うかどうかを上の表で判断してよく、拾わないと決めたものが残っていても Ready を止めない (手順5 の条件3 の表)。一方 body fold の Major / Minor は actionable と同格に扱い、手順5 の条件3 で 0 になるまで対応する。

**4-3. 修正を push する (「対応する」指摘)**

「対応する」と決めた指摘は、返信より先にコードを直して反映まで済ませる。修正をコミット (`/recipient-centric:commit`) して push する。**push に許可は要らない** (止まって聞かない。既定の完了ラインは「CodeRabbit の指摘 0 + CI green」なので、そこへ至る往復は全部自分で回す)。push したら HEAD が変わるので、**再度 `@coderabbitai review` を打って** 現 HEAD のレビューをやり直させ、4-1 に戻る。**未解決の reviewThread が 0 件** (手順5の `isResolved` 判定) になるまでこの往復を回す。

**4-4. push が終わってから返信する**

**返信は必ず修正の push が終わってから行う。push 前に「こう直します」と先に返信しない。** 修正を反映していない状態で返信すると、返信を受け取った側は反映済みだと思ってコードを見にいき、まだ変わっていないので困惑する。だから「対応する」指摘への返信は 4-3 の push 完了後に、**実際に反映した内容 (可能なら反映先のコミット SHA) を指し示して** 書く。

「対応しない」指摘は push を伴わない (コード変更が無い) ので、4-2 の返信と解決をそのまま行ってよい。「判断保留」は検討中である旨を返す。

全ての指摘に日本語で簡潔・丁寧にスレッド返信する。

**4-5. CI の面倒も見る**

CI が落ちていたらログを確認して直す。

```bash
OWNER="<owner>"; REPO="<repo>"   # この呼び出しの中で置き直す
gh run view "<run-id>" --repo "$OWNER/$REPO" --log-failed
```

push 後の CI は前面で張り付かず、終わるまで待って節目だけ Slack に流す。**複数のワークフローが走っていても 1 投稿にまとめる** (ワークフローごとに投げると報告スレッドが散らかる)。

```bash
OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
gh pr checks "$PR" --repo "$OWNER/$REPO" --watch --fail-fast   # どれか 1 つ落ちた時点で非 0 で返る
```

**`--watch` には上限が無い。** check が止まったままだと永久に待つので、バックグラウンドに載せて自分の側で打ち切るか、4-0 の回数上限つきのループを使う。上限のつもりで `timeout` を前に付けない — macOS には無いコマンドで、終了コード 127 で即座に終わり、待っていないのに待っているつもりになる。

**`gh run list --limit 1` で 1 本だけ選んで `gh run watch` しない。** ワークフローが複数あるリポジトリでは、選ばれなかった run の失敗をこの待ちが見逃す。手順 5 の `gh pr checks` で最後に拾えるとはいえ、待ちの時点で取り違えていると「CI は通った」と思って先へ進む。**待つ対象は PR に紐づく checks 全体**にする。

`--fail-fast` は **1 つ目の失敗を見つけた時点で待つのをやめる**指定で、残りの check は走ったままになる。直しに取りかかるのが早くなる代わりに、**そこで見えている失敗が全部とは限らない**。直して push すれば次の回で残りも評価されるので待ちとしてはこれでよいが、Ready の可否は必ず手順 5 の `gh pr checks` (`--watch` なし) で、全部が終わった状態を見て判定する。1 回の待ちで全 check の結果を並べたいときは `--fail-fast` を外す。

手元に CI 監視の仕掛け (完了を待って Slack へ投げるスクリプト等) があるならそれを使ってよい。**その場所をこの手順書に書かない** — 他の人の環境には無い。呼び出し側が引数か環境変数で場所を渡す形にする。

### 5. クリーンを確認して Ready For Review へ昇格

**大量ファイルを一括追加した PR では、この手順の前に必ず `@coderabbitai full review` を 1 回打ち、全ファイル評価を通す** (増分レビューだけでは diff 範囲外のファイルの指摘が出ない。4-1c)。full review が完了 (4-1c の完了判定) してから下のゲートを見る。

次の 3 つが揃ったら Ready 化する (**2 つではなく 3 つ**。reviewThread だけ見ると body fold を見落とす。4-1b)。

1. **CI が全てパス** (`gh pr checks <PR番号>` が緑)
2. **未解決の reviewThread が 0 件** — 「🎉 が出たか」ではなく `isResolved` で機械判定する:

   ```bash
   OWNER="<owner>"; REPO="<repo>"; PR="<PR番号>"   # この呼び出しの中で置き直す
   CURSOR=null; UNRESOLVED=0
   while : ; do                                   # 100 件ずつ、ページが尽きるまで
     PAGE=$(gh api graphql -f query='
       query($o:String!,$r:String!,$n:Int!,$c:String){repository(owner:$o,name:$r){
         pullRequest(number:$n){reviewThreads(first:100, after:$c){
           pageInfo{hasNextPage endCursor}
           nodes{isResolved comments(first:1){nodes{author{login}}}}}}}}' \
       -F o="$OWNER" -F r="$REPO" -F n="$PR" -F c="$CURSOR")
     UNRESOLVED=$(( UNRESOLVED + $(jq '[.data.repository.pullRequest.reviewThreads.nodes[]
            | select(.comments.nodes[0].author.login | test("coderabbit";"i"))
            | select(.isResolved==false)] | length' <<<"$PAGE") ))
     [ "$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"$PAGE")" = "true" ] || break
     CURSOR=$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' <<<"$PAGE")
   done
   echo "$UNRESOLVED"
   # → 0 なら未解決の inline 指摘なし
   ```

   **`reviewThreads(first:100)` を 1 回だけ叩いて数えない。** 往復の多い PR ではスレッドが 100 件を超え、**101 件目以降に残った未解決が数から落ちて 0 件に見える**。4-1b の遡りと同じ理由で、打ち切る位置は件数ではなく `pageInfo` が尽きるところに置く。

3. **現 HEAD に対する最新 review の body fold を、必須の 3 つと判断で閉じる 1 つに分けて見る** — reviewThread に出ない body fold (4-1b) を必ず別途確認する。現 HEAD (`commit.oid` 一致) に対する最新の CodeRabbit review の body を 4-1b の抽出コマンドにかける。**過去 HEAD の review に残る折りたたみは歴史的な記録なので数えない** (現 HEAD への review だけを見る)。

   | 見出し | 扱い |
   | --- | --- |
   | `Outside diff range comments` / `Minor comments` / `Actionable comments posted` | **0 でなければ Ready にしない。** 直して現 HEAD の review から消す |
   | `Nitpick comments` | **0 でなくてよい。** ただし 1 件ずつ 4-2 の表で裁き、拾わないと決めたものは「どれを・なぜ拾わないか」を PR のコメントに残す |

   **nitpick を必須 0 件に入れてはいけない。** body fold は reviewThread ではないので、返信でも `@coderabbitai resolve` でも畳めない。純粋な好みの指摘を拾わないと決めたのに、同じものが現 HEAD の review に再掲されると、**コードを変えない限り永久に Ready へ上げられなくなる** (0 にする手段が「指摘のとおり直す」しか無いため、4-2 の「拾うかどうかを判断してよい」が実質無効になる)。

   現 HEAD の最新レビューに `No actionable comments were generated in the recent review. 🎉` が出ていれば、それも 3 の十分条件 (出る環境なら)。ただし 🎉 が出ない環境では上の表の判定を正とする。

3 条件が揃わないときは Ready を強行せず、対応 (手順4) に戻る。判断が割れる指摘だけが残るなら `slack-to-shogun` で状況と自信度を添えて相談する。

```bash
gh pr ready "<PR番号>"
```

**Ready 昇格を握っている走行では、ここで止めて報告する。** 同僚のレビュー時間が動き出す操作なので、契約 (`dispatch` の `run-contract.jsonc` の `policy.draft`) が `keep` のままなら昇格しない。3 条件が揃ったところまでを成果として報告する。

### 6. 完了報告

結果をまとめて報告し、Slack にも通知する。投下は `slack-to-shogun` スキルで行う (投下スクリプトのパスを自分で書かない)。

**文面は契約の `policy.draft` で変える。** `keep` のまま止めたのに「→ Ready」と流すと、読んだ人は昇格済みだと思って次の作業に入る。

`policy.draft` が `keep` (Ready 昇格を握っている) とき:

```text
本文: 🏁 PR 仕上げ完了: ラベル整理 / 担当者 assign / 止める指摘 0 / CI ✅ → Draft のまま維持
引数: --header "✅ PR#<番号> / 仕上げ完了・Draft のまま" --color "#2EB67D" --topic "<https://github.com/<owner>/<repo>/pull/<PR番号>|<repo> / PR#<PR番号>>"
```

`policy.draft` が `ready` / `merge_ok` で、実際に昇格させたとき:

```text
本文: 🏁 PR 仕上げ完了: ラベル整理 / 担当者 assign / 止める指摘 0 / CI ✅ → Ready
引数: --header "✅ PR#<番号> / 仕上げ完了・Ready へ昇格" --color "#2EB67D" --topic "<https://github.com/<owner>/<repo>/pull/<PR番号>|<repo> / PR#<PR番号>>"
```

**「指摘 0」と書かない。「止める指摘 0」と書く。** 手順 5 の条件 3 のとおり、拾わないと決めた `Nitpick comments` は残ったまま閉じてよい。「指摘 0」と流すと、その残りごと無かったことになる。拾わなかった件数があるなら本文に添える (例: `止める指摘 0 / 見送った好みの指摘 1`)。

## 判断の原則

- **自信があるもの** は勝手に進める (明らかな typo・命名改善・lint 指摘・ラベル整理など)。逐一の許可は求めない。
- **自信がないもの** (設計判断・性能のトレードオフ・仕様に関わる変更・対応方針が割れる指摘) は着手前に `slack-to-shogun` でユーザーに相談する。自信度も添える。
- レビュアー (CodeRabbit 含む) の指摘を鵜呑みにしない。コードベースを調べて自分で妥当性を判断する。
- 複数の PR を順番に処理するときは 1 本ずつ最後まで (手順5まで) 通してから次へ。

## 落とし穴

| 失敗 | 原因 | 対策 |
| --- | --- | --- |
| 未解決スレッド 0 件を見て「クリーン」と判定したが、body fold に Major が残っていた | reviewThread だけを数えた | 手順5 は 3 条件。body fold を 4-1b の抽出で必ず別に見る |
| 指摘 0 件なのに完了を検知できず永久に待った | CodeRabbit は指摘が無いと新しいレビューを作らず、walkthrough コメントを書き換えるだけ。レビュー API を見張る監視は原理的に気づけない | 完了は 4-1 の状態遷移シグナルの OR で見る。特定の文字列にも新しいレビューにも賭けない |
| レート制限に当たって PR を飛ばした | 「時間の無駄」と判断した | 飛ばさない。15 分おきの督促ループを回す。投稿はユーザーの手に渡す |
| 大量ファイル追加の PR で指摘 0 件に見えた | 増分レビューは初回コミットの diff 範囲しか見ない | 手順5 の前に `@coderabbitai full review` を 1 回打つ |
| 本文が空の受領 review を数えて「指摘 0 件」と読んだ | `@coderabbitai review` / `resolve` を打つたびに本文の無い review が現 HEAD に積まれる。数える語が 1 つも無いので折りたたみが `[]` で返り、レビュー前なのに 0 件に見える | 4-1b の抽出で `.body \| length > 0` を必ず入れる。加えてサマリーコメントを時刻順に全部読み、`Review limit reached` が消えているかを確かめる |
| 折りたたみの抽出が古い review を読んでいた | `reviews(first:40)` を現 HEAD で絞らずに流し、複数の review を並べて目で拾っていた | 4-1b の抽出コマンド。`commit.oid` が現 HEAD のものだけに絞り、そのうち最新の 1 本を取る |
| 現 HEAD の review が実在するのに「未レビュー」と出て、そこから進まなくなった | 1 ページ (20 件) だけ見て打ち切っていた。往復の多い PR では現 HEAD の review が取得する範囲から落ちる | 4-1b の抽出コマンドは `pageInfo.hasPreviousPage` と `startCursor` を見て `before` で遡る。遡りの上限に達しても、未レビュー扱いにするだけで Ready には進めない |
| 拾わないと決めた nitpick が現 HEAD の review に再掲され、Ready へ上げられなくなった | Ready ゲートの必須 0 件に nitpick を入れていた。body fold は返信でも `@coderabbitai resolve` でも畳めないので、0 にする手段が「指摘のとおり直す」しか無い | 手順5 の条件3 の表。必須 0 件は `Outside diff` / `Minor` / `Actionable comments posted` の 3 つで、nitpick は判断を書き残して閉じる |
| 「対応しない」と返信したのにスレッドが開いたまま残った | `@coderabbitai resolve` をスレッド返信に書いた | 解決の依頼は PR 全体へのコメントとして投げる。返信に書くとスレッドが 1 件増える |
| 修正前に「こう直します」と返信して、読んだ人がコードを見て困惑した | 返信を push より先にした | 4-4。返信は push が終わってから、反映先の SHA を指して書く |
| CI も CodeRabbit も結果が出ているのに待ち続けた | CodeRabbit の check-run の完了を待つ条件にしたが、そのリポジトリでは CodeRabbit は commit status として出ていたので、条件が永遠に成り立たなかった。待つ前に現状も見ていなかった | 4-0。待つ前に 1 度見る。CI の収束 (失敗が出たら即抜ける・上限つき) → CodeRabbit の結論の順で見る。CodeRabbit の状態は `statusCheckRollup` で両方の形を拾う (4-1 の完了シグナル 1) |
| 監視を張ったつもりが、何も見ていなかった | `timeout` を付けて起動したが macOS には無いコマンドで、終了コード 127 で即座に終わっていた。動いた証拠を見ずに待っていた | 4-0 の 4。起動直後に最初の出力か終了コードを見る。上限は `timeout` ではなく回数で持つ |
| Slack の通知に宛先が出ず `<\| / PR#>` だけが並んだ | 手順 0 で組み立てたリンクを変数に入れ、手順 4 / 手順 6 で参照した。シェルの変数は次のコマンド実行には残らないので空文字に展開される。空でも `notify.sh` は成功を返すので打った側は気づけない | 手順 0。リンクは持ち回らず、通知のたびにその呼び出しの中で書く |
