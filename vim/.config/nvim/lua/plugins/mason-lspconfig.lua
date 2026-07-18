return {
	"williamboman/mason-lspconfig.nvim",
	dependencies = { "neovim/nvim-lspconfig", "williamboman/mason.nvim" },
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local buf_map = require("core.utils").buf_map

		local function on_attach(_, bufnr)
			local map = buf_map(bufnr)
			map("n", "<leader>ca", vim.lsp.buf.code_action,                          { desc = "Code action" })
			map("n", "<leader>gf", function() vim.lsp.buf.format({ async = true }) end, { desc = "Format" })
			map("n", "<leader>rn", vim.lsp.buf.rename,                               { desc = "Rename" })
			map("n", "gd", vim.lsp.buf.definition,                           { desc = "Go to definition" })
			map("n", "gr", vim.lsp.buf.references,                           { desc = "References" })
			map("n", "gk", function() vim.lsp.buf.hover({ border = "rounded" }) end, { desc = "Hover" })
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
			settings = {
				gopls = {
					-- 大きい Go モノレポでの常駐メモリ膨張を抑制（開いていないファイルの情報を積極的に破棄）
					["build.memoryMode"] = "DegradeClosed",
					-- 依存物・生成物ディレクトリをワークスペーススキャン対象から除外
					directoryFilters = { "-node_modules", "-vendor", "-**/node_modules", "-**/vendor" },
				},
			},
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
			settings = {
				python = {
					analysis = {
						typeCheckingMode = "basic",
						-- 依存物・生成物ディレクトリを解析対象から除外
						exclude = { "**/node_modules", "**/.venv", "**/venv", "**/vendor", "**/dist", "**/build" },
					},
				},
			},
		})

		vim.lsp.config("clangd", {
			-- competitive programming 等の単発ファイル用途。ワーカー数とインデックス優先度を下げ
			-- モノレポ内で誤って大量ファイルを拾った場合のピークメモリ・CPU負荷を抑える
			cmd = { "clangd", "--background-index", "--background-index-priority=background", "-j=2", "--pch-storage=disk" },
		})

		-- Neovim標準LSPはバッファを閉じてもクライアントを自動停止しないため、
		-- 別プロジェクト（別 root_dir）を渡り歩く長時間セッションでクライアントが積み上がり続ける。
		-- 添付バッファが0になったクライアントはその都度停止してメモリ膨張を防ぐ。
		vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
			callback = function()
				vim.schedule(function()
					for _, client in ipairs(vim.lsp.get_clients()) do
						if vim.tbl_isempty(client.attached_buffers) then
							client:stop()
						end
					end
				end)
			end,
		})
	end,
}
