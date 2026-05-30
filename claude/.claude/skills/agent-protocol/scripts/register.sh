#!/bin/bash

AGENT_NAME=$(basename "$PWD")
PANE=$(tmux display-message -p "#{session_name}:#{window_index}.#{pane_index}")

docker exec redis-container redis-cli SET "agent:$AGENT_NAME" "$PANE"
echo "Registered: $AGENT_NAME -> $PANE"
