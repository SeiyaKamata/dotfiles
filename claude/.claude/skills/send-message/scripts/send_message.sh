#!/bin/bash

if [ -z "$AGENT_NAME" ]; then
  echo "ERROR: AGENT_NAME is not set" >&2
  exit 1
fi

AGENT_TARGET=$1
MESSAGE=$2

if [ -z "$AGENT_TARGET" ]; then
  echo "ERROR: agent_name is required" >&2
  exit 1
fi

if [ -z "$MESSAGE" ]; then
  echo "ERROR: message is required" >&2
  exit 1
fi

docker exec redis-container redis-cli RPUSH queue:$AGENT_TARGET "$MESSAGE"
