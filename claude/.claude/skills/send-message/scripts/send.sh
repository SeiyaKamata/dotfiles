#!/bin/bash

TO=$1
TYPE=$2
ACTION=$3
PAYLOAD=${4:-\{\}}

if [ -z "$TO" ] || [ -z "$TYPE" ] || [ -z "$ACTION" ]; then
  echo "Usage: send.sh <to> <type> <action> [payload]" >&2
  exit 1
fi

# tmuxアドレス形式でなければエージェント名としてRedisから解決
if [[ "$TO" != *":"* ]]; then
  TO=$(docker exec redis-container redis-cli GET "agent:$TO")
  if [ -z "$TO" ]; then
    echo "ERROR: エージェントが見つかりません: $1" >&2
    exit 1
  fi
fi

FROM=$(tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

TMP=$(mktemp /tmp/send-payload-XXXXXX.json)
trap "rm -f $TMP" EXIT

python3 -c "
import json
with open('$TMP', 'w') as f:
    json.dump({
      'from': '$FROM',
      'to': '$TO',
      'type': '$TYPE',
      'action': '$ACTION',
      'payload': json.loads('$PAYLOAD'),
      'timestamp': '$TIMESTAMP'
    }, f, ensure_ascii=False)
"

MESSAGE=$(cat "$TMP")

tmux send-keys -t "$TO" -l "/receive-message $MESSAGE"
tmux send-keys -t "$TO" Enter
