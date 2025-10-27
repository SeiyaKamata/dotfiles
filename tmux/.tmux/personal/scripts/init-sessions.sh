#!/bin/bash
# ================================
# tmux セッション初期化スクリプト
# ================================

# セッション一覧
sessions=("test")

for s in "${sessions[@]}"; do
  # すでにセッションが存在する場合はスキップ
  if tmux has-session -t "$s" 2>/dev/null; then
    echo "[tmux] Session '$s' already exists — skipped."
    continue
  fi

  echo "[tmux] Creating session: $s"

  case "$s" in
    test)
      tmux new-session -d -s "$s" -n test
      ;;
  esac
done
