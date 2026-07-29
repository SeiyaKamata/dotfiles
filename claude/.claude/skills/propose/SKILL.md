---
name: propose
description: 各工程・PJからの改善提案の唯一の入口。skill / pipeline 改善の気づきを、規模に応じて kind: rule（一行のルールに落ちる）または kind: backlog（構成規模の改善）としてdotfilesの.specs/proposals/へ1件発行・記録する。再発判定はしない。
argument-hint: "[target] [claim...]"
allowed-tools: Bash(readlink *), Bash(ls *), Bash(test *), Bash(date *), Read, Write
---

# 提案発行スキル

## 役割
パイプラインの各工程・PJ が「これは skill / pipeline 側で改善すべきだった」と気づいたとき、恒久ルールに直接書かず、dotfiles の単一キュー `.specs/proposals/` へ改善提案を発行する**唯一の入口**。

**書き込みと検証のみを担う。** クラスタ判定・再発判定・寿命管理は持たない（単一実行では過去が見えないため原理的に持てない。それらは `/proposals-sweep` の責務）。

## 入出力
- **入力**: 引数（`target` / `claim`）、または直前の工程文脈から組み立てた気づき
- **出力**: `<dotfiles>/.specs/proposals/<YYYYMMDD-HHMMSS>-<target>-<claim-slug>.md` を**1 件だけ**

## モード
`auto` は持たない（各工程から呼ばれるが、発行そのものは常に同じ動作）。

**無確認実行**: 発行・記録の可否についてユーザーの事前承認を求めず、提案ファイルを書いて事後報告する。ただし `kind: backlog` を記録しても **`/spinoff` を自動起動しない**（着手は人が起動する）。

**恒久ルール（`CLAUDE.md`）へ勝手に追記しない。** 反映するかは人が判断する。

## 引数
- 第 1 引数: `target`（対象スキル名。例 `review`）
- 第 2 引数以降: `claim`（一行の主張）
- 省略時はプロンプト本文・直前の工程文脈から組み立てる。組み立てられなければ発行しない（Step 2 の敷居）

## 提案ファイルのスキーマ
frontmatter とその意味は次のとおり（**このスキルが正本**。`.specs/proposals/` 配下にスキーマ用ファイルは無く、この節が唯一の定義）。

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

**kind の語彙**
- **`rule`**: 一行足せば次回以降防げるルール
- **`backlog`**: 構成規模の skill / pipeline 改善（複数ステップの追加・ファイルの新設・スキル本体の修正が要る）

**target の語彙**（単一値のみ。リストは取らない）
- **スキル名**（例 `review` `commit` `handoff`）: 対象が 1 スキルに収まる
- **`CLAUDE.md`**: 恒久ルール宛
- **`pipeline`**: 複数スキル・ドキュメントに跨り代表を 1 つに絞れない backlog。使うときは対象群を本文に列挙する（frontmatter は単一値を保つ）

**claim の書き分け**
- **`rule`**: そのまま `CLAUDE.md` か対象スキルに追記できる一行。固有名詞を含めず一般化する。「一行で書けなければ発行しない」敷居は**rule にのみ適用**する
- **`backlog`**: 変更の主題の一行要約。追記可能な文である必要はなく、上記の敷居は適用しない

**backlog 本文に書く 2 点**: ①なぜ一行のルールでは足りないか ②触ることになる対象

## 進め方

### Step 1: 受付判定
気づきの種類を次の 5 分岐で判定する。判定は**カレント PJ に依存させない**（dotfiles 内で起動していても構成規模の気づきは backlog として記録する。「dotfiles で作業中なら `/spinoff`」という分岐は設けない）。

| 判定 | 行き先 |
|---|---|
| 一行のルールに落ちる（`CLAUDE.md` か対象スキルに 1 行足せば次回以降防げる） | Step 2 → `kind: rule` で発行 |
| 構成規模（複数ステップの追加・ファイルの新設・スキル本体の修正が要る） | Step 2 → `kind: backlog` で記録 |
| どちらか判別が付かない | `kind: backlog` で記録（**迷ったら backlog に倒す**） |
| skill / pipeline の改善ではなく**プロダクト側**のスコープ切り分け | 発行せず `/spinoff`（棚上げ）・`/handoff`（ブロッカー）を案内して中断 |
| 再発しない訂正（その場限りのタイポ・パス違い） | 何もせず終了 |

**完了ゲート:** 5 分岐のどれかに確定したか。

### Step 2: target・claim の確定（発行の敷居）
- `target`: スキル名・`CLAUDE.md`・`pipeline` のいずれか。引数または文脈から確定する
- `claim`: 「claim の書き分け」に沿って `kind` に応じた粒度で書く

**`claim` を一行で書けないときは発行しない。この敷居は `kind: rule` にのみ適用**し、`kind: backlog` には適用しない（backlog は主題の一行要約で足りるため）。

**完了ゲート:** `target`・`claim`・`kind` の 3 つが揃ったか（**1 つでも欠けていたら Write しない**）。

### Step 3: 書き出し

**3-1 キューの解決**

symlink からハードコードせず動的に解決する：

```bash
QUEUE_DIR="$(dirname "$(dirname "$(dirname "$(readlink -f ~/.claude/skills)")")")/.specs/proposals"
```

- `readlink -f ~/.claude/skills` → `.../dotfiles/claude/.claude/skills`、3 つ上 → `.../dotfiles`、そこに `/.specs/proposals` を付ける
- `readlink -f` が失敗する（symlink が張られていない環境）ときは、その旨を明示エラーとして報告し**発行を中止する**
- `test -d "$QUEUE_DIR"` で存在確認し、無ければ作成してよい

**3-2 ファイル名**

命名規則: `<YYYYMMDD-HHMMSS>-<target>-<claim-slug>.md`

- `date +%Y%m%d-%H%M%S` でタイムスタンプを得る
- `claim` を kebab-case 化し先頭数語を `claim-slug` とする
- `test -e` で衝突確認し、衝突していれば末尾に `-2` `-3` と連番を付ける（同一秒・同一 target の多重発行は稀だが保険）

**3-3 Write**

「提案ファイルのスキーマ」に従い、確定したファイル名に**1 件だけ**書く（`status: open`、`date` は当日、`source_feature` は発行元 feature 名か「不明」）。

**再発があるかは調べない。** 同種の提案が既にキューにあっても気にせず、毎回 1 件を投げるだけにとどめる（再発判定・クラスタ化は `/proposals-sweep` の責務）。

**完了ゲート:** 提案ファイルを 1 件 Write したか。

### Step 4: 出力

次の完了カードを**コードフェンスで囲まず**プレーンテキストで出力して終了する。カードの前後に作業サマリ・所感・補足を足さない。`/proposals-sweep` も `/spinoff` も**自動起動しない**。

✅ 提案発行完了
<kind と target と claim を 1 行>
- <主要な結果 最大 3 行>
📄 .specs/proposals/<提案ファイル>

次の一手:
▶ /proposals-sweep で再発を棚卸し（任意）

カードは**やったこと**（`✅` 〜 `📄`）・**次の一手**の 2 ブロックに分ける（発行内容は無確認で確定するが、`claim` 自体がその要約なので「要確認」は持たない）。

- やったこと: 一言サマリは 1 行（`kind`・`target`・`claim` を示す）。主要な結果は `- ` の箇条書きで**最大 3 行**（無ければ行ごと省略）。根拠の詳細は提案ファイルに書き、カードには列挙しない。
- 次の一手: **種別に応じて 1 行だけ**出す。
  - `kind: rule` → `▶ /proposals-sweep で再発を棚卸し（任意）`
  - `kind: backlog` → `▶ dotfiles で /spinoff <上記パス>（backlog を seed.md に詳細化）`

**中断時**（発行しなかった場合を含む）: ヘッダを `⚠ 提案発行中断` に差し替え、一言サマリに理由（`claim` を一行で書けない・プロダクト側のスコープ切り分け・symlink 未設置など）、次の一手に代わりの行き先（`▶ 棚上げする：/spinoff`、`▶ 依頼を投げる：/handoff`）を書く（ファイル未生成なので 📄 行は省略する）。

## エラー処理
- **`readlink -f ~/.claude/skills` が失敗する**（symlink 未設置環境）→ 発行を中止し、明示エラーとして報告する
- **`target` / `claim` のどちらかが確定できない** → 発行しない（Step 2 の敷居）

## 完了条件
次の 4 つの出口のいずれかに到達したら完了。**`kind` を確定できない状態では Write しない。**

- **rule 発行**: `kind: rule` で 1 件発行し、フルパスと `claim` を報告できた
- **backlog 記録**: `kind: backlog` で 1 件記録し、フルパスと `claim`・着手導線を報告できた
- **案内して終了**: プロダクト側のスコープ切り分けと判定し、発行せず `/spinoff`・`/handoff` を案内した
- **何もせず終了**: 再発しない訂正と判定し、どちらにも回さず終了した
