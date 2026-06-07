-- nvim-treesitter main ブランチ（Neovim 0.12+ 必須）
local parsers = {
	"lua", "python",
	"javascript", "jsx", "typescript", "tsx",
	"ruby", "go",
	"markdown", "markdown_inline",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup()
		require("nvim-treesitter").install(parsers)

		local function try_start(buf)
			pcall(vim.treesitter.start, buf)
			vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(ev) try_start(ev.buf) end,
		})

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				try_start(buf)
			end
		end
	end,
}
