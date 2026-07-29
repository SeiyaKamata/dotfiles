---
name: cleanup
description: PRマージ後の後片付けをする。作業ブランチの削除・specsの削除・mainへの移動・会話のクリアを行う。
argument-hint: "<feature>"
allowed-tools: Bash(git *), Bash(gh *), Bash(rm *)
---

# 後片付けスキル

## 役割
着地済み（PR マージ済み、または PR を作らない運用でデフォルトブランチへ取り込み済み）の feature について、作業ブランチと `.specs/<feature>` を削除してデフォルトブランチに戻す。

## 入出力
- **入力**: feature 名（引数、または `.specs/` の一覧から選択）とカレントブランチ
- **出力**: ファイル成果物は持たない（削除結果を報告する）

## 引数
- `$ARGUMENTS`: feature 名（省略可。省略時は `.specs/` の一覧から選ばせる）。ブランチ名はカレントブランチから自動取得する

## モード
このスキルは**削除を伴うので確認を残す**。着地が確認できない（PR が未マージ・デフォルトブランチへ未取り込み）ときは必ず人に確認し、勝手に消さない。`auto` は持たない（orchestrator の自走パイプラインには組み込まない）。

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

**カレントブランチ:**

```
git branch --show-current
```

カレントブランチがデフォルトブランチの場合、削除対象のブランチが無いため人間に確認する（`.specs/` の削除だけ行うのかを確かめる）。

### Step 2: 着地の確認

```
gh pr view <カレントブランチ名> --json state,mergedAt,headRefName --jq '{state, mergedAt, branch: .headRefName}'
```

- `MERGED` → Step 3 へ
- `OPEN` → 「PR はまだマージされていません」と伝え、本当に後片付けするか確認する
- `CLOSED`（マージなしクローズ）→ 人間に確認する
- **PR が見つからない** → PR を作らない運用（`claude/CLAUDE.md`「PR 運用の有無」が `なし`）の可能性があるので、PR の代わりに**デフォルトブランチへ取り込み済みか**を見る：
  ```
  DEFAULT=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  git fetch origin
  git branch -r --merged "origin/$DEFAULT" | grep -F "origin/<カレントブランチ名>"
  ```
  - マージ済み → Step 3 へ（PR 無しで着地した想定どおり）
  - 未マージ → 人間に確認する

### Step 3: 後片付け

**3-1 デフォルトブランチへ移動**

```
DEFAULT=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
git checkout "$DEFAULT"
git pull origin "$DEFAULT"
```

**3-2 ローカルブランチの削除**

```
git branch -d <元のブランチ名>
```

`-d` で削除できない（未マージ警告）場合、Step 2 でマージ済みを確認できているときに限り `-D` を使う。

**prototype ブランチ:** prototype 工程を使った feature では `<feature>-proto` が残っている。これは PR にならない参照用ブランチで、impl が流用済みなら不要なので削除する（マージされていないため `-D`）。存在しなければスキップする：

```
git rev-parse --verify <feature>-proto >/dev/null 2>&1 && git branch -D <feature>-proto
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
- <削除したブランチ・specs 最大 3 行>

次の一手:
▶ 会話をクリアする：/clear

カードは**やったこと**・**次の一手**の 2 ブロックに分ける（cleanup は判断で埋める余地が無いので「要確認」は持たない）。

- やったこと: 一言サマリは 1 行。主要な結果は `- ` の箇条書きで**最大 3 行**（削除対象が無かった項目は行ごと省略）。cleanup は**ファイル成果物を持たない**ので 📄 行は出さない。削除したブランチ名（`<feature>-proto` を含む）と `.specs/<feature>` の削除結果を載せる。
- 次の一手: `/clear` はハーネスコマンドだが同じ形式で書き、**自動実行せず**ユーザーの実行を待つ。

**中断時**: ヘッダを `⚠ 後片付け中断` に差し替え、一言サマリに中断理由（PR が未マージ・`proposals` が渡されたなど）、次の一手に復帰コマンドを書く。

## エラー処理
- `git checkout` で失敗する → `git fetch origin` してから再試行する
- ローカルブランチが存在しない → スキップして次へ
- `.specs/<feature>` が存在しない → スキップして次へ

## 完了条件
デフォルトブランチに移動し、作業ブランチ（＋あれば `<feature>-proto`）と `.specs/<feature>` の削除を済ませたら完了（いずれも「存在しなかった」で確認できていればよい）。`/clear` の実行は完了条件に含めない。
