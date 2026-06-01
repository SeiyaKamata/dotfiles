{ pkgs, ... }: {
  programs.git = {
    enable = true;

    settings = {
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull.rebase = false;
      merge.conflictStyle = "zdiff3";
      color.ui = "auto";
    };

    includes = [
      {
        condition = "gitdir:~/work/";
        path = "~/.gitconfig-work";
      }
      {
        condition = "gitdir:~/personal/";
        path = "~/.gitconfig-personal";
      }
      {
        path = "~/.gitconfig.local";
      }
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      dark = true;
      navigate = true;
      line-numbers = true;
      side-by-side = false;
      syntax-theme = "Dracula";
      merge-conflict-style = "zdiff3";
      file-modified-label = "[M]";
      file-renamed-label = "[R]";
      file-removed-label = "[-]";
      file-copied-label = "[C]";
      file-added-label = "[+]";
    };
  };

  programs.gh.enable = true;
}
