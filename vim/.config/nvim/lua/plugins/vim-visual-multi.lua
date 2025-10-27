return {
  "mg979/vim-visual-multi",
  branch = "master",
  init = function()
    -- optional: 好みの設定を追加
    vim.g.VM_leader = '\\'
    vim.cmd([[
      highlight VM_Extend ctermbg=lightblue guibg=#3E4452
      highlight VM_Cursor ctermbg=yellow guibg=#A3BE8C
      highlight VM_Insert ctermbg=red guibg=#E06C75
    ]])
  end,
}

