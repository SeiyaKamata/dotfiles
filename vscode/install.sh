MY_VSCODE_CNF_DIR="$HOME/config/vscode"
VSCODE_CNF_DIR="$HOME/Library/Application Support/Code/User"

ln -sf "$MY_VSCODE_CNF_DIR/keybindings.json" "$VSCODE_CNF_DIR/keybindings.json"
ln -sf "$MY_VSCODE_CNF_DIR/settings.json" "$VSCODE_CNF_DIR/settings.json"
