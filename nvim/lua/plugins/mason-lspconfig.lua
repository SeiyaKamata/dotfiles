-- ~/.config/nvim/lua/plugins/mason-lspconfig.lua
return {
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
        require("mason-lspconfig").setup {
        ensure_installed = { "ts_ls", "gopls" },
        }

        local lspconfig = require("lspconfig")

        -- React / TypeScript
        lspconfig.ts_ls.setup {
        on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
        end,
        }

        -- Go
        lspconfig.gopls.setup {
        on_attach = function(client)
            vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*.go",
            callback = function() vim.lsp.buf.format({ async = false }) end,
            })
        end,
        }
    end,
  },
}
