# Agent Protocol

Claude Code エージェント間通信プロトコル。tmux send-keys を使ってセッションをまたいだメッセージ送受信を行う。

## メッセージフォーマット

```json
{
  "from": "session:window.pane",
  "to": "session:window.pane",
  "type": "request | response | notify",
  "action": "env-lock | env-unlock | impl-complete | ...",
  "payload": {},
  "timestamp": "2026-05-10T12:00:00Z"
}
```

### type

| type | 説明 |
|------|------|
| `request` | 何かをやってほしい |
| `response` | request への返答 |
| `notify` | 通知のみ、返答不要 |

### action

| action | 説明 |
|--------|------|
| `env-lock` | 環境ロック要求 |
| `env-unlock` | 環境ロック解放 |
| `impl-complete` | 実装完了通知 |

## 返信

`from` フィールドのtmuxアドレスに対してそのまま返信する。

```bash
tmux send-keys -t <from> "<message>" Enter
```
