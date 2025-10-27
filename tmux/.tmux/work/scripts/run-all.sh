#!/bin/bash
for f in "$HOME"/.tmux/work/scripts/*.sh; do
  [ -f "$f" ] && [ "$f" != "$HOME/.tmux/work/scripts/run-all.sh" ] && "$f"
done
