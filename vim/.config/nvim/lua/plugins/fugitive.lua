return {
  "tpope/vim-fugitive",
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "Git status" },
    { "<leader>gl", "<cmd>Git log --oneline<cr>", desc = "Git log" },
  },
  config = function()
    -- Git statusウィンドウでの追加キーマップ
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "fugitive",
      callback = function(ev)
        local buf = ev.buf
        local opts = { buffer = buf, silent = true }
        -- ウィンドウ背景を NormalFloat にして他のウィンドウと区別
        vim.wo.winhighlight = "Normal:FugitiveBg,SignColumn:FugitiveBg,CursorLine:Visual"
        -- cc でコミット
        vim.keymap.set("n", "cc", "<cmd>Git commit<cr>", opts)
        -- pp でプッシュ
        vim.keymap.set("n", "pp", "<cmd>Git push<cr>", opts)
        -- P でプル
        vim.keymap.set("n", "P", "<cmd>Git pull<cr>", opts)
        -- rb でリベース
        vim.keymap.set("n", "rb", "<cmd>Git rebase<cr>", opts)
        -- q でウィンドウを閉じる
        vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
      end,
    })
  end,
}
