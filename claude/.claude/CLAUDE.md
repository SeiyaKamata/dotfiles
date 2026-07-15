# Claude Code 設定

## ユーザーへの質問スタイル

ユーザーに確認・選択を求めるときは、すぐに回答できる形式にする：

- **2択**: `y/n` または `はい/いいえ`
- **多択**: 番号付きリスト
  ```
  1: ...
  2: ...
  3: ...
  ```
- 自由記述が必要な場合でも、典型的な選択肢を番号で並べて「その他」を最後に置く

開放的な質問（「どうしますか？」など）は避ける。

## コミット

コミットする際は必ず `/commit` スキルを使う。直接 `git commit` を実行しない。

## 用語集（開発パイプライン）

スキル間で用語を統一する。特に「フェーズ」と「工程」を混同しない。

| 用語 | 意味 |
|---|---|
| **工程 (stage)** | パイプラインの各段階＝各スキル（spec / design / tasks / impl / test / review / qa / commit / create-pr / …）。「工程に戻す」「工程を推定する」はこの意味。 |
| **フェーズ (phase)** | 実装を PR 単位に割った塊。**大タスク = フェーズ = ブランチ `pN` = 1 PR**。複数フェーズ = stacked PR。 |
| **大タスク / サブタスク** | tasks.md の 2 階層。**大タスク ≡ フェーズ**（1 PR）、その配下がサブタスク（実装の最小単位）。 |
| **stacked PR** | フェーズ（大タスク）を積み上げるブランチ運用（`pN` を `p(N-1)` にスタック）。 |
| **Step** | スキル内部の手順見出し。工程・フェーズとは別物。 |

## PR / ブランチ命名

命名メタは **`/notion-to-meta` スキル**が Notion の「Auto-generated Naming」から拾って `.specs/<feature>/meta.md` に保存する（Notion に触れるのはこのスキルだけ）。tasks が meta.md の `pr_title` を使ってフェーズごとの PR タイトルを確定し、tasks.md に明記する。ブランチ名は feature スラッグから素直に決める（Notion のブランチ名は使わず、meta.md に記録するだけ）。

- **固定 prefix**: `【鎌田QA】` — 全 PR タイトルの先頭に必ず付ける。
- **PR タイトル形式**: `【鎌田QA】<pr_title>[：<フェーズ内容>]（PR<N>/<M>）`
  - `<pr_title>`: meta.md の `pr_title`（例 `[SEC-16005] ATM Auth0移行`）。meta.md が無ければ自動生成タイトル。
  - `：<フェーズ内容>`: **stacked（総フェーズ数 M≥2）のときだけ**付ける。単一 PR では付けない。
  - `（PR<N>/<M>）`: **常に付ける**。`N`＝フェーズ番号、`M`＝総フェーズ数。単一なら `（PR1/1）`。
  - 例（stacked）: `【鎌田QA】[SEC-16005] ATM Auth0移行：ログイン基盤を追加（PR1/2）`
  - 例（単一）: `【鎌田QA】[SEC-16005] ATM Auth0移行（PR1/1）`
- **ブランチ名形式**: 単一 = `<feature>`、stacked = `<feature>-p1` / `-p2` …（`pN` を `p(N-1)` にスタック）。meta.md の `branch_name` は参考として記録するだけで、ブランチ作成には使わない。

### meta.md（`/notion-to-meta` が `.specs/<feature>/meta.md` に作成）

| 項目 | 例 | 備考 |
|---|---|---|
| `feature` | `atm-auth0` | `.specs/` ディレクトリ名 |
| `notion_url` | `https://app.notion.com/...` | 参照元の Notion ページ |
| `ticket_key` | `SEC-16005` | Notion から抽出 |
| `pr_title` | `[SEC-16005] ATM Auth0移行` | Notion の Pull Request Title |
| `branch_name` | `feature/SEC-16005/atm-auth0-migration` | Notion の Branch Name（記録のみ・未使用） |
