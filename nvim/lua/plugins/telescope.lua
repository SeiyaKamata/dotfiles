return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup {
      defaults = {
        prompt_prefix = "❯ ",
        selection_caret = "❯ ",
        path_display = { "truncate" },
      },
    }

    -- optional: ファイル検索の keymap
    vim.api.nvim_set_keymap(
      "n",
      "<leader>ff",
      "<cmd>Telescope find_files<cr>",
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      "n",
      "<leader>fg",
      "<cmd>Telescope live_grep<cr>",
      { noremap = true, silent = true }
    )
  end,
}
