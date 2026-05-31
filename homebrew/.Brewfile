# Homebrew Brewfile
# nixpkgsに移行しないパッケージのみを管理する。
# bat, eza, fd, fzf, jq, git, neovim, tmux, starship 等の
# nixpkgsで入手可能なパッケージはHome Managerで管理するため、ここには含めない。

# ─── Taps ──────────────────────────────────────────────────────────────────

# Infisical公式tap（nixpkgsに存在しないため）
tap "infisical/get-cli"

# im-select公式tap（nixpkgsに存在しないため）
tap "daipeihust/tap"

# ─── Brews ─────────────────────────────────────────────────────────────────

# colima: Mac・Linux両環境でのDocker runtime安定性のため
# nixpkgsのcolimaはLinux非対応・動作が不安定なケースがある
brew "colima"

# pyenv: プロジェクトごとのPythonバージョン管理のため
# nixpkgsのpyenvはpython buildの互換性問題が発生するケースがある
brew "pyenv"

# rbenv-gemset: プロジェクトごとのgemセット管理のため
# nixpkgsに存在しない
brew "rbenv-gemset"

# aws-sam-cli: nixpkgsのバージョンが古くAWSの最新機能に追随できないため
brew "aws-sam-cli"

# infisical: nixpkgsに存在しないため公式tapから取得
brew "infisical/get-cli/infisical"

# im-select: macOS専用のIME切り替えツール（Neovim連携用）
# nixpkgsに存在せず、macOS専用のため
brew "daipeihust/tap/im-select"
