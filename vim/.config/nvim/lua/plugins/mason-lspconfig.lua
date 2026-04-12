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
			handlers = {
				-- デフォルト設定（全LSP共通）
				function(server_name)
					vim.lsp.config[server_name].setup({ on_attach = on_attach })
				end,

				-- TypeScript / JavaScript
				["ts_ls"] = function()
					vim.lsp.config.ts_ls.setup({
						on_attach = function(client, bufnr)
							client.server_capabilities.documentFormattingProvider = false
							on_attach(client, bufnr)
						end,
					})
				end,

				-- Go
				["gopls"] = function()
					vim.lsp.config.gopls.setup({
						on_attach = function(client, bufnr)
							on_attach(client, bufnr)
							vim.api.nvim_create_autocmd("BufWritePre", {
								pattern = "*.go",
								callback = function()
									vim.lsp.buf.format({ async = false })
								end,
							})
						end,
					})
				end,

				-- Python
				["pyright"] = function()
					vim.lsp.config.pyright.setup({
						settings = {
							python = {
								analysis = { typeCheckingMode = "basic" },
							},
						},
					})
				end,

				-- C / C++
				["clangd"] = function()
					vim.lsp.config.clangd.setup({
						cmd = { "clangd", "--background-index" },
						filetypes = { "c", "cpp", "objc", "objcpp" },
					})
				end,
			},
		})
	end,
}
