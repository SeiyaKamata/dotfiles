{
  description = "kamata_seiya's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # coderabbit-cli を取り出すためだけに 2 本目のフル nixpkgs を
    # フェッチ・評価するのを避け、本体の nixpkgs に揃える（評価高速化）
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, llm-agents }:
    let
      mkPkgs = system: import nixpkgs { inherit system; config.allowUnfree = true; };

      commonPackages = pkgs: with pkgs; [
        # CLI
        tmux
        tree-sitter
        bat
        bottom
        chafa
        eza
        fd
        fzf
        jq
        procs
        stow
        gnumake
        unzip
        duf

        # Docker
        docker
        docker-compose
        docker-buildx

        # AWS
        awscli2
        awslogs

        # ファイル処理
        imagemagick
        nkf
        fswatch
        flock

        # 言語ランタイム
        nodejs
        uv
        go
        gcc

        # インフラ
        terraform

        # データベース
        mycli

        # Go ツール
        golangci-lint

        # TUI
        yazi
        lazydocker

        # 検索・差分
        ripgrep
        delta

        # Git
        git
        gh

        # shell
        sheldon
        starship
        zoxide

        # Editor
        neovim
      ];

      macPackages = pkgs: with pkgs; [
        alacritty
      ];

      aiPackages = system: [
        llm-agents.packages.${system}.coderabbit-cli
      ];
    in
    {
      packages = {
        "aarch64-darwin".default =
          let pkgs = mkPkgs "aarch64-darwin";
          in pkgs.buildEnv {
            name = "kamata-env";
            paths = commonPackages pkgs ++ macPackages pkgs ++ aiPackages "aarch64-darwin";
          };
        "x86_64-linux".default =
          let pkgs = mkPkgs "x86_64-linux";
          in pkgs.buildEnv {
            name = "kamata-env";
            paths = commonPackages pkgs ++ aiPackages "x86_64-linux";
          };
      };
    };
}
