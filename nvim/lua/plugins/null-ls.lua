-- ~/.config/nvim/lua/plugins/null-ls.lua
return {
  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local null_ls = require("null-ls")
      null_ls.setup({
        sources = {
          null_ls.builtins.formatting.prettier, -- TS/JS/React
          null_ls.builtins.formatting.gofmt,     -- Go
        },
      })
    end,
  },
}
