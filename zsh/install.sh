# Copy configuration directory
cp -r ~/config/zsh/.zshrc ~/.zshrc
cp -r ~/config/zsh/conf.d ~/.config/zsh/

ZSH_PATH="/bin/zsh"

echo "Setting zsh as default shell..."
echo $ZSH_PATH | sudo tee -a /etc/shells
chsh -s $ZSH_PATH