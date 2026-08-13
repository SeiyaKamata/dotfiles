#!/usr/bin/env bash
# apt に存在しない/追随が遅いツールを、各ツール公式のインストール方法で導入する。
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo "Installing starship..."
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$BIN_DIR" -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing golangci-lint..."
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$BIN_DIR"

echo "Installing sheldon..."
curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to "$BIN_DIR"

# bottom / procs は apt にも公式ワンライナーインストーラーも無いため、
# cargo が使える場合のみ導入する（無ければ手動で GitHub Releases から取得する）。
if command -v cargo >/dev/null 2>&1; then
  echo "Installing bottom, procs via cargo..."
  cargo install bottom procs
else
  echo "cargo が見つからないため bottom / procs はスキップしました。" >&2
  echo "必要な場合は https://github.com/ClementTsang/bottom/releases と https://github.com/dalance/procs/releases から手動導入してください。" >&2
fi
