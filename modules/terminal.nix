{ pkgs, config, ... }: {
  # alacrittyはhome.fileで設定ファイルをそのまま配置
  # programs.alacritty.settingsでは `import` キーが処理できないため
  programs.alacritty.enable = true;

  home.file.".config/alacritty/alacritty.toml".source =
    ../../alacritty/.config/alacritty/alacritty.toml;

  home.file.".config/alacritty/themes.toml".source =
    ../../alacritty/.config/alacritty/themes.toml;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../../tmux/.config/tmux/tmux.conf;
  };

  # tmux conf.d の各設定ファイルをhome.fileで配置
  home.file.".config/tmux/conf.d/00-core.conf".source =
    ../../tmux/.config/tmux/conf.d/00-core.conf;
  home.file.".config/tmux/conf.d/10-terminal.conf".source =
    ../../tmux/.config/tmux/conf.d/10-terminal.conf;
  home.file.".config/tmux/conf.d/20-style.conf".source =
    ../../tmux/.config/tmux/conf.d/20-style.conf;
  home.file.".config/tmux/conf.d/30-status.conf".source =
    ../../tmux/.config/tmux/conf.d/30-status.conf;
  home.file.".config/tmux/conf.d/40-keymaps.conf".source =
    ../../tmux/.config/tmux/conf.d/40-keymaps.conf;
  home.file.".config/tmux/conf.d/50-mouse-copy.conf".source =
    ../../tmux/.config/tmux/conf.d/50-mouse-copy.conf;

  # lazydockerの設定をhome.fileで管理
  home.file.".config/lazydocker/config.yml".source =
    ../../lazydocker/.config/lazydocker/config.yml;
}
