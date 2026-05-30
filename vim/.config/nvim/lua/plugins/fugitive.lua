return {
  "tpope/vim-fugitive",
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "Git status" },
    { "<leader>ga", "<cmd>Git add %<cr>", desc = "Git add current file" },
    { "<leader>gc", "<cmd>Git commit<cr>", desc = "Git commit" },
    { "<leader>gp", "<cmd>Git push<cr>", desc = "Git push" },
    { "<leader>gP", "<cmd>Git pull<cr>", desc = "Git pull" },
    { "<leader>gl", "<cmd>Git log --oneline<cr>", desc = "Git log" },
    { "<leader>gb", "<cmd>Git blame<cr>", desc = "Git blame" },
    { "<leader>gB", "<cmd>Git branch<cr>", desc = "Git branch" },
    { "<leader>gco", "<cmd>Git checkout<cr>", desc = "Git checkout" },
    { "<leader>gf", "<cmd>Git fetch<cr>", desc = "Git fetch" },
    { "<leader>gr", "<cmd>Git rebase<cr>", desc = "Git rebase" },
  },
  config = function()
    -- Git statusウィンドウでの追加キーマップ
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "fugitive",
      callback = function(ev)
        local buf = ev.buf
        local opts = { buffer = buf, silent = true }
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
