bind-key s display-popup \
  -d "#{pane_current_path}" \
  -w 60% \
  -h 60% \
  -E "$HOME/.local/bin/tmux-select-session"

bind-key w display-popup \
  -d "#{pane_current_path}" \
  -w 60% \
  -h 60% \
  -E "$HOME/.local/bin/tmux-select-window"

bind-key g display-popup \
  -d "#{pane_current_path}" \
  -w 95% \
  -h 95% \
  -E "lazygit -ucd ~/.config/lazygit"

bind-key d display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "lazydocker"

bind-key c display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "claude"

bind-key y display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "yazi"

bind-key v display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "vim"

bind-key z display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "$SHELL"
  
