#!/bin/bash

if [ -z "$AGENT_NAME" ]; then
  echo "ERROR: AGENT_NAME is not set" >&2
  exit 1
fi

message=$(docker exec redis-container redis-cli LPOP queue:$AGENT_NAME)
if [ -n "$message" ]; then
  echo "$message"
fi
