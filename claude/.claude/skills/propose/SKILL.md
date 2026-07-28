---
name: propose
description: 各工程の気づきを提案キューに1件発行する軽量スキル。気づきが「一行のルールに落ちる」と判断したとき、恒久ルールに直接書かず dotfiles の .specs/proposals/ へ提案1件を投げる。再発判定はしない。
argument-hint: "[target] [claim...]"
allowed-tools: Bash(readlink *), Bash(ls *), Bash(test *), Bash(date *), Read, Write, AskUserQuestion
---

# 提案発行（propose）

## 役割

パイプラインの各工程が「これはスキル側で catch/改善すべきだった」と気づいたとき、恒久ルール
に直接書かず、dotfiles の単一キュー `.specs/proposals/` へ提案を1件だけ発行する。

**このスキルは書き込みと検証のみ**を担う。クラスタ判定・再発判定・寿命管理は持たない（単一
実行では過去が見えないため原理的に持てない。それらは `/proposals-sweep` の責務）。

## 引数

- 第1引数: `target`（対象スキル名。例 `review`）
- 第2引数以降: `claim`（一行の主張）
- 省略時はプロンプト本文・直前の工程文脈から Claude が `target`/`claim` を組み立てる。
  組み立てられなければ発行しない（下記 Step 2 の敷居）。

## 進め方

### Step 1: 振り分け判定

気づきが**一行のルールに落ちるか**で判定する:

- **一行のルールに落ちる**（`CLAUDE.md` か対象スキルに 1 行足せば次回以降防げる）→ Step 2 へ
  進みキューに発行する。
- **手順・構成の変更が要る**（複数ステップの追加・ファイルの新設・コードの修正）→ キューには
  発行しない。`/spinoff`（今いる PJ で直せるもの）または `/handoff`（別 PJ 側の変更が要るもの。
  dotfiles のスキル本体の穴も dotfiles 宛）で**改善提案に切り出す**よう案内し、ここで終了する。
- **再発しない訂正**（その場限りのタイポ・パス違い）→ どちらにも回さず終了する。

恒久ルール（`CLAUDE.md`）へ勝手に追記しない — 反映するかは人が判断する（再発判定は
`/proposals-sweep` の責務）。判断がつかない場合は Step 2 の敷居に委ね、一行で書けなければ
`/spinoff`・`/handoff` に回す。

### Step 2: target・claim の確定（発行の敷居）

- `target`: 対象スキル名（例 `review` / `qa` / `fix` / `test` / `impl` など）。引数または
  文脈から確定する。
- `claim`: 一行の主張。`.specs/proposals/README.md` の「claim の書き方」に沿って、簡潔・定型
  （固有名詞を含めず、次回以降も再発しうる一般化した表現）に書く。

**`claim` を一行で書けないときは、提案を発行しない。** 迷って複数行や条件分岐になる気づきは、
一行のルールでは足りず手順・構成の変更が要るということなので、`/spinoff`（今いる PJ）・
`/handoff`（別 PJ）を行き先として案内して終了する。

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

以下のスキーマで、確定したファイル名に**1件だけ** Write する:

```markdown
---
target: <target>
claim: <claim>
date: <当日 YYYY-MM-DD>
source_feature: <発行元 feature 名。不明なら現在のカレント feature か「不明」>
status: open
---

<根拠となった今回の具体的な指摘。なぜこの工程で catch すべきだったかを1〜数行で>
```

- `target` または `claim` が欠けている状態では Write しない（不正な提案を作らない）。

### Step 6: 報告

書いたファイルのフルパスと `claim` を、末尾の `## 完了カード` に畳んで報告する（カードの外に別文で書かない）。

**再発があるかは調べない。** 同種の提案が既にキューにあっても気にせず、毎回1件を投げるだけ
にとどめる（再発判定・クラスタ化は `/proposals-sweep` の責務）。

## 完了条件

- 引数または文脈から `target`・`claim` を確定できた場合、`.specs/proposals/` に提案ファイルを
  1件だけ発行し、フルパスと `claim` を報告できたら完了。
- `claim` を一行で書けない場合は、発行せずその旨を報告して終了する（敷居）。
- 手順・構成の変更を要すると判定された場合は、キューへ発行せず `/spinoff`・`/handoff` での改善提案に
  回す旨を案内して終了する（振り分け）。

## 完了カード
提案ファイルの Write が済んだら、次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。`/proposals-sweep` は自動起動せずユーザーの実行を待つ。

- 一言サマリは 1 行（`target` と `claim` を示す）。主要な結果は `- ` の箇条書きで**最大 3 行**（無ければ行ごと省略）。根拠の詳細は提案ファイルに書き、カードには列挙しない。
- ▶ 行は停止点なので 1 行に留める（棚卸しは任意）。

✅ 提案発行完了
<target と claim を 1 行>
- <主要な結果 最大 3 行>
📄 .specs/proposals/<提案ファイル>
▶ OK：/proposals-sweep で再発を棚卸し（任意）

発行しなかった／完了条件を満たせずに終了するときは、同じ構成でヘッダを `⚠ 提案発行中断` に差し替え、一言サマリに理由（`claim` を一行で書けない（手順・構成の変更が要る）・symlink 未設置など）、▶ 行に代わりの行き先（`/spinoff`・`/handoff` で改善提案に切り出す など）を書く（ファイル未生成なので 📄 行は省略する）。

## エラー処理

- `readlink -f ~/.claude/skills` が失敗する（symlink 未設置環境）→ 発行を中止し、その旨を
  明示エラーとして報告する。
- `target`/`claim` のどちらかが確定できない → 発行しない（Step 2 の敷居）。
