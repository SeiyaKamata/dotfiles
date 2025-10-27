# プレフィックスキーをctrl+jに変更
set -g prefix C-j

# デフォルトのプレフィックスキーctrl+bを解除
unbind C-b

# プレフィックスキー+^でペインを垂直分割する
bind ^ split-window -h

# プレフィックスキー+-でペインを水平分割する
bind - split-window -v
