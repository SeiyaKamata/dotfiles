---
name: retro
description: 1日の終わりにClaude Codeの全セッションログを横断的に読み込み、KPT形式でレトロスペクティブを行う。skill化候補・CLAUDE.mdへの追記・memory.mdへの保存・指示の出し方の改善を提案する。
disable-model-invocation: true
allowed-tools: Bash(bash *) Bash(chmod *)
argument-hint: [YYYY-MM-DD]
---

# /retro - KPT レトロスペクティブ

1日の終わりに全プロジェクトのClaude Codeセッションを横断的に振り返り、明日に繋げる。

## 実行手順

### Step 1: ログを収集する

引数があればその日付、なければ今日を対象にする。

```!
chmod +x "${CLAUDE_SKILL_DIR}/scripts/collect_logs.sh"
bash "${CLAUDE_SKILL_DIR}/scripts/collect_logs.sh" --skill-dir "${CLAUDE_SKILL_DIR}" "${ARGUMENTS:-}"
```

上記の出力が `NO_LOGS_FOUND` の場合は「本日のClaude Codeセッションが見つかりませんでした」と伝えて終了する。

### Step 2: KPT形式で分析する

収集したログをもとに以下の観点で分析する。

**Keep ✅ — 上手くいったこと・続けること**
- 効果的だった指示パターン
- スムーズに進んだ作業フロー

**Problem ⚠️ — 問題・改善すべき点**
- 手戻りが起きた箇所
- 指示が曖昧で意図が伝わらなかった点
- 同じことを繰り返し説明した場面

**Try 🚀 — 明日試すこと**

| カテゴリ | 内容 |
|---|---|
| skill化候補 | 繰り返し使ったパターン・手順 |
| CLAUDE.mdに追加 | プロジェクト固有のルール・コンテキスト |
| memory.mdに追加 | 汎用的な知識・設定・好み |
| 指示の出し方の改善 | より明確に伝えられた表現 |

### Step 3: 出力する

以下のフォーマットで出力する。

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  KPT レトロ - YYYY-MM-DD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Keep ✅
- ...

## Problem ⚠️
- ...

## Try 🚀
### skill化候補
- ...
### CLAUDE.mdに追加
- ...
### memory.mdに追加
- ...
### 指示の出し方の改善
- ...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 4: アクションを確認する

出力後、ユーザーに確認する。

- 「skill化するものはありますか？」
- 「CLAUDE.mdに追記しますか？」
- 「memory.mdに追記しますか？」

「はい」と言ったものはそのまま続けて実行する。

## 補足

- セッションが終了していなくてもタイムスタンプで当日分を抽出できる
- 複数アカウント・複数プロジェクトを横断して一度に振り返れる
