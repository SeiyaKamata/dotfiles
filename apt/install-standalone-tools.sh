#!/usr/bin/env bash
# apt に存在しない/追随が遅いツールを、各ツール公式のインストール方法で導入する。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$BIN_DIR" -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing golangci-lint..."
# master の install.sh は v2 系のチェックサム行を取り違えて検証に失敗するため、
# バージョンを固定した install.sh を使う。
golangci_ver="$(curl -fsSL https://api.github.com/repos/golangci/golangci-lint/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4)"
golangci_sh="$(mktemp)"
curl -sSfL "https://raw.githubusercontent.com/golangci/golangci-lint/${golangci_ver}/install.sh" -o "$golangci_sh"
sh "$golangci_sh" -b "$BIN_DIR" "$golangci_ver"
rm -f "$golangci_sh"

echo "Installing sheldon..."
curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to "$BIN_DIR"

# yazi は apt リポジトリ(yazi-rs.github.io/apt)が Release ファイルを返さなくなったため、
# GitHub Releases のビルド済みバイナリを直接取得する。
echo "Installing yazi..."
yazi_ver="$(curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4)"
yazi_tmp="$(mktemp -d)"
curl -fLsS -o "$yazi_tmp/yazi.zip" "https://github.com/sxyazi/yazi/releases/download/${yazi_ver}/yazi-x86_64-unknown-linux-gnu.zip"
unzip -oq "$yazi_tmp/yazi.zip" -d "$yazi_tmp"
install -m755 "$yazi_tmp"/yazi-x86_64-unknown-linux-gnu/yazi "$yazi_tmp"/yazi-x86_64-unknown-linux-gnu/ya "$BIN_DIR/"
rm -rf "$yazi_tmp"

# apt に無い/バージョンが古すぎるツールを GitHub Releases のビルド済みバイナリで導入する。
# ($1=リポジトリ, $2=アーカイブ名の pattern, $3以降=展開後に install するバイナリの相対パス)
install_from_github_release() {
  local repo="$1" pattern="$2"; shift 2
  local ver tmp url
  ver="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | grep -m1 '"tag_name"' | cut -d'"' -f4)"
  url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep '"browser_download_url"' | cut -d'"' -f4 | grep -E "$pattern" | head -1)"
  tmp="$(mktemp -d)"
  echo "Installing ${repo} ${ver}..."
  curl -fLsS -o "$tmp/a" "$url"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$tmp/a" -C "$tmp" ;;
    *.zip)          unzip -oq "$tmp/a" -d "$tmp" ;;
  esac
  local b
  for b in "$@"; do
    install -m755 "$(find "$tmp" -type f -name "$(basename "$b")" | head -1)" "$BIN_DIR/"
  done
  rm -rf "$tmp"
}

install_from_github_release ClementTsang/bottom 'bottom_x86_64-unknown-linux-gnu\.tar\.gz$' btm
install_from_github_release dalance/procs 'procs-.*-x86_64-linux\.zip$' procs

# neovim は runtime ディレクトリ(lib/share)ごと必要なため $HOME/.local へ丸ごと展開し、
# バイナリだけ $BIN_DIR に symlink する。
echo "Installing neovim..."
nvim_tmp="$(mktemp -d)"
curl -fLsS -o "$nvim_tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
rm -rf "$HOME/.local/nvim"
mkdir -p "$HOME/.local/nvim"
tar -xzf "$nvim_tmp/nvim.tar.gz" -C "$HOME/.local/nvim" --strip-components=1
ln -sf "$HOME/.local/nvim/bin/nvim" "$BIN_DIR/nvim"
rm -rf "$nvim_tmp"

echo "Installing AWS CLI v2..."
aws_tmp="$(mktemp -d)"
curl -fLsS -o "$aws_tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip -oq "$aws_tmp/awscliv2.zip" -d "$aws_tmp"
"$aws_tmp/aws/install" --update --install-dir "$HOME/.local/aws-cli" --bin-dir "$BIN_DIR"
rm -rf "$aws_tmp"

if command -v uv >/dev/null 2>&1; then
  echo "Installing awslogs via uv..."
  uv tool install awslogs
fi

echo "Installing coderabbit CLI..."
cr_sh="$(mktemp)"
curl -fsSL https://cli.coderabbit.ai/install.sh -o "$cr_sh"
CODERABBIT_INSTALL_DIR="$BIN_DIR" sh "$cr_sh"
rm -f "$cr_sh"

if command -v npm >/dev/null 2>&1; then
  echo "Installing global npm packages..."
  grep -v '^#' "$SCRIPT_DIR/../npm/global-packages.txt" | grep -v '^[[:space:]]*$' \
    | xargs -r npm i -g
else
  echo "npm が見つからないため npm グローバルパッケージはスキップしました。" >&2
fi
