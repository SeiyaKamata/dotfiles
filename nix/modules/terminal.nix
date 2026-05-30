{ pkgs, config, lib, dotfilesRoot, ... }: {
  # alacrittyはmacOS向け（home.fileで設定ファイルをそのまま配置）
  # programs.alacritty.settingsでは `import` キーが処理できないため
  programs.alacritty.enable = lib.mkIf pkgs.stdenv.isDarwin true;

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile "${dotfilesRoot}/tmux/.config/tmux/tmux.conf";
  };

  home.file = lib.mkMerge [
    # alacritty設定はmacOSのみ
    (lib.mkIf pkgs.stdenv.isDarwin {
      ".config/alacritty/alacritty.toml".source =
        "${dotfilesRoot}/alacritty/.config/alacritty/alacritty.toml";
      ".config/alacritty/themes.toml".source =
        "${dotfilesRoot}/alacritty/.config/alacritty/themes.toml";
    })
    # tmux conf.d の各設定ファイル（共通）
    {
      ".config/tmux/conf.d/00-core.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/00-core.conf";
      ".config/tmux/conf.d/10-terminal.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/10-terminal.conf";
      ".config/tmux/conf.d/20-style.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/20-style.conf";
      ".config/tmux/conf.d/30-status.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/30-status.conf";
      ".config/tmux/conf.d/40-keymaps.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/40-keymaps.conf";
      ".config/tmux/conf.d/50-mouse-copy.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d/50-mouse-copy.conf";
      # lazydockerの設定
      ".config/lazydocker/config.yml".source =
        "${dotfilesRoot}/lazydocker/.config/lazydocker/config.yml";
    }
  ];
}
