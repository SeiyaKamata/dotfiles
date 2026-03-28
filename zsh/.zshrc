echo "[zshrc] loading ~/.zsh/*.zsh ..."
for config_file in $HOME/.zsh/*.zsh; do
  echo "[zshrc] source: $config_file"
  source $config_file
done
echo "[zshrc] done"

alias claude-mem='/Users/kamata_seiya/.bun/bin/bun "/Users/kamata_seiya/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
