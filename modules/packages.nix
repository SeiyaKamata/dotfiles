{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLIユーティリティ
    bat
    bottom
    chafa
    eza
    fd
    fzf
    jq
    procs

    # Docker
    docker
    docker-compose
    docker-buildx

    # AWS
    awscli2
    awslogs

    # メディア・ファイル処理
    imagemagick
    nkf
    fswatch
    flock

    # 言語ランタイム・パッケージマネージャ
    nodejs
    uv
    # pipx  # nixpkgs上流のテスト失敗のため一時的にコメントアウト（タスク4.1）

    # データベース
    mycli

    # Go ツール
    golangci-lint

    # TUI ツール
    yazi
    lazydocker
  ];
}
