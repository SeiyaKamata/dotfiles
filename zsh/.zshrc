for config_file in $HOME/.zsh/*.zsh; do
    [[ $config_file == "$HOME/.zsh/.p10k.zsh" ]] && continue
    source $config_file
done

[[ -f ~/.zsh/.p10k.zsh ]] && source ~/.zsh/.p10k.zsh
