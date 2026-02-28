return {
  "folke/which-key.nvim",
  config = function()
    require("which-key").setup({
      triggers = {
        { "<leader>", mode = "n" }, -- ノーマルモードのみ
      },
    })
  end,
}
