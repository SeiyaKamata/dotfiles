#!/bin/bash
# Usage: source parse_message.sh "<json>"
# Exports: MSG_FROM, MSG_TO, MSG_TYPE, MSG_ACTION, MSG_PAYLOAD, MSG_TIMESTAMP

MESSAGE=$1

if [ -z "$MESSAGE" ]; then
  echo "ERROR: message is required" >&2
  exit 1
fi

MSG_FROM=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('from',''))")
MSG_TO=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('to',''))")
MSG_TYPE=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('type',''))")
MSG_ACTION=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('action',''))")
MSG_PAYLOAD=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('payload',{})))")
MSG_TIMESTAMP=$(echo "$MESSAGE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('timestamp',''))")

export MSG_FROM MSG_TO MSG_TYPE MSG_ACTION MSG_PAYLOAD MSG_TIMESTAMP
