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
  -E "tmux select-window -t codex || tmux display-message 'codex window not found'"

bind-key a display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "claude"

bind-key y display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "yazi"

bind-key r display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "gh dash"

bind-key z display-popup \
  -d "#{pane_current_path}" \
  -w 80% \
  -h 80% \
  -E "$SHELL"
  
