return {
	"williamboman/mason-lspconfig.nvim",
	dependencies = { "neovim/nvim-lspconfig", "williamboman/mason.nvim" },
	config = function()
		local on_attach = require("core.utils").lsp_on_attach

		require("mason-lspconfig").setup({
			ensure_installed = {
				"html",
				"cssls",
				"ts_ls",
				"gopls",
				"pyright",
				"clangd",
			},
			automatic_enable = true,
		})

		-- デフォルト設定（全LSP共通）
		vim.lsp.config("*", { on_attach = on_attach })

		-- TypeScript / JavaScript
		vim.lsp.config("ts_ls", {
			on_attach = function(client, bufnr)
				client.server_capabilities.documentFormattingProvider = false
				on_attach(client, bufnr)
			end,
		})

		-- Go
		vim.lsp.config("gopls", {
			on_attach = function(client, bufnr)
				on_attach(client, bufnr)
				local augroup = vim.api.nvim_create_augroup("LspFormatting_" .. bufnr, { clear = true })
				vim.api.nvim_create_autocmd("BufWritePre", {
					group = augroup,
					buffer = bufnr,
					pattern = "*.go",
					callback = function()
						vim.lsp.buf.format({ async = false })
					end,
				})
			end,
		})

		-- Python
		vim.lsp.config("pyright", {
			settings = {
				python = {
					analysis = { typeCheckingMode = "basic" },
				},
			},
		})

		-- C / C++
		vim.lsp.config("clangd", {
			cmd = { "clangd", "--background-index" },
			filetypes = { "c", "cpp", "objc", "objcpp" },
		})
	end,
}
