---
name: propose
description: 各工程・PJからの改善提案の唯一の入口。skill / pipeline 改善の気づきを、規模に応じて kind: rule（一行のルールに落ちる）または kind: backlog（構成規模の改善）としてdotfilesの.specs/proposals/へ1件発行・記録する。再発判定はしない。
argument-hint: "[target] [claim...]"
allowed-tools: Bash(readlink *), Bash(ls *), Bash(test *), Bash(date *), Read, Write, AskUserQuestion
---

# 提案発行（propose）

## 役割

パイプラインの各工程・PJ が「これは skill / pipeline 側で改善すべきだった」と気づいたとき、
恒久ルールに直接書かず、dotfiles の単一キュー `.specs/proposals/` へ改善提案を発行する
**唯一の入口**として機能する。気づきの規模に応じて `kind: rule`（一行のルールに落ちる）と
`kind: backlog`（構成規模の skill / pipeline 改善）の2種別に分けて記録する。

**このスキルは書き込みと検証のみ**を担う。クラスタ判定・再発判定・寿命管理は持たない（単一
実行では過去が見えないため原理的に持てない。それらは `/proposals-sweep` の責務）。

**無確認実行**: 発行・記録の可否についてユーザーの事前承認を求めず、提案ファイルを書いて
事後報告する。ただし `kind: backlog` を記録した際は `/spinoff` を自動起動しない（着手は
人が起動する。下記「完了カード」参照）。

## 引数

- 第1引数: `target`（対象スキル名。例 `review`）
- 第2引数以降: `claim`（一行の主張）
- 省略時はプロンプト本文・直前の工程文脈から Claude が `target`/`claim` を組み立てる。
  組み立てられなければ発行しない（下記 Step 2 の敷居）。

## 提案ファイルのスキーマ

提案ファイルの frontmatter とその意味は次のとおり（このスキルが正本。`.specs/proposals/` 配下に
スキーマ用ファイルは無く、この節が唯一の定義）。

```markdown
---
target: <対象。下記「target の語彙」参照>
claim: <一行の主張。kind により意味が変わる>
kind: rule | backlog
date: <YYYY-MM-DD>
source_feature: <発行元 feature 名。不明なら「不明」>
status: open | applied | dropped
---

<本文。kind により書くものが変わる>
```

### kind の語彙

- **`rule`**: 一行足せば次回以降防げるルール。
- **`backlog`**: 構成規模の skill / pipeline 改善（複数ステップの追加・ファイルの新設・スキル
  本体の修正が要る）。

### target の語彙（単一値のみ。リストは取らない）

- **スキル名**（例 `review` `commit` `handoff`）: 対象が1スキルに収まる。
- **`CLAUDE.md`**: 恒久ルール宛。
- **`pipeline`**（新設の予約語）: 複数スキル・ドキュメントに跨り代表を1つに絞れない backlog。
  使うときは対象群を本文に列挙する（frontmatter は単一値を保つ）。

### claim の書き分け

- **`rule` の `claim`**: そのまま `CLAUDE.md` か対象スキルに追記できる一行。固有名詞を含めず
  一般化する。「一行で書けなければ発行しない」敷居は**rule にのみ適用**する。
- **`backlog` の `claim`**: 変更の主題の一行要約。追記可能な文である必要はなく、上記の敷居は
  適用しない。

### backlog 本文に書く2点

1. なぜ一行のルールでは足りないか
2. 触ることになる対象

## 進め方

### Step 1: 振り分け判定

このスキルは改善提案の唯一の入口であり、気づきの種類に応じて次の5分岐で判定する。判定は
**カレント PJ に依存させない**（dotfiles 内で起動していても構成規模の気づきは backlog として
記録する。「dotfiles で作業中なら `/spinoff`」という分岐は設けない）。

| 判定 | 行き先 |
|---|---|
| 一行のルールに落ちる（`CLAUDE.md` か対象スキルに1行足せば次回以降防げる） | Step 2 へ → `kind: rule` で発行 |
| 構成規模（複数ステップの追加・ファイルの新設・スキル本体の修正が要る） | Step 2 へ → `kind: backlog` で記録 |
| 上記どちらか判別が付かない | `kind: backlog` で記録（迷ったら backlog に倒す） |
| skill / pipeline の改善ではなくプロダクト側のスコープ切り分け | キューに発行せず `/spinoff`（棚上げ）・`/handoff`（ブロッカー）を案内して終了 |
| 再発しない訂正（その場限りのタイポ・パス違い） | 何もせず終了 |

恒久ルール（`CLAUDE.md`）へ勝手に追記しない — 反映するかは人が判断する（再発判定は
`/proposals-sweep` の責務）。

### Step 2: target・claim の確定（発行の敷居）

- `target`: 対象（スキル名・`CLAUDE.md`・`pipeline` のいずれか）。引数または文脈から確定する。
  語彙の詳細は `## 提案ファイルのスキーマ` を参照する。
- `claim`: 一行の主張。`## 提案ファイルのスキーマ` の「claim の書き分け」に沿って、`kind` に
  応じた粒度で書く。

**`claim` を一行で書けないときは、提案を発行しない。この敷居は `kind: rule` にのみ適用し、
`kind: backlog` には適用しない**（backlog は主題の一行要約で足りるため）。

### Step 3: QUEUE_DIR の解決

symlink からハードコードせず動的に解決する:

```bash
QUEUE_DIR="$(dirname "$(dirname "$(dirname "$(readlink -f ~/.claude/skills)")")")/.specs/proposals"
```

- `readlink -f ~/.claude/skills` → `.../dotfiles/claude/.claude/skills`
- 3つ上 → `.../dotfiles`、そこに `/.specs/proposals` を付ける
- `readlink -f` が失敗する（symlink が張られていない環境）ときは、その旨を明示エラーとして
  報告し発行を中止する。
- `test -d "$QUEUE_DIR"` で存在確認し、無ければ作成してよい（README.md ごと1.1 で作成済みの
  想定だが、無い環境向けの保険として作成する）。

### Step 4: 一意なファイル名の生成

命名規則: `<YYYYMMDD-HHMMSS>-<target>-<claim-slug>.md`

- `date +%Y%m%d-%H%M%S` でタイムスタンプを得る。
- `claim` を kebab-case 化し先頭数語を `claim-slug` とする。
- `test -e "$QUEUE_DIR/<候補名>.md"` で衝突確認し、衝突していれば末尾に `-2` `-3` と連番を
  付けて再確認する（同一秒・同一 target の多重発行はソロ運用では稀だが保険として行う）。

### Step 5: 提案ファイルの Write

`## 提案ファイルのスキーマ` に従い、確定したファイル名に**1件だけ** Write する:

```markdown
---
target: <target>
claim: <claim>
kind: rule | backlog
date: <当日 YYYY-MM-DD>
source_feature: <発行元 feature 名。不明なら現在のカレント feature か「不明」>
status: open
---

<本文。rule はなぜこの工程で catch すべきだったかを1〜数行で。backlog はなぜ一行のルールでは
足りないかと触ることになる対象を書く>
```

- `target`・`claim`・`kind` のいずれかが欠けている状態では Write しない（不正な提案を作らない）。

### Step 6: 報告

書いたファイルのフルパスと `kind`・`claim` を、末尾の `## 完了カード` に畳んで報告する
（カードの外に別文で書かない）。記録した種別（`rule` / `backlog`）を必ず明示する。

**再発があるかは調べない。** 同種の提案が既にキューにあっても気にせず、毎回1件を投げるだけ
にとどめる（再発判定・クラスタ化は `/proposals-sweep` の責務）。

## 完了条件

次の4つの出口のいずれかに到達したら完了する:

- **rule 発行**: 一行のルールに落ちると判定し、`kind: rule` で提案ファイルを1件発行し、
  フルパスと `claim` を報告できた。
- **backlog 記録**: 構成規模（または判別不能）と判定し、`kind: backlog` で提案ファイルを1件
  記録し、フルパスと `claim`・着手導線（dotfiles で `/spinoff` により詳細化する旨）を報告できた。
- **案内して終了**: プロダクト側のスコープ切り分けと判定し、キューへ発行せず `/spinoff`・
  `/handoff` を行き先として案内して終了した。
- **何もせず終了**: 再発しない訂正と判定し、どちらにも回さず終了した。

`kind` を確定できない状態では Write しない。

## 完了カード
提案ファイルの Write が済んだら、次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。`/proposals-sweep` は自動起動せずユーザーの実行を待つ。`kind: backlog` を記録した際も `/spinoff` を自動起動しない。

- 一言サマリは 1 行（`kind`・`target`・`claim` を示す）。主要な結果は `- ` の箇条書きで**最大 3 行**（無ければ行ごと省略）。根拠の詳細は提案ファイルに書き、カードには列挙しない。
- ▶ 行は停止点なので 1 行に留める（種別に応じて rule / backlog のどちらか一方だけを出す）。

✅ 提案発行完了
<kind と target と claim を 1 行>
- <主要な結果 最大 3 行>
📄 .specs/proposals/<提案ファイル>
▶ OK：/proposals-sweep で再発を棚卸し（任意）          ← kind: rule のとき
▶ OK：dotfiles で /spinoff <上記パス>（backlog を seed.md に詳細化）  ← kind: backlog のとき

発行しなかった／完了条件を満たせずに終了するときは、同じ構成でヘッダを `⚠ 提案発行中断` に差し替え、一言サマリに理由（`claim` を一行で書けない・プロダクト側のスコープ切り分け・symlink 未設置など）、▶ 行に代わりの行き先（`/spinoff`・`/handoff` で改善提案に切り出す など）を書く（ファイル未生成なので 📄 行は省略する）。

## エラー処理

- `readlink -f ~/.claude/skills` が失敗する（symlink 未設置環境）→ 発行を中止し、その旨を
  明示エラーとして報告する。
- `target`/`claim` のどちらかが確定できない → 発行しない（Step 2 の敷居）。
