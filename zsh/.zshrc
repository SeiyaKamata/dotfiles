for config_file in $HOME/.zsh/*.zsh; do
  source $config_file
done

alias claude-mem='/Users/kamata_seiya/.bun/bin/bun "/Users/kamata_seiya/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
