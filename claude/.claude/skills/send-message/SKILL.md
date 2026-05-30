---
name: send-message
description: 指定したエージェント（tmuxペイン）にメッセージを送信する。他のエージェントに情報・指示を渡したいときに使用する。
disable-model-invocation: true
---

# send-message

指定エージェントのtmuxペインにメッセージを送信する。

メッセージフォーマットは [agent-protocol/README.md](../agent-protocol/README.md) を参照。

## 使い方

```bash
./scripts/send.sh <to> <type> <action> [payload]
```

- `to`: 送信先のtmuxアドレス（例: `main:1.0`）
- `type`: `request` | `response` | `notify`
- `action`: `env-lock` | `env-unlock` | `impl-complete` | ...
- `payload`: JSON文字列（省略時は `{}`）

## 例

```bash
# 環境ロック要求
./scripts/send.sh "main:1.0" request env-lock '{}'

# 実装完了通知
./scripts/send.sh "main:1.0" notify impl-complete '{"feature": "feature-a"}'
```
