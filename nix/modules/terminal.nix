{ pkgs, config, lib, dotfilesRoot, ... }: {
  # alacrittyはmacOS向け（home.fileで設定ファイルをそのまま配置）
  # programs.alacritty.settingsでは `import` キーが処理できないため
  programs.alacritty.enable = lib.mkIf pkgs.stdenv.isDarwin true;

  # tmuxは自前のtmux.conf + conf.dを使うため、home-managerのモジュール（設定自動生成）は使わず
  # パッケージ本体のみpackages.nixで導入する。programs.tmux.enableを有効にすると
  # モジュールが生成する~/.config/tmux/tmux.confと下記のhome.file配置が衝突するため無効化している。

  home.file = lib.mkMerge [
    # alacritty設定はmacOSのみ
    (lib.mkIf pkgs.stdenv.isDarwin {
      ".config/alacritty/alacritty.toml".source =
        "${dotfilesRoot}/alacritty/.config/alacritty/alacritty.toml";
      ".config/alacritty/themes.toml".source =
        "${dotfilesRoot}/alacritty/.config/alacritty/themes.toml";
    })
    # tmux設定ファイル（共通）
    {
      ".config/tmux/tmux.conf".source =
        "${dotfilesRoot}/tmux/.config/tmux/tmux.conf";
      ".config/tmux/conf.d".source =
        "${dotfilesRoot}/tmux/.config/tmux/conf.d";
    }
  ];
}
