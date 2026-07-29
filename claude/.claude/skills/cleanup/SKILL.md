---
name: cleanup
description: PRマージ後の後片付けをする。specsの削除・protoブランチの削除・デフォルトブランチへの移動を行う。
argument-hint: "<feature>"
allowed-tools: Bash(git *), Bash(gh *), Bash(rm *)
---

# 後片付けスキル

## 役割
着地済み（PR マージ済み、または PR を作らない運用でデフォルトブランチへ取り込み済み）の feature について、`.specs/<feature>` と `<feature>-proto` ブランチを削除してデフォルトブランチに戻す。

**フェーズブランチ（`<feature>` / `<feature>-pN`）は削除しない。** マージ時に `gh pr merge -d` を使えばローカルとリモートの両方が消えるので、stacked でも各 PR のマージで自然に片付く。ここに同じ削除を持つとロジックが二重になり、フェーズ数だけループを回す必要も出る。このスキルが担うのは **`gh` が関知しないもの**（`.specs` と、PR に紐づかない `<feature>-proto`）だけにする。

## 入出力
- **入力**: feature 名（引数、または `.specs/` の一覧から選択）
- **出力**: ファイル成果物は持たない（削除結果を報告する）

## 引数
- `$ARGUMENTS`: feature 名（省略可。省略時は `.specs/` の一覧から選ばせる）

## モード
このスキルは**取り消せない削除（`.specs/<feature>`）を伴うので確認を残す**。着地が確認できない（PR が未マージ・デフォルトブランチへ未取り込み）ときは必ず人に確認し、勝手に消さない。`auto` は持たない（orchestrator の自走パイプラインには組み込まない）。

## 進め方

### Step 1: 対象の確定

**feature 名:** `$ARGUMENTS` が指定されていればそれを使う。未指定なら `.specs/` 以下のディレクトリを列挙し、番号で選ばせる：

```
ls -1 .specs/
```

**`proposals` は候補から除外する。** `.specs/proposals/` はスキル自己改善の提案キュー（永続・全 app repo/feature の集約先）であり feature ではないため、cleanup の削除候補として**絶対に掴んではならない**。

候補が 1 件も無い場合は「`.specs/` にディレクトリが見つかりません。feature 名を直接入力してください」と伝えて入力を待つ。候補があれば番号付きで提示する：

```
.specs/ 以下のディレクトリが見つかりました：

1: foo-feature
2: bar-feature

番号で選んでください（その他: 手入力）:
```

### Step 2: 着地の確認

`.specs/<feature>` の削除は取り消せないので、feature が着地しているかを先に確かめる。**確認対象は feature のフェーズブランチ**（`<feature>` と `<feature>-p*`）で、削除はしない：

```
gh pr list --search "head:<feature>" --state all \
  --json number,headRefName,state,mergedAt
```

- **全 PR が `MERGED`** → Step 3 へ
- **`OPEN` / `CLOSED`（マージなしクローズ）が混ざる** → 該当 PR を挙げて「まだ着地していない PR があります」と伝え、本当に後片付けするか確認する
- **PR が 1 件も見つからない** → PR を作らない運用（`claude/CLAUDE.md`「PR 運用の有無」が `なし`）の可能性があるので、PR の代わりに**デフォルトブランチへ取り込み済みか**を見る：
  ```
  DEFAULT=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  git fetch origin
  git branch --list "<feature>" --list "<feature>-p*"
  git branch --merged "origin/$DEFAULT" | grep -E "^\s+<feature>(-p[0-9]+)?$"
  ```
  - 存在するフェーズブランチが全てマージ済み → Step 3 へ（PR 無しで着地した想定どおり）
  - ローカルにフェーズブランチが 1 本も無い → `gh pr merge -d` で既に消えている想定なので Step 3 へ
  - 未マージのものがある → 人間に確認する

### Step 3: 後片付け

**3-1 デフォルトブランチへ移動**

```
DEFAULT=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git checkout "$DEFAULT"
git pull origin "$DEFAULT"
```

**3-2 prototype ブランチの削除**

prototype 工程を使った feature では `<feature>-proto` が残っている。これは PR にならない参照用ブランチで `gh pr merge -d` の対象外なので、ここで削除する（マージされていないため `-D`）。存在しなければスキップする：

```
git rev-parse --verify <feature>-proto >/dev/null 2>&1 && git branch -D <feature>-proto
```

**フェーズブランチは削除しない。** ただし `<feature>` / `<feature>-p*` がローカルに残っていたら、`gh pr merge -d` を使わずにマージした（Web UI など）ことになるので、**列挙して報告するだけ**にする（消すかは人が判断する）：

```
git branch --list "<feature>" --list "<feature>-p*"
```

**3-3 `.specs/<feature>` の削除**

存在すれば削除し、無ければスキップする：

```
rm -rf .specs/<feature>
```

**`<feature>` が `proposals` のときは絶対に実行しない。** `.specs/proposals/` は feature ではなく提案キュー（cleanup 対象外）。誤って `proposals` が feature 名として渡された場合は削除せず、その旨を伝えて中断する。

### Step 4: 出力

次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。

✅ 後片付け完了
<どの feature の後片付けをしたかを 1 行>
- <削除した specs・proto ブランチ 最大 3 行>

要確認:
- 残存フェーズブランチ: <ブランチ名>（`gh pr merge -d` を使えばマージ時に消えます）

次の一手:
▶ 会話をクリアする：/clear

カードは**やったこと**・**要確認**・**次の一手**の 3 ブロックに分ける。

- やったこと: 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（削除対象が無かった項目は行ごと省略）。cleanup は**ファイル成果物を持たない**ので 📄 行は出さない。`.specs/<feature>` と `<feature>-proto` の削除結果を載せる。
- 要確認: Step 3-2 で列挙した**残存フェーズブランチ**だけを出す（cleanup は消さないので、消すかは人が判断する）。残っていなければブロックごと省略する。
- 次の一手: `/clear` はハーネスコマンドだが同じ形式で書き、**自動実行せず**ユーザーの実行を待つ。

**中断時**: ヘッダを `⚠ 後片付け中断` に差し替え、一言サマリに中断理由（着地していない PR がある・`proposals` が渡されたなど）、次の一手に復帰コマンドを書く。

## エラー処理
- `git checkout` で失敗する → `git fetch origin` してから再試行する
- `<feature>-proto` が存在しない → スキップして次へ
- `.specs/<feature>` が存在しない → スキップして次へ

## 完了条件
デフォルトブランチに移動し、`<feature>-proto`（あれば）と `.specs/<feature>` の削除を済ませたら完了（いずれも「存在しなかった」で確認できていればよい）。**フェーズブランチの削除は完了条件に含めない**（`gh pr merge -d` の担当）。`/clear` の実行も完了条件に含めない。
