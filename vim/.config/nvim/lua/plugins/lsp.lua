return {
  "neovim/nvim-lspconfig",
  config = function()
    local buf_map = require("core.utils").buf_map

    local on_attach = function(_, bufnr)
      local map = buf_map(bufnr)
      map("n", "<leader>ca", vim.lsp.buf.code_action)
      map("n", "<leader>gf", function() vim.lsp.buf.format({ async = true }) end)
      map("n", "<leader>rn", vim.lsp.buf.rename)
      map("n", "<leader>gd", vim.lsp.buf.definition)
      map("n", "<leader>gr", vim.lsp.buf.references)
      map("n", "<leader>gk", vim.lsp.buf.hover)
    end

    vim.lsp.config("gopls", {
      on_attach = on_attach,
    })

    vim.lsp.enable("gopls")
  end,
}
