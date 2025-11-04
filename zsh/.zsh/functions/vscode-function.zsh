
open_vscode_by_workspace() {
  command -v code >/dev/null 2>&1 || { echo "VS Code の 'code' CLI が見つかりません"; return 1; }

  shopt -s nullglob 2>/dev/null
  local files=(*.code-workspace)

  if (( ${#files[@]} == 1 )); then
    code "${files[0]}"
  elif (( ${#files[@]} > 1 )); then
    if command -v fzf >/dev/null 2>&1; then
      local pick
      pick="$(printf '%s\n' "${files[@]}" | fzf --prompt='workspace > ')"
      [[ -n "$pick" ]] && code "$pick"
    else
      echo "複数の workspace があります。番号で選択:"
      select f in "${files[@]}"; do
        [[ -n "$f" ]] && code "$f" && break
      done
    fi
  else
    # サブフォルダ .vscode も一応見る。無ければカレントを開く。
    if compgen -G ".vscode/*.code-workspace" >/dev/null; then
      code .vscode/*.code-workspace
    else
      code .
    fi
  fi
}
