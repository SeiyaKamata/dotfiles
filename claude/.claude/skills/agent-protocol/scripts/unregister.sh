#!/bin/bash

AGENT_NAME=$(basename "$PWD")

docker exec redis-container redis-cli DEL "agent:$AGENT_NAME"
echo "Unregistered: $AGENT_NAME"
