{ pkgs, config, dotfilesRoot, ... }: {
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    envExtra = builtins.readFile "${dotfilesRoot}/zsh/.zshenv";
    initContent = ''
      for f in ${dotfilesRoot}/zsh/.zsh/*.zsh; do
        source "$f"
      done
    '';
  };

  programs.sheldon.enable = true;

  programs.starship.enable = true;

  programs.zoxide.enable = true;

  home.file = {
    ".config/sheldon/plugins.toml".source =
      "${dotfilesRoot}/sheldon/.config/sheldon/plugins.toml";
    ".config/starship.toml".source =
      "${dotfilesRoot}/starship/.config/starship.toml";
  };
}
