return {
  "nvimtools/none-ls.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local none_ls = require("null-ls")

    none_ls.setup({
      sources = {
        none_ls.builtins.formatting.prettier,     -- JS / TS / HTML / CSS
        none_ls.builtins.formatting.stylua,       -- Lua
        none_ls.builtins.formatting.gofmt,        -- Go
        none_ls.builtins.formatting.black,        -- Python
        none_ls.builtins.formatting.rubocop,      -- Ruby
        none_ls.builtins.formatting.clang_format, -- C / C++
      },
    })
  end,
}
