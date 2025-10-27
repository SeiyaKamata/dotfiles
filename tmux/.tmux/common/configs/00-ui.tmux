# ペイン表示形式
set -g tree-format '  #{?pane_active,=> ,  }#{session_name}:#{window_index}.#{pane_index} #{window_name} #{pane_current_path}'

# ペインの開始番号を 0 から 1 に変更する
set-option -g base-index 1

# ステータスラインの文字色、背景色を変更
setw -g status-style fg=colour255,bg=colour234
