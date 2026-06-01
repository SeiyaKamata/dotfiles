{ config, pkgs, dotfilesRoot, lib, ... }:

{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  # nvim設定はdotfilesRootから直接参照（ストアへのコピー）
  # 編集ワークフローのためにシンボリックリンクが必要な場合は
  # home-manager switch 後に手動で差し替えること
  home.file.".config/nvim" = {
    source = "${dotfilesRoot}/vim/.config/nvim";
    recursive = true;
  };
}
