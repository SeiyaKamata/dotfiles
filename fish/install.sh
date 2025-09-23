#!/bin/bash

# Install fish shell
brew install fish

# Create fish config directory if it doesn't exist
mkdir -p ~/.config/fish

# Copy fish configuration
cp ~/config/fish/config.fish ~/.config/fish/config.fish

# Copy configuration directory
cp -r ~/config/fish/conf.d ~/.config/fish/

# Use Homebrew's fish path for Apple Silicon Macs
FISH_PATH="/opt/homebrew/bin/fish"

# Check if fish path exists, fallback to Intel Mac path
if [ ! -f "$FISH_PATH" ]; then
    FISH_PATH="/usr/local/bin/fish"
fi

# Set fish as the default shell
echo "Setting fish as default shell..."
echo $FISH_PATH | sudo tee -a /etc/shells
chsh -s $FISH_PATH

echo "Fish setup complete! Please restart your terminal or run 'exec fish' to start using fish."