{
  description = "kamata_seiya's dotfiles managed by Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      mkHomeConfig = { system, homeNix }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
          extraSpecialArgs = { dotfilesRoot = self; };
          modules = [ homeNix ];
        };
    in
    {
      homeConfigurations = {
        "kamata_seiya@mac" = mkHomeConfig {
          system = "aarch64-darwin";
          homeNix = ./nix/hosts/mac/home.nix;
        };
        "kamata_seiya@linux" = mkHomeConfig {
          system = "x86_64-linux";
          homeNix = ./nix/hosts/linux/home.nix;
        };
      };
    };
}
