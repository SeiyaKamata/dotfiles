---
name: proposals-sweep
description: 提案キューを走査し再発クラスタを報告する手動スイープ。dotfiles の .specs/proposals/ を1コマンドで棚卸しし、target+claim が近い open 提案を3件以上のクラスタとして再発シグナルを報告する。90日超の open singleton は寿命管理で dropped に落とす。スキル本体の修正はしない。
allowed-tools: Bash(readlink *), Bash(ls *), Bash(cat *), Bash(date *), Bash(grep *), Read, Edit, AskUserQuestion
---

# 提案キューのスイープ（proposals-sweep）

## 役割

`.specs/proposals/` に積み上がった提案を手動1コマンドで走査し、`target`+`claim` が近い
`open` 提案をクラスタ化して再発シグナルとして報告する。**読み取り・クラスタ報告・status
遷移のみ**を担い、スキル本体の修正は行わない（修正は人が別途判断・実施する）。

## 引数

なし。1コマンドで起動する。

## 進め方

### Step 1: QUEUE_DIR の解決

```bash
QUEUE_DIR="$(dirname "$(dirname "$(dirname "$(readlink -f ~/.claude/skills)")")")/.specs/proposals"
```

- `readlink -f` が失敗する、あるいは `QUEUE_DIR` が存在しない／中身が空（`README.md` 以外の
  提案ファイルが無い）場合は、「提案なし」と報告してここで終了する。

### Step 2: open な提案の抽出

`$QUEUE_DIR/*.md`（`README.md` を除く）の frontmatter を読み、`status: open` の提案だけを
対象に絞る。`applied` / `dropped` は以降の処理から完全に除外する。

### Step 3: 寿命管理（90日超 open singleton の失効）

- 各提案の `date`（`YYYY-MM-DD`）を epoch に変換し、現在時刻との差が `90*86400` 秒を超えるか
  を判定する（macOS/BSD 前提。ロケール非依存にするため `-j -f` を使う）:

  ```bash
  date -j -f "%Y-%m-%d" "<date>" "+%s"
  now=$(date +%s)
  ```

  差が `90*86400` を超えていれば「90日超」とみなす。

- **singleton**（同一 `target` かつ `claim` が近い提案が自分1件だけ）である 90日超 `open`
  提案だけを `status: dropped` に `Edit` で更新する。
- **クラスタを構成しているメンバー**（Step 4 で3件以上のクラスタに属す提案）は、90日超でも
  drop しない。生きた再発シグナルとして残す。
- singleton か否かは、寿命判定の前に一度 Step 4 のグルーピングを行い、そのグルーピング結果を
  流用して判定する（同じ near-match ロジックを2度書かない）。

### Step 4: クラスタ検出

残った（`dropped` にしなかった）`open` 提案を、`target` が完全一致し `claim` が近似する
もの同士でグルーピングする。近似判定は AI が行う（表現の揺れは吸収するが、無関係な claim を
混ぜない）。

- 同一クラスタが **3件以上** → 再発シグナルとして報告対象にする。
- 1〜2件（singleton 含む）→ 再発として報告しない（件数の参考表示のみ許容）。

### Step 5: 報告

クラスタ（3件以上）ごとに次のフォーマットで報告する:

```
## 再発シグナル

### target: <target>
- 代表 claim: <claim>
- 件数: N
- ファイル:
  - <path1>
  - <path2>
  - ...
```

クラスタが1つも無い場合は「再発クラスタなし（open singleton のみ）」と報告する。

### Step 6: 修正はしない・applied への更新は補助のみ

このスキルはスキル本体・CLAUDE.md の修正を行わない。報告を見た人間が「このクラスタは修正に
着手する」と判断した場合のみ、対象クラスタの提案群を `status: applied` に更新する補助を
`AskUserQuestion` で確認のうえ提供する（任意・対話）。ユーザーの明示的な指示が無い限り
`applied` へは書き換えない。

## 完了条件

- `.specs/proposals/` を1コマンド起動で走査し、`target`+`claim` が3件以上一致するクラスタを
  すべて報告できたら完了。
- `open` かつ90日超の singleton を `status: dropped` に更新できている（クラスタメンバーは
  対象外）。
- `applied` / `dropped` の提案がクラスタ検出（Step 4）の対象から除外されている。
- クラスタが無ければ「再発クラスタなし」と報告して完了。

## エラー処理

- `QUEUE_DIR` が解決できない／空 → 「提案なし」で終了する。
- frontmatter が壊れている（`target`/`claim`/`date`/`status` のいずれか欠落）提案ファイルが
  ある場合は、その提案をクラスタ検出・寿命管理の対象から外し、「不正な提案ファイルあり」と
  ファイル名を添えて報告する（黙って無視しない）。
