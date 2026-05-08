# ===== common =====
set -g status-interval 5
set -g status-justify centre
set -g status-style bg=default,fg=default

# ===== status-left =====
set-option -g status-left-length 100
set -g status-left "\
#[bg=#{E:@mode_bg},fg=#{E:@mode_fg}]#{E:@mode_text}\
#[bg=#{@accent},fg=#{E:@mode_bg}]#{@sep}\
#[bg=#{@accent},fg=#{@bg}] #S \
#[bg=#{@mid_bg},fg=#{@accent}]#{@sep} \
#[bg=#{@mid_bg},fg=#{@fg}]#{b:pane_current_path} \
#[bg=#{@bg},fg=#{@mid_bg}]#{@sep}\
"


# ===== status-right =====
set -g status-right-length 100
set -g status-right "\
#[bg=#{@bg},fg=#{@mid_bg}]#{@right_sep}\
#[bg=#{@mid_bg},fg=#{@fg}] %H:%M \
"


# ===== window status =====
setw -g window-status-format "\
#[bg=#{@win_bg},fg=#{@bg}]#{@sep}\
#[bg=#{@win_bg},fg=#{@bg}] #I:#W \
#[bg=#{@bg},fg=#{@win_bg}]#{@sep}\
"


# ===== current window status =====
setw -g window-status-current-format "\
#[bg=#{@win_active_bg},fg=#{@bg}]#{@sep}\
#[bg=#{@win_active_bg},fg=#{@bg},bold] #I:#W \
#[bg=#{@bg},fg=#{@win_active_bg}]#{@sep}\
"


