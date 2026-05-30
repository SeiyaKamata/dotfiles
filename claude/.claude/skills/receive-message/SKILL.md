---
name: receive-message
description: 他のエージェントからtmux経由で受け取ったメッセージを解析し、actionに応じて処理する。メッセージが届いたときに使用する。
disable-model-invocation: true
---

# receive-message

受け取ったJSONメッセージを解析してactionを実行する。

メッセージフォーマットは [agent-protocol/README.md](../agent-protocol/README.md) を参照。

## 使い方

```bash
./scripts/receive.sh "<json>"
```

## actionごとの処理

| action | 処理 |
|--------|------|
| `env-lock` | 環境ロックを取得して切り替えを実行 |
| `env-unlock` | 環境ロックを解放 |
| `impl-complete` | 実装完了を記録・通知 |

## 返信

`from` フィールドのアドレスに `send.sh` で返信する。

```bash
../send-message/scripts/send.sh "$MSG_FROM" response <action> '{}'
```
