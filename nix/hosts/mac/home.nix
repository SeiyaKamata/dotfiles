{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/shell.nix
    ../../modules/git.nix
    ../../modules/editor.nix
    ../../modules/terminal.nix
    ../../modules/packages.nix
  ];

  home.username = "kamata_seiya";
  home.homeDirectory = "/Users/kamata_seiya";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}
