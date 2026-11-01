---
name: memory-to-skill
description: auto-memory を「過去事故の再発防止 / PJ固有tribal / 参照情報」だけに純化し、それ以外を既存skill・CLAUDE.md・新設skillへ移行するスキル。「memory整理」「memory見直し」「memoryをskillに移行」「memoryを既存skillに組み込む」「memoryが肥大化してきた」「auto-memory見直し」のような依頼、または memory ディレクトリが20件超になった・特定skillとmemoryで責務が重複していると気付いた時に必ず発火する。memoryを軽量化したい時の主軸スキル。
---

# memory-to-skill

auto-memory (`~/.claude/projects/<encoded-path>/memory/`) を点検し、適切な移行先へ振り分けて memory を軽量化するスキル。

## なぜ memory を整理する必要があるか

auto-memoryは「会話開始時にMEMORY.mdが自動ロードされる」「該当memoryをClaudeが必要と判断した時のみ中身が読まれる」という挙動。これは「**引かれるとは限らない二次資料**」であることを意味する。一方 skill は「特定の発火条件で必ず読まれる」一次資料。

つまり memory に置いても **読まれない** 内容と、skill に置けば **必ず効く** 内容が混在している。これを定期的に振り分けないと:

- memory が肥大化してインデックスから索引するのが遅くなる
- 同じルールが skill / CLAUDE.md / memory の3箇所に散らばって二重管理になる
- 進捗系スナップショット (Phase N 完了 / PR #N マージ済み等) が陳腐化したまま残り、誤った前提で動く

## memory に残すべきもの (3カテゴリだけ)

memory に残すのは以下3カテゴリだけ。それ以外は移行・削除対象。

1. **過去事故の再発防止** — 強く叱責された経験 / 障害ベースの教訓 / 構造的に再発しうる失敗パターン
2. **PJ固有tribal knowledge** — そのPJで作業する人だけが知るべき非自明な事実 (リネーム履歴 / 略称対応 / 隠れた制約)
3. **参照情報** — ログインの手順と使うアカウント名 / API名の誤解防止 / 動作するbotリスト / 特定セレクタなど、再調査コストが高くて固定された事実

   **ただしパスワード・token・API key・cookie・セッション情報そのものは置かない。** memory は毎セッション自動で
   読み込まれるので、置いた秘密はそれ以降の全部の会話に載り続ける。置くのは「どこを見れば分かるか」
   (秘密の管理場所・環境変数の名前・アカウント名) までにする。

## いつ発火するか

- ユーザーが「memory見直したい」「memory整理して」「memory→skill移行」「memoryをskillに組み込みたい」のような依頼を出した時
- memory ディレクトリ全体が20件を超えた時
- ある memory を見て「これ `/recipient-centric:commit` skill 内で読まれるべきでは」「これ `pr-create` skill の手順5に組み込めば memory 不要では」と気付いた時
- 既存skillとmemoryで責務が重複していると気付いた時

## 評価軸

memory 1件ごとに以下のどれに該当するか判定する。

| カテゴリ | 判定 | 移行先 |
|---|---|---|
| 過去事故の再発防止 | 残す | memory(現在地維持) |
| PJ固有tribal knowledge | 残す | memory(PJ別 or dev) |
| 参照情報 (URL/認証情報/API名誤解防止) | 残す | memory |
| 特定skill実行時にだけ効く運用ルール | **既存skill組込** | skill の SKILL.md |
| 汎用ルールで CLAUDE.md 相当 | **CLAUDE.md組込 or 削除** | `${CLAUDE_PROJECT_DIR}/CLAUDE.md` |
| 新しい workflow を構造化したい | **新設skill** | skill-creator経由 |
| 「仕事の進め方そのもの」が既存モードのどれにも収まらない | **新設モード** | `${CLAUDE_PLUGIN_ROOT}/skills/dispatch/modes/<name>.md` (この拡張の中) |
| 進捗系・完了済プロジェクトのスナップショット | 削除 | — |
| 特定PJで起動時のみ必要な内容 | PJ別memoryへ移動 | PJ memory |
| 横断PJで効くがPJ memoryに置かれている | dev memoryへ移動 | dev memory |
| CLAUDE.md / 他skillと内容重複 | 削除 | — |

### 判別ルール: 既存skill組込 vs CLAUDE.md寄せ vs memory据置

「特定skill実行時にだけ効く運用ルール」と「汎用ルール = CLAUDE.md相当」の境界が曖昧な時は、**発火条件の包含関係**で判別する:

- **memo の発火条件 ⊆ skill の発火条件**(memo発火範囲がskill発火範囲に内包される)→ **既存skill組込**。skillが走る時に必ず読まれるので memory 不要
- **memo の発火条件 ⊃ skill の発火条件**(memo発火範囲のほうが広い)→ **CLAUDE.md寄せ or memory据置**。skill外でも適用したいルールなのでskillに閉じ込めない
- **memo の発火条件 = CLAUDE.md ロード条件 (会話開始時、横断適用)** かつ **CLAUDE.md にまだ無い** → **CLAUDE.md組込**

例:
- 「pr-create 実行時、PRテンプレを find で全件取る」→ pr-create 発火時のみ → **pr-create skill 組込**
- 「コード変更したら全箇所動作確認」→ コミット時にも PR時にも レビュー対応時にも適用 → skill より広い → **CLAUDE.md寄せ or memory据置**
- 「コミット時は必ず /recipient-centric:commit を使う」→ コミット = /recipient-centric:commit 発火条件と完全一致 → **commit skill 組込 or CLAUDE.md** (どちらも合理的、skill 内に閉じ込めると skill 起動前のユーザー指示には届かないので CLAUDE.md 寄せが多い)

### 判別ルール: 新設skill vs 新設モード

境界は「**何をするか**の手順が新しいのか、**どう任されているか**の型が新しいのか」で切る。

- **新設skill** — 特定の作業をやるときの手順が新しい (例: スカウト文を書く、PR ドキュメントを作る)。呼ばれて働き、終わったら返る
- **新設モード** — 仕事の**任され方**が新しい。`dispatch` スキルの `modes/` は「成果物 × 到達範囲 × 立会い」の 3 軸でできているので、**成果物の種類が既存 6 種のどれでもない**ときだけ足す

既存の成果物は `pr` / `finding` / `doc` / `review` / `harness` / `pipeline` の 6 種。次を順に問う。

1. その仕事の**終わりの形**は 6 種のどれかに当てはまるか → 当てはまるなら既存モードに追記する (新設しない)
2. 当てはまらないとして、それは**到達範囲**や**立会い**の違いにすぎないのではないか → 軸の値の違いは新設理由にならない
3. 1 と 2 を通ってなお収まらないなら新設する。`modes/` の既存ファイルと同じ frontmatter と本文構成 (実例 / プレイブック / 完了判定 / 落とし穴表) に揃える

frontmatter は `name` / `label` / `deliverable` / `scope` / `signals` / `not_this_when` / `done_when`。dispatch のルーターがこれを読んで判定する。

**新設モードは skill を兼ねない。** モード定義は「何をどこまでやるか」を書く場所で、細かい手順は既存 skill を呼ぶ。手順をモード定義に書き写すと二重管理になる (`pipeline.md` が `dev-pipeline-drive` に委ねているのがその形)。

## 手順

### Step 1: 全 memory 一覧化

PC全体のmemoryディレクトリを発見し、各ディレクトリの件数とMEMORY.md内容を把握する。

```bash
find ~/.claude/projects -maxdepth 3 -type d -name memory 2>/dev/null
```

各ディレクトリで:

```bash
ls -la <memory-dir>/
cat <memory-dir>/MEMORY.md 2>/dev/null
```

特定ディレクトリだけ対象にしたい場合(「dev memoryだけ見たい」等)、ユーザーに範囲を確認する。

### Step 2: 全 skill 一覧化

評価対象のmemoryが発火する文脈で、どのskillが走るかを把握する。

主要な skill 配置場所(dev起動時に発火するもの):

```bash
echo "=== ~/dev/.claude/skills/ (project-level skills for /dev) ==="
ls "${CLAUDE_PROJECT_DIR}/.claude/skills/"

echo "=== ~/.claude/skills/ (user-installed global) ==="
ls ~/.claude/skills/

echo "=== ~/.claude/commands/ (slash commands) ==="
ls ~/.claude/commands/

echo "=== ~/.claude/plugins/.../skills/ (plugin skills) ==="
find ~/.claude/plugins -type d -name skills 2>/dev/null
```

会話履歴の system-reminder にある「available skills」リストも一次情報源として有用。各 skill の SKILL.md(または .md)の description を読んで責務を要約する。

**全件 SKILL.md 実 Read は不要**。description だけで責務把握できれば十分で、**組込候補として有力な skill** (memo の発火条件と一致しそうなもの) のみ実 Read で組込先 Step/Phase を特定する。例: PR タイトル系 memo なら `pr-create.md` だけ実 Read、コミット系 memo なら `commit/SKILL.md` だけ実 Read。これで Step 2 の token 消費を1〜2 file Read に抑えられる。

特定 PJ memoryを評価する時は、そのPJの `.claude/skills/` も把握対象に追加(例: `~/dev/elearning-service/.claude/skills/`)。

### Step 3: 各 memory を評価軸で分類

memory 1件ずつ中身を Read で確認し、評価軸の表に当てはめる。判定基準:

- **既存skill組込候補**: memory の "How to apply" が「`/<skill名>` 実行時には〜する」のような形式、または特定skillの発火条件と memory の発火条件が一致 → そのskillのSKILL.mdに組み込めば memory 不要になる
- **CLAUDE.md重複**: `${CLAUDE_PROJECT_DIR}/CLAUDE.md` の節と内容が重なる → 削除 or CLAUDE.md 補強。memo自身に「CLAUDE.md に正式版あり」と書かれている時は強い削除シグナル
- **新設skill候補**: 複数のmemoryが同じworkflowについて語っており、かつ既存skillに該当するものがない → 新設skill検討、`skill-creator` 起動を提案
- **進捗系**: 「完了」「進行中」「未着手」「Phase N」「PR #NNNN」「次セッションで再開」のような状態スナップショット表現が主軸
- **PJ固有 vs 汎用**: 「ev2固有」「phr固有」「Group 1」のような注記、または特定PJコードベース依存。汎用化できるなら dev に上げる、できないなら PJ memory のまま

### Step 4: 推奨アクション提示

ユーザーに以下のテーブル形式で提示。**自信度(%)を必ず併記**する(CLAUDE.md ルールにより90%未満なら追加調査)。

```markdown
## <memory dir> 評価結果

### A. 削除 (N件) — 完了済み進捗 + 重複
| ファイル | 削除根拠 |
|---|---|

### B. dev に移動 (N件) — 汎用化可能
| ファイル | 汎用化の根拠 |
|---|---|

### C. 既存skill組込 (N件)
| ファイル | 組込先skill | 組込箇所 |
|---|---|---|

### D. 新設skill候補 (N件)
| ファイル群 | 新設skill名 | 責務 |
|---|---|---|

### E. 残す (N件) — 過去事故 / PJ固有 / 参照情報
| ファイル | 残す根拠 |
|---|---|

## 自信度: NN%
## 確認事項: <判断分岐がある項目>
```

### Step 5: ユーザー判断を仰ぐ

判断分岐(複数案がある項目)は **A案/B案/C案** で明示的に提示。明確な判定はそのまま実行案として提示し YES/NO を取る。

ユーザーは「順次確認」を希望することが多い。**ディレクトリ単位** で1つずつ確認を取り、消化してから次のディレクトリに進むのが安全。memoryディレクトリが複数あるなら、最初に「どの順で進めるか」を提示する。

ディレクトリ内のカテゴリが複数ある時は、**リスクの高いアクションから先に確認** する順序: A(削除) → C(既存skill組込) → D(新設skill) → B(dev移動) → E(残す)。理由は (1) 削除は不可逆で確認重要度が最高、(2) skill組込は他skillの責務に影響するので削除の次に重要、(3) 残すアクションは確認の必要性が低い。1ディレクトリで件数が多い時は「カテゴリ単位でまとめて YES/NO」を提案、件数が少ない時は「ディレクトリ単位で全件まとめて YES/NO」を提案する。

### Step 6: 実行

承認されたアクションを実行する。アクション種類別の実装パターン:

#### 既存skill組込

skillのSKILL.mdに追記する。**組込箇所(どの手順/Phase/節)を明示**してからEditする。

```
1. 該当 skill の SKILL.md を Read
2. 組込箇所を判断 (skill の手順構造から、memoryの発火条件と一致する Step/Phase を選ぶ)
3. Edit で追記。CLAUDE.md と重複する内容は再掲せず「CLAUDE.md の X セクション参照」で済ます
4. memory ファイルを rm で削除
5. MEMORY.md(index)から該当行を Edit で削除
```

#### 新設skill

`skill-creator` skill を起動するか、ユーザーが具体的な要求を出している場合は直接 SKILL.md を Write で作成する。

#### CLAUDE.md組込

`${CLAUDE_PROJECT_DIR}/CLAUDE.md` (or 該当PJ CLAUDE.md) に Edit で追記。プロジェクト共有のCLAUDE.mdに個人運用を入れない原則を守る(個人運用は CLAUDE.local.md へ)。

#### memory削除

```bash
rm <memory-file>
```

加えて MEMORY.md(index)の該当行を Edit で除去。

#### memory移動 (PJ別 ↔ dev、または PJ別同士)

```
1. 移動先で Write でファイル作成 (frontmatter整備、汎用化の場合は内容微修正)
2. 両側のMEMORY.md(index)を Edit で更新
3. 元のファイルを rm
```

複数件まとめて移動する時も、**1 件ずつ順に実行する。並列にしない。**

移動は「移動先を書く → 両方の index を直す → 元を消す」の 3 段だが、これはひとつの操作として
まとまっていない。並列にすると、書き込みが失敗したのに元だけ消える順序が起こりうる。
**移動先を書いて存在を確かめ、両方の index を直して確かめ、そのあとで元を消す。**

## 重要な原則

### memory と skill と CLAUDE.md の役割分担

| 場所 | 役割 | 強制ロード | 適切な内容 |
|---|---|---|---|
| memory | 二次資料 | 索引のみ自動、本文は Claude の判断 | 過去事故 / PJ tribal / 参照情報 |
| skill | 一次資料 | 発火条件で必ず読まれる | 特定状況の運用ルール / workflow |
| CLAUDE.md | 一次資料 | 会話開始時に必ず読まれる | プロジェクト共通規約 / 略称表 |
| CLAUDE.local.md | 一次資料(個人スロット) | 会話開始時に必ず読まれる | 個人運用 / .gitignore配下 |

「**状況が決まれば必ず守るべきルール**」は skill か CLAUDE.md に置く。memory に置くと引かれない可能性がある。

### CLAUDE.md と skill との二重管理を避ける

skill 内で CLAUDE.md と同じルールを再掲すると、CLAUDE.md 側を更新したのに skill 側が古いまま、という不整合が起きる。重複箇所は skill 側で「`CLAUDE.md` の X セクション参照」と書いて参照のみにする。

### 進捗系の判別シグナル

以下の表現を含む memory は進捗系の可能性が高く、削除推奨:

- 「Phase N 完了」「Phase N 未着手」
- 「PR #NNNN マージ済み」「PR #NNNN マージ予定」
- 「進行中」「次セッションで再開」「最終: ...完了」
- ファイル一覧 / コミット計画 / 実装状況テーブル
- 「v3 → v4 移行調査」のような完了したマイグレーション作業ノート

進捗系の正本は **spec / .work / .kiro / git log / PR description** にあるべきで、memoryに置くと陳腐化する。

ただし「次セッションで再開」「進行中」マーカー付き **未完了作業ノート** は注意。即削除すると作業途中の文脈が失われる可能性があるので、削除前に `.work/<日付>_<トピック>/` 等の正本ストレージへ退避してから削除する。退避が不要 (ユーザーが「もう触らない」と明言、または内容が完全に陳腐化) な場合のみ即削除。判断に迷ったら **削除せずユーザーに確認** が安全側。

### 「PJ固有」と「汎用化可能」の判別

PJ memory にある feedback は **「そのPJの作業中に発見された普遍ルール」** が紛れ込んでいることが多い。「ev2 起点だけど他PJでも効く」「phr 案件で叱られたけど内容は技術全般」というケースは dev memory に格上げする。

判別の問い: 「**この memory の本質は ev2 のコードに紐付くか、それともコード非依存の運用ルールか**」。後者なら dev に上げる。

### 削除前のリカバリ可能性

memory を削除すると復元できないので、迷ったら削除前にバックアップを取る:

```bash
cp <memory-file> /tmp/memory-backup-$(date +%Y%m%d-%H%M%S)-$(basename <memory-file>)
```

ユーザーが「全削除」と明示した時はバックアップ不要。判断が曖昧な時だけ取る。

### MEMORY.md(index)同期

memory ファイルを削除・移動した後、必ず MEMORY.md からも該当行を Edit で削除する。MEMORY.md は会話開始時に index としてロードされるので、不整合があるとリンク切れの参照が混入する。

複数件削除する時は MEMORY.md の Edit を1回で済ませず、各削除ごとに Edit を分けるか、`replace_all` を使わず該当行を一意に特定して安全に消す。

## 典型的なユーザーやり取りの流れ

1. ユーザー: 「memory整理したい」
2. Claude: Step 1-3 を実行、評価表を提示、Step 4 で推奨アクションを テーブル形式で出す
3. ユーザー: 「順次確認したい」「これは新設skillにしよう」「これは削除でいい」等の判断を返す
4. Claude: ディレクトリ単位 or アクション単位で実行 → 完了報告
5. 次のディレクトリ / 次のアクション → 繰り返し
6. 全完了後にサマリー(Before/After件数 / 削除総数 / skill組込内容)を提示

## アンチパターン

- 「全部に組み込める」と楽観的に判断して memory 全削除を提案する → 失われる事故記録がある
- skill description を読まず「これ `/recipient-centric:commit` に組み込めそう」と推測する → skill の発火条件と memory の発火条件が実は違う
- MEMORY.md の Edit を忘れて memory ファイルだけ削除する → index が壊れる
- バックアップなしで判断曖昧な memory を一気に削除する → 後悔
- 進捗系を残す方向に倒す → 陳腐化メモが累積し、Claude が古い前提で動く

## 関連スキル

- `skill-creator`: 新設skillの作成時に起動
- `update-config`: settings.json 経由で hook を仕込む必要が出た時 (memory 関連 hook など)
