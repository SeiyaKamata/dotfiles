# dotfiles

My dotfiles managed with GNU Stow and Make.


## Ready
Install Homebrew manually first:
https://brew.sh/ja/



## Setup


```bash
git clone <YOUR_REPO_URL> ~/dotfiles
cd ~/dotfiles
make setup
```


## Usage

Stow all configs:
```bash
make stow-all
```

Stow a specific config:
```bash
make zsh
make tmux
```

Reload configs:
```bash
make reload-zsh
make reload-tmux
make reload-sheldon
```

Update Brewfile:
```bash
make brew-dump
```
