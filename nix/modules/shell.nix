{ pkgs, config, dotfilesRoot, ... }: {
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    envExtra = builtins.readFile "${dotfilesRoot}/zsh/.zshenv";
    initExtra = ''
      # .config/zsh/*.zsh をソース
      for f in ${config.home.homeDirectory}/.config/zsh/*.zsh; do
        source "$f"
      done
    '';
  };

  programs.sheldon = {
    enable = true;
    settings = {
      shell = "zsh";
      plugins = {
        zsh-completions = {
          github = "zsh-users/zsh-completions";
        };
        zsh-autosuggestions = {
          github = "zsh-users/zsh-autosuggestions";
        };
        fast-syntax-highlighting = {
          github = "zdharma-continuum/fast-syntax-highlighting";
        };
      };
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile "${dotfilesRoot}/starship/.config/starship.toml");
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
