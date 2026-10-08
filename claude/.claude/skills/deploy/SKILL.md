---
name: deploy
description: 現在のブランチを ITG などの開発環境へ、GitHub Actions の deploy workflow を起動して反映する。開発環境で動作を検証したいときに使う。
allowed-tools: Bash(git *), Bash(gh *), Read, Grep, Glob
---

# 開発環境デプロイスキル

## 役割
検証用に、現在のブランチを開発環境へ反映する。
repo が持つ GitHub Actions の workflow を起動し、完了まで見届ける。

対象は開発環境だけで、本番環境へは使わない。
開発環境は作り直しが効くため、起動前の承認は取らない。

## 判断が割れる点の扱い
repo ごとの差は、workflow の定義と `CLAUDE.local.md` の `## デプロイ` 節で吸収する。
workflow を 1 つに絞れないとき、入力を埋められないときは推測せず、中断カードで人に委ねる。

## 進め方

### Step 1: 手順の決定

`CLAUDE.local.md` に `## デプロイ` 節があれば、その手順を採用する。
節が workflow の起動以外の操作を含むときは、Step 4 の後に節の順で実行する。
対話ログインが要る操作は実行せず、Step 5 の中断カードで `! <コマンド>` として案内する。

節が無ければ、`.github/workflows` から `workflow_dispatch` を持つ workflow を探し、ファイル名か `name` に `deploy` か `cd` を含むものを候補にする。
候補が 1 つならそれを採用し、0 または複数なら Step 5 の中断カードで候補を挙げて終了する。

### Step 2: ref と inputs の決定

ref は現在のブランチにする。
`git rev-list --count @{u}..HEAD` が 0 でない、または upstream が無いときは、workflow が反映するのはリモートの内容なので、未 push の旨を Step 5 の中断カードで報告して終了する。

workflow の `inputs` を読んで次のように埋める。

- 環境を表す入力があれば、ITG に当たる値を選ぶ
- ブランチを表す入力があれば、ref を渡す
- それ以外は既定値に任せ、既定値の無い必須入力が残ったら Step 5 の中断カードで報告して終了する

ブランチを表す入力が無い workflow は `--ref` で渡す。

### Step 3: 起動

```
gh workflow run <workflow> --ref <ref> -f <入力名>=<値>
```

起動後、同じ workflow の最新の `workflow_dispatch` の run を `gh run list --workflow <workflow> --event workflow_dispatch --limit 1 --json databaseId,url` で取る。

### Step 4: 完了待ち

```
gh run watch <run の databaseId> --exit-status
```

失敗したら `gh run view <run の databaseId> --log-failed` で失敗したジョブのログを取り、Step 5 の中断カードに要点を載せる。

### Step 5: 出力

次のカードを、コードフェンス自体は出さずに中身だけ出力して終了する。
中断時は見出しを `### デプロイ中断` にし、1 行目に中断理由を書き、生成物の行は未起動なら省き、次の一手は復帰に必要な操作だけにする。

```markdown
### デプロイ完了
<反映したブランチと環境を 1 行>

生成物: <run の URL>
```
