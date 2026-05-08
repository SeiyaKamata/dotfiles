# マウス操作を有効化
set-option -g mouse on

# コピーモード（vi）を有効化
set-window-option -g mode-keys vi

# OS が Darwin の時は pbcopy を使う
if-shell -b '[ "$(uname)" = "Darwin" ]' {
  set -s copy-command "pbcopy"
}

# copy-pipe と競合する場合があるので無効化
set -s set-clipboard off

# コピーモード中に Vim 風に v で選択範囲を定める
bind -Tcopy-mode-vi v send -X begin-selection

# コピーモード中に Vim 風に y で選択範囲をヤンクしてコピーモードを終了する
bind -Tcopy-mode-vi y send -X copy-pipe-and-cancel

# マウスをドラッグして選択範囲を定め、それをヤンクしてコピーモードを終了する
bind -Tcopy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel
