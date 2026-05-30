#!/bin/bash

MESSAGE=$1

if [ -z "$MESSAGE" ]; then
  echo "ERROR: message is required" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../agent-protocol/scripts/parse_message.sh" "$MESSAGE"

echo "FROM:    $MSG_FROM"
echo "TYPE:    $MSG_TYPE"
echo "ACTION:  $MSG_ACTION"
echo "PAYLOAD: $MSG_PAYLOAD"

SEND_SH="$(dirname "$0")/../../send-message/scripts/send.sh"

case "$MSG_ACTION" in
  env-lock|env-unlock|impl-complete|*)
    "$SEND_SH" "$MSG_FROM" response "$MSG_ACTION" '{"message": "こんにちは"}'
    ;;
esac
