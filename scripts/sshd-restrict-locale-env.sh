#!/usr/bin/env bash
set -uo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

# macOS はこの対応の対象外（Ubuntu/Linuxのsshdが対象）
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "[locale] macOS はスキップ対象です"
  exit 0
fi

if [[ ! -f "$SSHD_CONFIG" ]]; then
  echo "[locale] $SSHD_CONFIG が見つかりません。スキップします" >&2
  exit 0
fi

# 冪等性: 既にLC_*が無ければ何もしない
if ! grep -Eq '^AcceptEnv[[:space:]]+.*LC_\*' "$SSHD_CONFIG"; then
  echo "[locale] sshd_config は対応済みです"
  exit 0
fi

TMP_CONFIG="$(mktemp)"
sed -E 's/^(AcceptEnv[[:space:]]+LANG)[[:space:]]+LC_\*[[:space:]]*$/\1/' "$SSHD_CONFIG" > "$TMP_CONFIG"

# 構文検証してから適用（不正な設定でSSHがロックアウトされるのを防ぐ）
if ! sudo sshd -t -f "$TMP_CONFIG"; then
  echo "[locale] 修正後の sshd_config が無効なため変更を中止しました" >&2
  rm -f "$TMP_CONFIG"
  exit 0
fi

if sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak" \
    && sudo cp "$TMP_CONFIG" "$SSHD_CONFIG" \
    && sudo systemctl reload ssh; then
  echo "[locale] AcceptEnv から LC_* を除去し、sshd を reload しました"
else
  echo "[locale] sshd_config の更新に失敗しました（sudo権限を確認してください）。手動で AcceptEnv から LC_* を削除してください" >&2
fi

rm -f "$TMP_CONFIG"
exit 0
