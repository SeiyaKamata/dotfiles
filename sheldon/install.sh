# Install Zsh plugins manager
if command -v sheldon >/dev/null 2>&1; then
  echo "sheldon is already installed. skipping..."
else
  echo "Installing sheldon..."
  brew install sheldon
fi

# Copy configuration directory
echo "Copying sheldon configuration..."
mkdir -p ~/.config/sheldon
cp -r ~/config/sheldon/plugins.toml ~/.config/sheldon/plugins.toml
cp ~/config/sheldon/.p10k.zsh ~/.config/zsh/conf.d/p10k.zsh

echo "Completing sheldon configuration..."