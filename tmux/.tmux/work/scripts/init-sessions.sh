#!/bin/bash
# ================================
# tmux セッション初期化スクリプト
# ================================

# セッション一覧
sessions=("ev2" "scratch" "seculio" "mysql")

for s in "${sessions[@]}"; do
  # すでにセッションが存在する場合はスキップ
  if tmux has-session -t "$s" 2>/dev/null; then
    echo "[tmux] Session '$s' already exists — skipped."
    continue
  fi

  echo "[tmux] Creating session: $s"

  case "$s" in
    # ------------------------
    # e-learning service 開発環境
    # ------------------------
    ev2)
      tmux new-session -d -s "$s" -n ev2
      tmux new-window  -t "${s}:" -n shell
      tmux new-window  -t "${s}:" -n front
      tmux new-window  -t "${s}:" -n back

      tmux send-keys -t "${s}:ev2"   'cd ~/Develop/elearning-service && npm run dev' C-m
      tmux send-keys -t "${s}:shell" 'cd ~/Develop/elearning-service' C-m
      tmux send-keys -t "${s}:front" 'cd ~/Develop/elearning-service/elearning-next' C-m
      tmux send-keys -t "${s}:back"  'cd ~/Develop/elearning-service/elearning-backend' C-m
      ;;

    # ------------------------
    # scratch セッション
    # ------------------------
    scratch)
      tmux new-session -d -s "$s" -n scratch
      ;;

    # ------------------------
    # seculio プロジェクト
    # ------------------------
    seculio)
      tmux new-session -d -s "$s" -n seculio
      tmux new-window  -t "${s}:" -n shell
      tmux send-keys   -t "${s}:shell" 'cd ~/Develop/seculio' C-m
      ;;

    # ------------------------
    # MySQL セッション
    # ------------------------
    mysql)
      tmux new-session -d -s "$s" -n mysql
      ;;

    # ------------------------
    # その他（未定義セッション）
    # ------------------------
    *)
      echo "[tmux] No definition for session: $s"
      ;;
  esac
done
