---
name: pipeline
label: dev-pipeline を回す
deliverable: pipeline
scope: [single, chain]
observed: 24
signals:
  - dev-pipeline / DP / パイプライン / 番人 / 起票 / カード
  - 「パイプライン回して」「人間ゲートまで進めて」「差し戻したから続けて」
not_this_when:
  - パイプラインを使わず直接実装してほしい → ship
  - パイプラインそのものを改修する → harness
done_when: カードが人間ゲートに到達しているか、needs_human で正しく止まっている
---

# pipeline — dev-pipeline を回す

**このモードは `dev-pipeline-drive` スキルに委ねる。** 手順をここに書き写さない。

## 委ねる理由

番人ループ (issuer / worker / spec-reviewer / reviewer) の手順は既に `dev-pipeline-drive` が持っている。二重管理にすると、番人スキル側の更新がこちらに反映されず食い違う。

## ルーターがやること

1. `dev-pipeline-drive` を起動する
2. 契約ファイルには `mode: pipeline` と対象カードだけ書く。工程の詳細は書かない (パイプライン側が持つ)
3. 完了判定は「人間ゲートに到達」または「needs_human で停止」

## 不変のルール

- **番人 = メイン会話は直接作業しない。** 実作業は必ずサブエージェントに委譲する
- メイン会話はパイプライン MCP を直接叩かない。巨大な payload を読み込まない
- やり直しは起票工程から

## 落とし穴

| 失敗 | 原因 | 対策 |
| --- | --- | --- |
| メイン会話で payload を読み込んで文脈を埋めた | 手回ししたくなった | `dev-pipeline-drive` に乗せる。兆候があれば止める |
| サブエージェントの出力を自己判断で集約・簡略化した | 「まとめたほうが読みやすい」と考えた | 計画通りに実行する。疑問があれば変更せずユーザーに確認する |
