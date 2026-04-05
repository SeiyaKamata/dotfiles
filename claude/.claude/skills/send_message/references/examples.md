# sending-message: 使用例

## 基本的な使い方

```bash
./scripts/send_message.sh agent_b "タスクAが完了しました"
```

## タスク完了を通知する

```bash
./scripts/send_message.sh orchestrator "レビューが完了しました。承認をお願いします。"
```

## エラーを通知する

```bash
./scripts/send_message.sh orchestrator "ERROR: テストが失敗しました。詳細: test_login.rb line 42"
```

## 複数エージェントに送る

```bash
./scripts/send_message.sh agent_b "データの準備ができました"
./scripts/send_message.sh agent_c "データの準備ができました"
```
