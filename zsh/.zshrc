echo "[zshrc] loading ~/.zsh/*.zsh ..."
for config_file in $HOME/.zsh/*.zsh; do
  echo "[zshrc] source: $config_file"
  source $config_file
done
echo "[zshrc] done"
