---
name: sending-message
description: 指定したエージェントのRedisキューにメッセージを送信する。他のエージェントに情報・指示を渡したいときに使用する。
disable-model-invocation: true
---

# sending-message

指定エージェントのキューにメッセージを送信する。

## 使い方

```bash
./scripts/send_message.sh <agent_name> "<message>"
```

詳細な使用例は [references/examples.md](references/examples.md) を参照。
