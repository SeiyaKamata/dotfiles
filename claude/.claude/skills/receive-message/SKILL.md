---
name: receive-message
description: 他のエージェントからtmux経由で受け取ったメッセージを解析し、actionに応じて処理する。メッセージが届いたときに使用する。
disable-model-invocation: true
---

# receive-message

受け取ったJSONメッセージを解析してactionを実行する。

メッセージフォーマットは [agent-protocol/README.md](../agent-protocol/README.md) を参照。

## actionごとの処理

### env-lock
環境ロックを取得してマウントを切り替える。

1. ロック中かどうかを確認する（`/tmp/env.lock` が存在するか）
2. **ロック中の場合**: 送信元に `busy` を返す
   ```
   send-message で <from> に返信:
     type: response / action: env-lock / payload: {"status": "busy"}
   ```
3. **空きの場合**:
   - `/tmp/env.lock` にworktree名を書き込む
   - プロジェクトルートの `switch-workspace.sh <worktree>` を実行する
   - 送信元に `ready` を返す
   ```
   send-message で <from> に返信:
     type: response / action: env-lock / payload: {"status": "ready"}
   ```

### env-unlock
環境ロックを解放する。

1. `/tmp/env.lock` を削除する
2. 送信元に完了を返す
   ```
   send-message で <from> に返信:
     type: response / action: env-unlock / payload: {"status": "released"}
   ```

### impl-complete
実装完了の通知を受け取る。

1. 完了をユーザーに報告する
2. 送信元に受信確認を返す
   ```
   send-message で <from> に返信:
     type: response / action: impl-complete / payload: {"status": "received"}
   ```

## 返信の共通形式

```
send-message <from> response <action> '<payload>'
```
