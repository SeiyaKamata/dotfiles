return {
	"williamboman/mason-lspconfig.nvim",
	dependencies = { "neovim/nvim-lspconfig", "williamboman/mason.nvim" },
	config = function()
		local buf_map = require("core.utils").buf_map

		local function on_attach(_, bufnr)
			local map = buf_map(bufnr)
			map("n", "<leader>ca", vim.lsp.buf.code_action,                          { desc = "Code action" })
			map("n", "<leader>gf", function() vim.lsp.buf.format({ async = true }) end, { desc = "Format" })
			map("n", "<leader>rn", vim.lsp.buf.rename,                               { desc = "Rename" })
			map("n", "<leader>gd", vim.lsp.buf.definition,                           { desc = "Go to definition" })
			map("n", "<leader>gr", vim.lsp.buf.references,                           { desc = "References" })
			map("n", "<leader>gk", function() vim.lsp.buf.hover({ border = "rounded" }) end, { desc = "Hover" })
		end

		require("mason-lspconfig").setup({
			ensure_installed = { "html", "cssls", "ts_ls", "gopls", "pyright", "clangd" },
			automatic_enable = true,
		})

		vim.lsp.config("*", { on_attach = on_attach })

		-- ts_ls: formatting delegated to prettier
		vim.lsp.config("ts_ls", {
			on_attach = function(client, bufnr)
				client.server_capabilities.documentFormattingProvider = false
				on_attach(client, bufnr)
			end,
		})

		vim.lsp.config("gopls", {
			on_attach = function(client, bufnr)
				on_attach(client, bufnr)
				local augroup = vim.api.nvim_create_augroup("LspFormatting_" .. bufnr, { clear = true })
				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					callback = function() vim.lsp.buf.format({ async = false }) end,
				})
			end,
		})

		vim.lsp.config("pyright", {
			settings = { python = { analysis = { typeCheckingMode = "basic" } } },
		})

		vim.lsp.config("clangd", {
			cmd = { "clangd", "--background-index" },
		})
	end,
}
