{ config, pkgs, ... }:

{
  home.username = "kamata_seiya";
  home.homeDirectory = "/Users/kamata_seiya";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}
