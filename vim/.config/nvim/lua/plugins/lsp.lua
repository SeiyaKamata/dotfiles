return {
  "neovim/nvim-lspconfig",
  config = function()
    local lspconfig = require("lspconfig")

    local on_attach = function(_, bufnr)
      local map = vim.keymap.set
      local opts = { noremap = true, silent = true, buffer = bufnr }

      map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      map("n", "<leader>gf", function()
        vim.lsp.buf.format({ async = true })
      end, opts)

      map("n", "<leader>rn", vim.lsp.buf.rename, opts)
      map("n", "<leader>gd", vim.lsp.buf.definition, opts)
      map("n", "<leader>gr", vim.lsp.buf.references, opts)
      map("n", "<leader>gk", vim.lsp.buf.hover, opts)
    end

    vim.lsp.config("gopls", {
      on_attach = on_attach,
    })

    vim.lsp.enable("gopls")
  end,
}
