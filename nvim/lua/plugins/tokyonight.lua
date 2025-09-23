return {
  "folke/tokyonight.nvim",
  lazy = false,  -- 起動時にロード
  priority = 1000,
  config = function()
    vim.cmd("colorscheme tokyonight")
  end,
}
