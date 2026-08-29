#!/usr/bin/env bash
# Linux (Ubuntu/Debian系) 向けパッケージインストール。
# apt に無い/古すぎるツールは scripts/install-standalone-tools.sh が別途担当する。
set -euo pipefail

# ─── 公式サードパーティ apt リポジトリの登録 ──────────────────────────────

add_apt_repo_if_missing() {
  local list_file="$1"
  shift
  if [ ! -f "$list_file" ]; then
    "$@"
  fi
}

# Docker
add_apt_repo_if_missing /etc/apt/sources.list.d/docker.list bash -c '
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
'

# Terraform (HashiCorp)
add_apt_repo_if_missing /etc/apt/sources.list.d/hashicorp.list bash -c '
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
'

# GitHub CLI
add_apt_repo_if_missing /etc/apt/sources.list.d/github-cli.list bash -c '
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
'

# Charm (glow など)
add_apt_repo_if_missing /etc/apt/sources.list.d/charm.list bash -c '
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  sudo chmod a+r /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
    | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
'

sudo apt-get update

# ─── apt パッケージ一覧を読み込んでインストール ────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
grep -v '^#' "$SCRIPT_DIR/apt-packages.txt" | grep -v '^[[:space:]]*$' | xargs sudo apt-get install -y
