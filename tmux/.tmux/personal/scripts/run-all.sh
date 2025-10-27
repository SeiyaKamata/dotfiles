#!/bin/bash
for f in "$HOME"/.tmux/personal/scripts/*.sh; do
  [ -f "$f" ] && [ "$f" != "$HOME/.tmux/personal/scripts/run-all.sh" ] && "$f"
done
